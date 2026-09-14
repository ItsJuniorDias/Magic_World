//
//  Analytics.swift
//  Magic World
//
//  Cliente do backend proprio (`analytics-magicworld`). Manda o funil que a
//  loja nao mostra: quantas pessoas VIRAM o paywall, quantas tocaram em
//  comprar, e quantas chegaram ao fim. A App Store so conta a ultima.
//
//  O QUE ELE NAO MANDA, E ISSO E DELIBERADO
//
//  Nenhum identificador de aparelho, nenhum IDFA, nenhum nome, nenhum
//  progresso de leitura, nenhum titulo de conto. Um app de historia infantil
//  nao precisa saber o que a crianca leu pra saber se o paywall converte.
//
//  O identificador e um UUID sorteado na primeira execucao e guardado
//  localmente. Ele nao segue a pessoa entre apps nem entre aparelhos, e
//  desaparece quando o app e desinstalado. Ainda assim e dado coletado: tem
//  de estar declarado no rotulo de privacidade da App Store, em "Identifiers
//  / Product Interaction", ligado a "Analytics" e marcado como NAO usado
//  para rastreamento.
//
//  COMO ELE NAO ATRAPALHA
//
//  Nada bloqueia a interface. Os eventos entram numa fila em memoria, sao
//  gravados em disco, e vao em lote — no maximo 100 por requisicao, que e o
//  teto do servidor. Se a rede falhar, ficam na fila e vao na proxima. O app
//  inteiro funciona sem rede por design, entao a fila TEM de sobreviver a
//  ficar dias offline.
//
//  Sem `endpoint` configurado o cliente vira no-op silencioso. Isso e o que
//  deixa rodar em simulador e em TestFlight sem sujar os numeros.
//

import Foundation
import OSLog
import UIKit

@MainActor
@Observable
final class Analytics {

    // MARK: - Configuracao

    private static let live = "https://analytics-magicworld.onrender.com/events"

    /// Ligue temporariamente pra conferir do Xcode que os eventos chegam.
    /// Deixe desligado depois.
    private static let sendFromDebugBuilds = false

    /// Build de desenvolvimento nao manda nada por padrao.
    ///
    /// O funil do dashboard so filtra por data — nao ha filtro de
    /// plataforma nem de versao. Entao cada vez que voce roda pelo Xcode e
    /// abre o paywall, aquilo entra no mesmo numero que o de gente de
    /// verdade, e nao ha como separar depois. Melhor nao mandar.
    static var endpoint: String {
        #if DEBUG
        sendFromDebugBuilds ? live : ""
        #else
        live
        #endif
    }

    /// Quantos eventos acumular antes de mandar sozinho. O servidor aceita
    /// 100 por requisicao; 20 e o meio-termo entre poucas requisicoes e
    /// perder pouca coisa se o app morrer.
    private let batchSize = 20
    private let maxQueued = 500

    // MARK: - Eventos

    /// So os quatro do funil, mais a abertura, que e o denominador.
    ///
    /// A tentacao de instrumentar tudo e forte e vale resistir: cada evento
    /// a mais e um dado a mais pra declarar, defender e apagar, e o funil
    /// responde a pergunta que o app tem hoje.
    enum Event: String {
        case appOpen = "app_open"
        case paywallView = "paywall_view"
        case checkoutInitiated = "checkout_initiated"
        case startTrial = "start_trial"
        case subscribe = "subscribe"
    }

    // MARK: - Estado

    private var queue: [[String: Any]] = []
    private var flushTask: Task<Void, Never>?
    private let session = UUID().uuidString
    private let installId: String

    private let log = Logger(subsystem: "com.alexandre.juniort10.magicworld",
                             category: "analytics")

