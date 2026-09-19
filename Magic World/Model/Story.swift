//
//  Story.swift
//  Magic World
//
//  Schema de conteudo v2.
//
//  Mudou de v1: `category` (genero) virou `realm` (habitat), e entrou
//  `publishedAt`. Todo conto do acervo e fantasia com animal magico, entao
//  categorizar por genero nao separa nada — "fantasy" seria o acervo inteiro.
//  Habitat separa, e e como crianca procura: pelo bicho e por onde ele vive.
//

import Foundation

// MARK: - Localizacao de conteudo

extension String {
    /// Traducao em runtime pela chave que e a propria string em ingles.
    ///
    /// A ideia: o titulo, o resumo, o nome do bicho, o titulo do capitulo,
    /// e o texto do capitulo existem em ingles no JSON do bundle, e a
    /// traducao vive no `Localizable.xcstrings` como uma chave = string-
    /// fonte. Ao pedir `.localizedContent`, o resolver do String Catalog
    /// devolve a versao no idioma corrente ou, se ela nao existir, a
    /// propria string em ingles (fallback nativo do sistema).
    ///
    /// COMO ADICIONAR TRADUCOES DE CONTEUDO:
    ///
    /// 1. Abra `Magic World/Localizable.xcstrings` no Xcode.
    /// 2. Adicione uma chave nova cujo VALOR e a string-fonte em ingles —
    ///    para conteudo, a chave e o texto inteiro em ingles (titulo,
    ///    resumo, ou o corpo do capitulo, do primeiro ao ultimo caracter).
    /// 3. Preencha as traducoes nas 6 outras linguas.
    /// 4. Salvar. Xcode faz o resto no proximo build.
    ///
    /// Chaves de conteudo longas (o texto de um capitulo tem ~500 palavras)
    /// sao pesadas de digitar; a via ergonomica e um script pequeno que
    /// mescle um JSON de traducoes no xcstrings (ver `scripts/`).
    ///
    /// Nome diferente de `.localized` — que ja existe como convencao mais
    /// solta em muito codigo — pra deixar claro que este e o caminho pra
    /// CONTEUDO do app, nao pra rotulo de interface. Rotulos passam pelo
    /// LocalizedStringKey de sempre.
    var localizedContent: String {
        String(localized: LocalizedStringResource(stringLiteral: self))
    }
}

/// O idioma em que o CONTEUDO existe, que nao e o mesmo em que a
/// interface existe.
///
/// A interface fala sete linguas. A narracao foi gravada uma vez, em
/// ingles, e gravar de novo em seis linguas e producao de audio, nao
/// codigo. Enquanto isso nao acontece, tocar a faixa inglesa para quem
/// pos o app em portugues entrega uma voz que a pessoa nao pediu e que
/// nao corresponde ao que ela escolheu — pior que nao ter audio.
///
/// Entao o leitor desliga o transporte fora do ingles e diz por que.
/// Quando houver narracao em outra lingua, o teste aqui vira uma
/// consulta ao que existe por idioma, e o resto do codigo nao muda.
enum ContentLanguage {

    /// Linguas em que ha narracao gravada.
    static let narrated: Set<String> = ["en"]

    /// A lingua que o bundle realmente resolveu — respeita tanto o
    /// idioma do sistema quanto o override de `AppState.preferredLanguage`,
    /// porque os dois passam por `AppleLanguages`.
    static var current: String {
        Bundle.main.preferredLocalizations.first ?? "en"
    }

    /// Ha narracao na lingua em que o app esta sendo lido.
    static var hasNarration: Bool {
        let code = current.split(separator: "-").first.map(String.init) ?? current
        return narrated.contains(code)
    }
}

struct Story: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    /// O animal da historia. Aparece no cartao — e o que a crianca procura.
    let creature: String
    let summary: String
    let realm: Realm
    let isFree: Bool
    let publishedAt: Date
    /// Nome do asset da capa. Vazio enquanto nao houver arte.
    let coverAsset: String
    let chapters: [Chapter]

    enum Realm: String, Codable, CaseIterable, Hashable, Identifiable {
        case forest, tides, skies, nightfall, frost

        var id: String { rawValue }

        var label: String {
            switch self {
            case .forest: String(localized: "Deep Forest")
            case .tides: String(localized: "The Tides")
            case .skies: String(localized: "Open Skies")
            case .nightfall: String(localized: "Nightfall")
            case .frost: String(localized: "Frost")
            }
        }

        /// Simbolos antigos de proposito: todos existem desde o iOS 13,
        /// entao nenhum vira quadrado vazio em aparelho mais velho.
        var symbol: String {
            switch self {
            case .forest: "leaf.fill"
            case .tides: "drop.fill"
            case .skies: "cloud.fill"
            case .nightfall: "moon.stars.fill"
            case .frost: "snowflake"
            }
        }
    }

    var narrationDuration: TimeInterval {
        chapters.reduce(0) { $0 + ($1.audioDuration ?? 0) }
    }

    var hasNarration: Bool {
        chapters.contains { $0.audioFile != nil }
    }

    var wordCount: Int {
        chapters.reduce(0) { $0 + $1.wordCount }
    }

    /// Estimativa a 150 palavras por minuto, usada enquanto nao ha MP3.
    var estimatedMinutes: Int {
        max(1, Int((Double(wordCount) / 150).rounded()))
    }

    /// Minutos reais quando a narracao existe, estimados quando nao.
    var minutes: Int {
        narrationDuration > 0
            ? max(1, Int((narrationDuration / 60).rounded()))
            : estimatedMinutes
    }

    /// "About" avisa que o numero e estimativa. Quando o audio existe,
    /// some. Nao usar o padrao "~%lld min" antigo: o Xcode normaliza o
    /// nome do simbolo tirando o "~" e ele colide com "%lld min".
    var durationLabel: String {
        narrationDuration > 0
            ? String(localized: "\(minutes) min")
            : String(localized: "About \(estimatedMinutes) min")
    }

    // MARK: - Conteudo localizado
    //
    // Nao trocamos os `let` originais: eles continuam sendo a fonte em
    // ingles (chave de traducao) e ficam disponiveis onde precisar da
    // string-fonte — busca, log, etc. As view usam estes acessores.

    var localizedTitle: String { title.localizedContent }
    var localizedCreature: String { creature.localizedContent }
    var localizedSummary: String { summary.localizedContent }
}

struct Chapter: Codable, Identifiable, Hashable {
    let index: Int
    let title: String
    let text: String
    let audioFile: String?
    let audioDuration: TimeInterval?

    var id: Int { index }

    var wordCount: Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }

    /// Segmentacao local, usada so quando nao ha arquivo de timings.
    /// Quando ha timings, a segmentacao vem de la — ver ReaderView.
    /// Opera sobre o texto LOCALIZADO: quando ha traducao, o fallback
    /// tambem quebra na frase certa daquele idioma.
    var fallbackSentences: [String] {
        localizedText
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Conteudo localizado

    var localizedTitle: String { title.localizedContent }
    var localizedText: String { text.localizedContent }
}
