//
//  ReminderScheduler.swift
//  Magic World
//
//  Lembrete diario de hora da historia — e, nas segundas, os contos
//  gratis da semana nova.
//
//  A permissao NUNCA e pedida na abertura do app. O sistema so deixa
//  perguntar uma vez: se a crianca (ou o pai) nega no primeiro segundo,
//  sem entender o que e, acabou — so volta pelos Ajustes. Por isso a tela
//  de onboarding explica primeiro e so pede depois do toque.
//
//  UMA NOTIFICACAO POR DIA, NUNCA DUAS
//
//  O onboarding promete "One reminder a day, at the hour you pick. Nothing
//  else". A virada da semana nao ganha notificacao propria: na segunda, o
//  lembrete daquele dia troca "A chapter is waiting" pelos titulos que
//  acabaram de abrir. Mesma hora, mesma permissao, a mesma uma por dia.
//  Quem nao ligou o lembrete nao recebe nada, e quem assina recebe o
//  lembrete de sempre — "gratis esta semana" nao diz nada a quem tem tudo.
//
//  POR QUE AGENDAR AS SEGUNDAS COM ANTECEDENCIA
//
//  O calendario dos gratis esta no bundle, entao os titulos de cada segunda
//  sao conhecidos hoje. Cada segunda vira um pedido proprio, sem repeticao,
//  com os titulos daquela semana; os outros seis dias sao um pedido
//  repetido por dia da semana. Assim a notificacao da virada chega mesmo
//  com o app fechado a semana inteira. O horizonte e de `mondaysAhead`
//  semanas e anda a cada abertura do app — quem ficar mais que isso sem
//  abrir perde o lembrete das segundas seguintes, nao o dos outros dias.
//

import Foundation
import UserNotifications
import OSLog

enum ReminderScheduler {

    /// Prefixo de todo pedido deste agendador. O lembrete antigo, de antes
    /// das segundas, usava exatamente este id — o prefixo tambem o cobre.
    static let identifier = "magicworld.bedtime"
    /// Quantas segundas a frente ficam agendadas. Com os seis dias
    /// repetidos sao 18 pedidos, longe do teto de 64 do sistema.
    static let mondaysAhead = 12

    private static let log = Logger(subsystem: "com.alexandre.juniort10.magicworld", category: "reminders")

    /// O que deve estar agendado. Montado pelo Magic_WorldApp a partir do
    /// AppState, do Store e da biblioteca; Equatable pra servir de id de
    /// `.task` — muda o plano, reagenda.
    struct Plan: Equatable {
        var enabled: Bool
        var hour: Int
        var minute: Int
        /// Segundas de semana nova e os titulos, ja localizados, que abrem
        /// nelas. Vazio pra quem assina: ai todo dia e o lembrete de sempre.
        var mondays: [Monday]

        struct Monday: Equatable {
            /// Segunda 00:00 local.
            let start: Date
            let titles: [String]
        }
    }

    /// True se o usuario autorizou. False tanto para negado quanto para erro.
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            log.error("permissao de notificacao falhou: \(error.localizedDescription)")
            return false
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// A sincronizacao em andamento, e quantas ja foram pedidas.
    private static var queue: Task<Void, Never>?
    private static var generation = 0

    /// Deixa agendado exatamente o que o plano diz. Idempotente: apaga
    /// tudo deste agendador e grava de novo, entao pode rodar a cada
    /// abertura sem acumular pedidos.
    ///
    /// Em fila, uma de cada vez. Duas pedidas juntas — no lancamento de quem
    /// assina, o plano troca de "nao assina" pra "assina" enquanto a volta
    /// ao primeiro plano tambem pede uma — se intercalavam nos `await`: a
    /// velha gravava depois de a nova apagar, e sobravam os seis dias da
    /// semana E o diario, duas notificacoes por dia. Na fila, a que ficou
    /// velha antes de comecar e pulada, e a ultima sempre apaga e grava
    /// sozinha.
    static func sync(_ plan: Plan, now: Date = .now) async {
        generation += 1
        let mine = generation
        let previous = queue
        let task = Task {
            await previous?.value
            guard mine == generation else { return }
            await perform(plan, now: now)
        }
        queue = task
        await task.value
    }

    private static func perform(_ plan: Plan, now: Date) async {
        let center = UNUserNotificationCenter.current()
        let ours = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(identifier) }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        guard plan.enabled else { return }
        switch await authorizationStatus() {
        case .authorized, .provisional, .ephemeral: break
        default: return
        }

        var requests: [UNNotificationRequest] = []

        if plan.mondays.isEmpty {
            requests.append(repeating(
                id: "\(identifier).daily",
                matching: DateComponents(hour: plan.hour, minute: plan.minute)))
        } else {
            // Domingo e 1, segunda e 2 no calendario gregoriano. A segunda
            // fica de fora da repeticao: cada uma tem pedido proprio.
            for weekday in [1, 3, 4, 5, 6, 7] {
                requests.append(repeating(
                    id: "\(identifier).weekday.\(weekday)",
                    matching: DateComponents(hour: plan.hour, minute: plan.minute, weekday: weekday)))
            }

            let calendar = FreeSchedule.calendar()
            for monday in plan.mondays {
                guard let fire = calendar.date(bySettingHour: plan.hour, minute: plan.minute,
                                               second: 0, of: monday.start),
                      fire > now
                else { continue }
                // Os componentes do gatilho saem do calendario DO APARELHO,
                // com era: o gatilho le ano, mes e dia no `Calendar.current`
                // da pessoa. Numeros gregorianos lidos num calendario budista,
                // hebraico ou islamico (padrao de ar_SA) caem em outro seculo
                // ou em data nenhuma — e a segunda ficava sem lembrete.
                //
                // Sem `parts.calendar`: com ele o fuso do calendario prende o
                // gatilho, e depois de uma viagem a segunda dispararia noutro
                // dia local que os seis repetidos — dois num dia, nenhum noutro.
                let parts = Calendar.current.dateComponents(
                    [.era, .year, .month, .day, .hour, .minute], from: fire)
                let day = calendar.dateComponents([.year, .month, .day], from: monday.start)
                let content = UNMutableNotificationContent()
                content.title = String(localized: "New free stories")
                content.body = String(localized: "Free until Sunday: \(joined(monday.titles))")
                content.sound = .default
                requests.append(UNNotificationRequest(
                    identifier: "\(identifier).monday.\(day.year ?? 0)-\(day.month ?? 0)-\(day.day ?? 0)",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)))
            }
        }

        for request in requests {
            do {
                try await center.add(request)
            } catch {
                log.error("falha ao agendar \(request.identifier): \(error.localizedDescription)")
            }
        }
        log.info("lembrete agendado para \(plan.hour):\(plan.minute), \(requests.count) pedidos")
    }

    // MARK: - Apoio

    /// O lembrete de todo dia. Localizado na hora de agendar: o app reagenda
    /// a cada abertura, entao troca de idioma e pega na abertura seguinte.
    private static func repeating(id: String, matching components: DateComponents) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Story time")
        content.body = String(localized: "A chapter is waiting.")
        content.sound = .default
        return UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true))
    }

    /// "A, B e C" na lingua do app, nao na da regiao: com o app em
    /// portugues num aparelho em ingles, `Locale.current` juntaria com "and".
    private static func joined(_ titles: [String]) -> String {
        let formatter = ListFormatter()
        formatter.locale = Locale(identifier: ContentLanguage.current)
        return formatter.string(from: titles) ?? titles.joined(separator: ", ")
    }
}
