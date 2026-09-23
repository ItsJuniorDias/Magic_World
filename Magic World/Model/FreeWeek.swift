//
//  FreeWeek.swift
//  Magic World
//
//  Os contos gratis da semana.
//
//  Nenhum conto e gratis pra sempre. Toda segunda-feira, a meia-noite no
//  fuso do aparelho, tres contos inteiros abrem pra quem nao assina e os da
//  semana anterior trancam de novo — mesmo que a crianca esteja no meio.
//  O calendario vem pronto no bundle (Content/free-weeks.json, gerado por
//  scripts/free_weeks.py) e a semana corrente sai da data do aparelho:
//  sem servidor, funciona em modo aviao.
//
//  Quem mexe no relogio do aparelho abre outra semana. Aceito: e um app
//  infantil sem backend, e a alternativa seria exigir rede pra ler um conto
//  gratis — o que quebraria a promessa de funcionar sem sinal.
//

import Foundation
import Observation
import OSLog
import UIKit

/// O calendario do bundle. Puro e sem estado, pra poder ser testado com
/// qualquer data e qualquer fuso — e `nonisolated` pelo mesmo motivo: o
/// projeto isola tudo no MainActor por padrao, e valor puro nao precisa.
nonisolated struct FreeSchedule: Decodable {
    /// Segunda-feira da semana 0, "yyyy-MM-dd". Meia-noite no fuso de quem
    /// le, nao em UTC: a semana vira a meia-noite de cada um.
    let startsOn: String
    /// Um lote de ids por semana. Depois do ultimo, volta pro primeiro.
    let weeks: [[String]]

    struct Week: Equatable {
        /// Posicao no calendario, de 0 a `weeks.count - 1`.
        let index: Int
        let storyIDs: [String]
        /// Segunda 00:00 local.
        let start: Date
        /// Segunda seguinte 00:00 local — quando estes trancam.
        let end: Date
    }

    /// Semana de segunda a segunda em qualquer locale. `Calendar.current`
    /// comeca no domingo nos EUA e no sabado em partes do mundo arabe, e o
    /// conto gratis nao pode mudar de dia conforme o idioma do aparelho.
    ///
    /// Montado a cada chamada, e nao guardado: o fuso pode mudar com o app
    /// aberto (viagem), e um calendario guardado ficaria no fuso antigo.
    static func calendar(timeZone: TimeZone = .current) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    /// A semana que contem `date`.
    func week(at date: Date, calendar: Calendar = FreeSchedule.calendar()) -> Week? {
        guard let first = firstMonday(calendar),
              let current = calendar.dateInterval(of: .weekOfYear, for: date)
        else { return nil }
        return week(number: weeksBetween(first, current.start, calendar), calendar: calendar)
    }

    /// As `count` semanas que comecam depois da que contem `date`, em ordem.
    func upcoming(after date: Date, count: Int,
                  calendar: Calendar = FreeSchedule.calendar()) -> [Week] {
        guard let first = firstMonday(calendar),
              let current = calendar.dateInterval(of: .weekOfYear, for: date)
        else { return [] }
        let now = weeksBetween(first, current.start, calendar)
        return (1...max(1, count)).compactMap { week(number: now + $0, calendar: calendar) }
    }

    // MARK: Aritmetica

    /// Semana `number` contada a partir da semana 0, que pode ser negativa
    /// (relogio antes de `startsOn`) ou passar do fim (o ciclo recomeca).
    private func week(number: Int, calendar: Calendar) -> Week? {
        guard !weeks.isEmpty,
              let first = firstMonday(calendar),
              let start = calendar.date(byAdding: .day, value: number * 7, to: first),
              let end = calendar.date(byAdding: .day, value: 7, to: start)
        else { return nil }
        let index = ((number % weeks.count) + weeks.count) % weeks.count
        return Week(index: index, storyIDs: weeks[index], start: start, end: end)
    }

    private func firstMonday(_ calendar: Calendar) -> Date? {
        let parts = startsOn.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// Dias de calendario, nao segundos: na semana do horario de verao ha
    /// 167 ou 169 horas, e dividir segundos por 604 800 erra justo na
    /// virada. Divisao pra baixo tambem nos negativos.
    private func weeksBetween(_ from: Date, _ to: Date, _ calendar: Calendar) -> Int {
        let days = calendar.dateComponents([.day], from: from, to: to).day ?? 0
        return days >= 0 ? days / 7 : -((-days + 6) / 7)
    }
}

extension FreeSchedule {
    /// O calendario embarcado, ou nil se o arquivo faltar ou nao abrir.
    nonisolated static func bundled() -> FreeSchedule? {
        guard let url = Bundle.main.url(forResource: "free-weeks", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let schedule = try? JSONDecoder().decode(FreeSchedule.self, from: data),
              !schedule.weeks.isEmpty
        else { return nil }
        return schedule
    }
}

// MARK: - Estado observavel

/// A semana corrente, mantida em dia com o app aberto.
///
/// Tres coisas fazem a semana virar na tela sem ninguem reabrir o app:
/// uma espera ate a meia-noite de segunda, a notificacao de mudanca
/// significativa de hora do sistema (meia-noite, fuso, relogio mexido) e
/// a volta do app ao primeiro plano, que o `Magic_WorldApp` repassa.
@MainActor
@Observable
final class FreeWeek {

    private(set) var current: FreeSchedule.Week?

    @ObservationIgnored let schedule: FreeSchedule?
    @ObservationIgnored private var turnover: Task<Void, Never>?
    // Sem deinit, pelo mesmo motivo do listener do Store: este objeto vive
    // o app inteiro e o observador tem de viver junto.
    @ObservationIgnored private var timeObserver: NSObjectProtocol?
    private let log = Logger(subsystem: "com.alexandre.juniort10.magicworld", category: "free-week")

    init(schedule: FreeSchedule? = FreeSchedule.bundled()) {
        self.schedule = schedule
        if schedule == nil {
            // Sem calendario nada abre de graca, e o paywall de abertura
            // deixa de ter o que o sustenta na revisao (ver RootView).
            log.error("free-weeks.json ausente ou ilegivel — nenhum conto gratis")
            assertionFailure("free-weeks.json ausente: rode scripts/free_weeks.py")
        }
        refresh()

        timeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.significantTimeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    /// Ids da semana, na ordem do calendario.
    var storyIDs: [String] { current?.storyIDs ?? [] }

    func contains(_ storyId: String) -> Bool {
        current?.storyIDs.contains(storyId) ?? false
    }

    /// Recalcula a semana. Barato; chamar sempre que o relogio puder ter
    /// andado sem o app ver.
    func refresh(now: Date = .now) {
        let week = schedule?.week(at: now)
        // So atribui quando muda: toda atribuicao invalida as views que
        // perguntam `canOpen`, e isto roda a cada volta ao primeiro plano.
        if week != current {
            if let week {
                log.info("semana \(week.index): \(week.storyIDs.joined(separator: ", "))")
            }
            current = week
        }
        armTurnover()
    }

    /// Acorda na meia-noite de segunda. Com o app suspenso a espera nao
    /// dispara, mas ai quem cobre e a volta ao primeiro plano.
    private func armTurnover() {
        turnover?.cancel()
        guard let end = current?.end else { return }
        turnover = Task { [weak self] in
            // Um segundo de folga pra nao recalcular ainda na semana velha.
            let wait = max(1, end.timeIntervalSinceNow + 1)
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }
}
