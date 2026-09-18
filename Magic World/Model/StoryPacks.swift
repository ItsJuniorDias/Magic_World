//
//  StoryPacks.swift
//  Magic World
//
//  On-Demand Resources. A narracao e a capa em movimento de cada conto
//  nao moram mais no .app: sao pacotes hospedados pela App Store, baixados
//  quando alguem vai usar. Eram 423 MB de MP3 e MP4 dentro do bundle, e o
//  app chegava a 429 MB na loja. Agora o download leva o codigo, as capas,
//  os textos e os tres contos livres.
//
//  AS TAGS SAO GERADAS por scripts/odr_tags.py — nunca a mao:
//
//    narration-<id>   os MP3 de todos os capitulos do conto
//    motion-<id>      o loop MP4 da capa
//
//  Um pacote por conto, e nao por capitulo, por causa do segundo plano:
//  quando um capitulo acaba com a tela bloqueada o player encadeia o
//  proximo sozinho, e esse momento nao pode depender de rede. Com o conto
//  inteiro num pacote, abrir o leitor ja garante todos os capitulos.
//
//  Narracao e capa em tags separadas porque pesam coisas diferentes: a capa
//  e enfeite com fallback parado e aparece no detalhe de conto que a pessoa
//  nem pode abrir. Baixar 5 MB de audio so por olhar a vitrine seria
//  desperdicio.
//
//  Os contos livres sao tags de instalacao inicial: descem junto com o app.
//  Mesmo assim passam por NSBundleResourceRequest como os outros — o sistema
//  pode apagar qualquer pacote quando falta espaco, e sem o pedido o arquivo
//  simplesmente nao aparece no Bundle.main.
//

