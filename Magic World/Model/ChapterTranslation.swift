//
//  ChapterTranslation.swift
//  Magic World
//
//  Traducao automatica de capitulo, no aparelho.
//
//  POR QUE NAO TRADUZIR TUDO ANTES
//
//  O acervo tem 108 mil palavras. Em seis idiomas sao 648 mil — sete
//  romances — e a maior parte disso seria aposta: ninguem garante que
//  alguem vai abrir O Sapo-Relogio em italiano. Traduzir a mao o que
//  talvez nunca seja lido e caro pelo lado errado.
//
//  POR QUE NO APARELHO E NAO NUMA API
//
//  Tres coisas quebrariam de uma vez com tradutor na nuvem:
//
//  1. A promessa do paywall. "Plays with no signal — after that, no
//     connection needed" deixa de ser verdade se abrir um capitulo
//     exige rede.
//  2. A revisao de privacidade. Categoria Kids mandando leitura de
//     crianca para terceiro e uma conversa que nao precisamos ter.
//  3. O custo por leitura, que cresce com o uso — exatamente o tipo de
//     conta que um app de assinatura plana nao quer ter.
//
//  O framework Translation da Apple resolve os tres: roda local, de
//  graca, sem chave e sem servidor.
//
//  O QUE ISSO CUSTA, E E UM CUSTO REAL
//
//  Traducao de maquina achata a voz. "It was not frightening in
//  October" vira alguma coisa correta e morta, e a voz e o produto
//  aqui. Por isso a traducao humana segue o calendario dos gratis (ver
//  scripts/free_weeks.py e translation_status.py): dentro de cada idioma,
//  os contos das proximas semanas sao traduzidos a mao primeiro e vivem no
//  String Catalog — sao o que quem nao assina, e um revisor da App Store,
//  abre e o que decide assinatura. A maquina cobre o resto, inclusive gratis
//  da semana num idioma cuja fila ainda nao chegou nele.
//
//  A PRECEDENCIA, ENTAO, E:
//
//      traducao humana (catalogo)  →  cache em disco  →  maquina  →  ingles
//
//  E o leitor diz quando o que esta na tela veio da maquina. Sem isso a
//  pessoa julga a escrita do app pela traducao da Apple.
//

import Foundation
import Observation
import OSLog
import Translation

// MARK: - Cache

/// Guarda em disco o que a maquina ja traduziu.
///
/// Um arquivo por capitulo e por idioma, em vez de um indice unico: um
/// arquivo corrompido custa um capitulo, nao o acervo inteiro. Fica em
/// Application Support porque e conteudo derivado — sobrevive a
/// atualizacao do app, e o sistema pode limpar sob pressao de espaco
/// sem que nada se perca de verdade.
struct TranslationCache {
    private let root: URL
    private let log = Logger(subsystem: "com.alexandre.juniort10.magicworld",
                             category: "translation")

    init(directory: String = "Translations") {
        root = URL.applicationSupportDirectory.appending(path: directory)
    }

    private func url(storyId: String, chapter: Int, language: String) -> URL {
        root.appending(path: language)
            .appending(path: "\(storyId)-\(chapter).txt")
    }

    func read(storyId: String, chapter: Int, language: String) -> String? {
        let file = url(storyId: storyId, chapter: chapter, language: language)
        guard let text = try? String(contentsOf: file, encoding: .utf8),
              !text.isEmpty
        else { return nil }
        return text
    }

    func write(_ text: String, storyId: String, chapter: Int, language: String) {
        let file = url(storyId: storyId, chapter: chapter, language: language)
        do {
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            try text.write(to: file, atomically: true, encoding: .utf8)
        } catch {
            // Falhar em gravar o cache nao pode impedir a leitura: o
            // texto ja esta na tela, so vai ser traduzido de novo na
            // proxima abertura.
            log.error("cache de traducao nao gravou: \(error.localizedDescription)")
        }
    }

    /// Apaga tudo. Ligado ao "Erase progress" dos ajustes.
    func clear() {
        try? FileManager.default.removeItem(at: root)
    }