    private static let queueURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory,
                                           in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir,
                                                 withIntermediateDirectories: true)
        return dir.appendingPathComponent("analytics-queue.json")
    }()

    private static let installKey = "magicworld.installId"

    var isEnabled: Bool { !Self.endpoint.isEmpty }

    init() {
        // UUID sorteado, guardado em UserDefaults. Nao e o identificador do
        // aparelho: e deste app, nesta instalacao.
        if let existing = UserDefaults.standard.string(forKey: Self.installKey) {
            installId = existing
        } else {
            installId = UUID().uuidString
            UserDefaults.standard.set(installId, forKey: Self.installKey)
        }
        loadQueue()
    }

    // MARK: - Registrar

    /// `value` e `productId` so tem sentido nos eventos de compra; o resto
    /// dos campos o servidor indexa sozinho.
    func track(_ event: Event,
               productId: String? = nil,
               value: Decimal? = nil,
               currency: String? = nil) {
        guard isEnabled else { return }

        var params: [String: Any] = [
            "session_id": session,
            "user_id": installId,
            "platform": "ios",
            "app_version": Self.appVersion,
            "locale": Locale.current.identifier,
        ]
        if let region = Locale.current.region?.identifier {
            params["country"] = region
        }
        if let productId { params["product_id"] = productId }
        if let value { params["value"] = NSDecimalNumber(decimal: value).doubleValue }
        if let currency { params["currency"] = currency }

        queue.append([
            "event": event.rawValue,
            "ts": Int(Date().timeIntervalSince1970 * 1000),
            "params": params,
        ])

        // Fila cheia significa dias sem rede. Descartar os mais ANTIGOS: o
        // funil de ontem interessa menos que o de agora, e crescer sem
        // limite acabaria comendo o disco de quem nunca reconecta.
        if queue.count > maxQueued {
            queue.removeFirst(queue.count - maxQueued)
        }

        saveQueue()
        if queue.count >= batchSize { flush() }
    }

    // MARK: - Enviar

    func flush() {
        guard isEnabled, !queue.isEmpty, flushTask == nil,
              let url = URL(string: Self.endpoint) else { return }

        let batch = Array(queue.prefix(100))
        flushTask = Task { [weak self] in
            defer { Task { @MainActor in self?.flushTask = nil } }
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json",
                                 forHTTPHeaderField: "Content-Type")
                request.timeoutInterval = 15
                request.httpBody = try JSONSerialization.data(
                    withJSONObject: ["events": batch])

                let (_, response) = try await URLSession.shared.data(for: request)
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0

                await MainActor.run {
                    guard let self else { return }
                    // 202 e o sucesso. 4xx que nao seja 429 significa evento
                    // malformado: reenviar sempre daria o mesmo erro pra
                    // sempre, entao descarta. 429 e 5xx ficam pra proxima.
                    if code == 202 || (400..<500).contains(code) && code != 429 {
                        self.queue.removeFirst(min(batch.count, self.queue.count))
                        self.saveQueue()
                    }
                    if code != 202 {
                        self.log.error("envio devolveu \(code)")
                    }
                }
            } catch {
                // Rede caiu. A fila fica; vai na proxima tentativa.
                self?.log.debug("envio falhou: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Persistencia

    private func loadQueue() {
        guard let data = try? Data(contentsOf: Self.queueURL),
              let rows = try? JSONSerialization.jsonObject(with: data)
                as? [[String: Any]] else { return }
        queue = rows
    }

    private func saveQueue() {
        guard let data = try? JSONSerialization.data(withJSONObject: queue) else {
            return
        }
        try? data.write(to: Self.queueURL, options: .atomic)
    }

    /// Versao, com sufixo em TestFlight.
    ///
    /// Build de TestFlight e Release, entao manda eventos — o que costuma
    /// ser o que se quer durante o beta. Mas eles entram no mesmo funil que
    /// producao, e o dashboard nao separa. O sufixo pelo menos deixa a
    /// lista crua de eventos distinguir os dois, ja que `app_version` e
    /// campo indexado.
    ///
    /// O sinal e o recibo: TestFlight usa `sandboxReceipt`, a App Store
    /// nao.
    private static var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "0"
        let isTestFlight = Bundle.main.appStoreReceiptURL?
            .lastPathComponent == "sandboxReceipt"
        return isTestFlight ? "\(v)-beta" : v
    }
}