import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class StoryPacks {

    enum Kind: String {
        case narration, motion

        /// Quanto o sistema deve se esforcar pra manter o pacote quando o
        /// aparelho fica sem espaco. A narracao e o que a pessoa veio buscar
        /// e o que precisa estar la numa noite sem sinal; a capa em
        /// movimento e a primeira coisa que pode sair.
        fileprivate var preservation: Double {
            switch self {
            case .narration: 0.8
            case .motion: 0.2
            }
        }

        /// Narracao so e pedida com o leitor aberto e a pessoa esperando.
        /// A capa pode chegar quando der: ate la, a arte parada segura.
        fileprivate var loadingPriority: Double {
            switch self {
            case .narration: NSBundleResourceRequestLoadingPriorityUrgent
            case .motion: 0.2
            }
        }
    }

    static func tag(_ kind: Kind, _ storyId: String) -> String {
        "\(kind.rawValue)-\(storyId)"
    }

    /// tag -> bytes, de packs.json. E como o app sabe que um conto tem
    /// narracao ou capa em movimento sem ter de baixar nada pra descobrir.
    private let sizes: [String: Int]

    /// Prefetches em andamento, pra nao abrir dois pedidos pra mesma tag.
    @ObservationIgnored private var prefetching: Set<String> = []

    private let log = Logger(subsystem: "com.alexandre.juniort10.magicworld", category: "packs")

    init() {
        sizes = Self.loadManifest()

        for kind in [Kind.narration, .motion] {
            let tags = Set(sizes.keys.filter { $0.hasPrefix(kind.rawValue + "-") })
            Bundle.main.setPreservationPriority(kind.preservation, forTags: tags)
        }

        #if DEBUG
        Self.assertNoUntaggedMedia()
        #endif
    }

    func has(_ kind: Kind, for storyId: String) -> Bool {
        sizes[Self.tag(kind, storyId)] != nil
    }

    /// Um pedido novo pro pacote, ou nil quando o conto nao tem esse pacote.
    /// Quem segura o objeto segura o conteudo — ver PackAccess.
    func access(_ kind: Kind, for storyId: String) -> PackAccess? {
        let tag = Self.tag(kind, storyId)
        guard let bytes = sizes[tag] else { return nil }
        return PackAccess(tag: tag, bytes: bytes, priority: kind.loadingPriority)
    }

    /// Baixa pro cache do sistema e solta na hora. Serve pra adiantar o que
    /// a pessoa provavelmente vai abrir: quando o leitor pedir, o pacote ja
    /// esta no aparelho e o pedido dele resolve sem rede.
    func prefetch(_ kind: Kind, for storyId: String) {
        let tag = Self.tag(kind, storyId)
        guard sizes[tag] != nil, !prefetching.contains(tag) else { return }
        prefetching.insert(tag)

        let request = NSBundleResourceRequest(tags: [tag])
        request.loadingPriority = 0.5
        Task {
            defer { prefetching.remove(tag) }
            if await request.conditionallyBeginAccessingResources() {
                request.endAccessingResources()
                return
            }
            do {
                try await request.beginAccessingResources()
                request.endAccessingResources()
            } catch {
                // Sem rede, sem espaco: tanto faz aqui. O leitor pede de novo
                // e e ele quem mostra o erro, se ainda houver.
                log.notice("prefetch de \(tag) falhou: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Manifesto

    private static func loadManifest() -> [String: Int] {
        guard let url = Bundle.main.url(forResource: "packs", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data)
        else {
            Logger(subsystem: "com.alexandre.juniort10.magicworld", category: "packs")
                .error("packs.json ausente ou ilegivel — narracao e capas em movimento ficam desligadas")
            return [:]
        }
        return manifest.packs
    }

    private struct Manifest: Decodable {
        let packs: [String: Int]
    }

    #if DEBUG
    /// Antes de qualquer pedido, nenhum MP3 ou MP4 deveria estar visivel no
    /// bundle: tudo que tem tag mora em pacote. Se aparece aqui, entrou no
    /// .app sem tag — o grupo sincronizado adiciona arquivo novo sozinho e
    /// ninguem percebe ate o app voltar a pesar centenas de MB na loja.
    private static func assertNoUntaggedMedia() {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
        let untagged = ["mp3", "mp4"]
            .flatMap { Bundle.main.urls(forResourcesWithExtension: $0, subdirectory: nil) ?? [] }
            .map(\.lastPathComponent)
            .sorted()
        guard let first = untagged.first else { return }
        assertionFailure("""
            \(untagged.count) arquivo(s) de midia no .app sem tag de On-Demand \
            Resources (ex.: \(first)). Rode: python3 scripts/odr_tags.py
            """)
    }
    #endif
}

// MARK: - Pedido

/// Um pedido de acesso a um pacote. Enquanto este objeto vive e `release`
/// nao foi chamado, o sistema nao apaga o conteudo e os arquivos aparecem
/// no Bundle.main como se estivessem no .app.
///
/// Soltar o objeto tambem devolve o acesso: o NSBundleResourceRequest chama
/// `endAccessingResources` sozinho quando e desalocado. `release` existe pra
/// quem quer cancelar um download no meio.
@MainActor
@Observable
final class PackAccess {

    enum Phase: Equatable {
        case idle
        case downloading(Double)
        case ready
        case failed(Failure)
    }

    enum Failure: Equatable {
        /// Sem conexao, ou a conexao caiu no meio.
        case network
        case noSpace
        case other
    }

    let tag: String
    let bytes: Int
    private(set) var phase: Phase = .idle

    var isReady: Bool { phase == .ready }

    private let priority: Double
    @ObservationIgnored private var request: NSBundleResourceRequest?
    @ObservationIgnored private var hasAccess = false
    @ObservationIgnored private var inflight: Task<Void, Never>?
    @ObservationIgnored private var progressObservation: NSKeyValueObservation?

    fileprivate init(tag: String, bytes: Int, priority: Double) {
        self.tag = tag
        self.bytes = bytes
        self.priority = priority
    }

    /// Resolve quando o pacote esta no aparelho ou quando falhou — olhar
    /// `phase` depois. Pode ser chamado de novo: pronto, volta na hora;
    /// baixando, espera o mesmo download; falhou, tenta outra vez.
    ///
    /// Cancelar a Task de quem chamou NAO cancela o download. Pra isso,
    /// `release`.
    func load() async {
        if phase == .ready { return }
        let task: Task<Void, Never>
        if let inflight {
            task = inflight
        } else {
            task = Task { await self.fetch() }
            inflight = task
        }
        await task.value
    }

    /// Devolve o acesso, ou cancela o download se ainda nao terminou.
    func release() {
        progressObservation = nil
        if let request {
            if hasAccess {
                request.endAccessingResources()
            } else {
                request.progress.cancel()
            }
        }
        request = nil
        hasAccess = false
        inflight = nil
        phase = .idle
    }

    // MARK: - Privado

    /// Um NSBundleResourceRequest so serve pra uma tentativa; tentar de novo
    /// depois de uma falha pede um objeto novo.
    private func fetch() async {
        let request = NSBundleResourceRequest(tags: [tag])
        request.loadingPriority = priority
        self.request = request

        // Ja no aparelho (instalacao inicial, ou baixado antes): sem rede e
        // sem piscar barra de progresso.
        if await request.conditionallyBeginAccessingResources() {
            settle(request, began: true, phase: .ready)
            return
        }
        guard self.request === request else { return }

        phase = .downloading(0)
        observeProgress(of: request)
        do {
            try await request.beginAccessingResources()
            settle(request, began: true, phase: .ready)
        } catch {
            settle(request, began: false, phase: .failed(Self.failure(from: error)))
        }
    }

    /// Fecha uma tentativa. Se `release` foi chamado no meio do caminho, o
    /// pedido ja nao e o corrente: devolve o acesso e nao mexe na fase.
    private func settle(_ request: NSBundleResourceRequest, began: Bool, phase: Phase) {
        guard self.request === request else {
            if began { request.endAccessingResources() }
            return
        }
        progressObservation = nil
        inflight = nil
        hasAccess = began
        if !began { self.request = nil }
        self.phase = phase
    }

    private func observeProgress(of request: NSBundleResourceRequest) {
        let id = ObjectIdentifier(request)
        progressObservation = request.progress.observe(\.fractionCompleted) { @Sendable [weak self] progress, _ in
            let fraction = progress.fractionCompleted
            Task { @MainActor [weak self] in
                guard let self,
                      self.request.map({ ObjectIdentifier($0) }) == id,
                      case .downloading(let shown) = self.phase,
                      // De ponto em ponto percentual: o KVO dispara muito mais
                      // que isso, e cada disparo redesenharia o leitor.
                      fraction - shown >= 0.01 || fraction >= 1
                else { return }
                self.phase = .downloading(min(fraction, 1))
            }
        }
    }

    private static func failure(from error: Error) -> Failure {
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain, ns.code == NSBundleOnDemandResourceOutOfSpaceError {
            return .noSpace
        }
        let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError
        if ns.domain == NSURLErrorDomain || underlying?.domain == NSURLErrorDomain {
            return .network
        }
        return .other
    }
}