    /// Quanto o cache ocupa, para mostrar nos ajustes.
    var byteSize: Int64 {
        guard let walker = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let file as URL in walker {
            let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize
            total += Int64(size ?? 0)
        }
        return total
    }
}

// MARK: - Estado da traducao de um capitulo

@MainActor
@Observable
final class ChapterTranslation {

    enum State: Equatable {
        /// O que esta na tela e o texto de origem — ou porque o app esta
        /// em ingles, ou porque ha traducao humana no catalogo.
        case source
        /// A maquina esta trabalhando. Primeira abertura do capitulo.
        case working
        /// Traduzido pela maquina. O leitor rotula.
        case machine(String)
        /// Nao deu: par de idiomas sem suporte, ou o modelo falhou.
        /// A tela cai no ingles sem alarde.
        case unavailable
    }

    private(set) var state: State = .source
    /// Nao-nil dispara o `.translationTask` do leitor. Volta a nil
    /// quando nao ha nada a fazer.
    private(set) var configuration: TranslationSession.Configuration?

    private var pendingText: String?
    private var pendingStory: String?
    private var pendingChapter: Int?

    private let cache: TranslationCache
    private let log = Logger(subsystem: "com.alexandre.juniort10.magicworld",
                             category: "translation")

    init(cache: TranslationCache = TranslationCache()) {
        self.cache = cache
    }

    /// O texto a mostrar, ou nil para usar o do capitulo.
    var machineText: String? {
        if case .machine(let text) = state { return text }
        return nil
    }

    /// Verdadeiro quando a tela mostra prosa de maquina, e portanto
    /// precisa dizer isso.
    var isMachineTranslated: Bool { machineText != nil }

    // MARK: Ciclo

    /// Decide o que fazer com um capitulo que acabou de abrir.
    ///
    /// Sincrono de proposito: as tres saidas rapidas — ingles, traducao
    /// humana, cache — resolvem antes do primeiro desenho, e so o
    /// caminho lento arma a `configuration`. Assim o capitulo ja
    /// traduzido abre sem piscar.
    func prepare(chapter: Chapter, storyId: String) {
        configuration = nil

        let target = ContentLanguage.current
        guard ContentLanguage.canMachineTranslate else {
            state = .source
            return
        }

        // Ha traducao humana: ela ganha da maquina sempre.
        guard chapter.text == chapter.localizedText else {
            state = .source
            return
        }

        if let cached = cache.read(storyId: storyId,
                                   chapter: chapter.index,
                                   language: target) {
            state = .machine(cached)
            return
        }

        pendingText = chapter.text
        pendingStory = storyId
        pendingChapter = chapter.index
        state = .working
        configuration = TranslationSession.Configuration(
            source: Locale.Language(identifier: ContentLanguage.source),
            target: Locale.Language(identifier: target))
    }

    /// Chamado pelo `.translationTask` com a sessao pronta.
    func run(session: TranslationSession) async {
        guard let text = pendingText,
              let storyId = pendingStory,
              let index = pendingChapter
        else { return }

        let target = ContentLanguage.current

        do {
            // O capitulo inteiro numa requisicao so, nao frase a frase:
            // o modelo precisa do contexto em volta para escolher tempo
            // verbal e pronome, e picar o texto entrega prosa que nao
            // se liga com a frase anterior.
            let response = try await session.translate(text)
            guard !Task.isCancelled else { return }

            cache.write(response.targetText,
                        storyId: storyId, chapter: index, language: target)
            state = .machine(response.targetText)
        } catch {
            log.error("traducao falhou para \(storyId)#\(index): \(error.localizedDescription)")
            state = .unavailable
        }

        configuration = nil
        pendingText = nil
        pendingStory = nil
        pendingChapter = nil
    }

    /// Descarta o estado ao sair do leitor.
    func teardown() {
        configuration = nil
        pendingText = nil
        pendingStory = nil
        pendingChapter = nil
        state = .source
    }
}
