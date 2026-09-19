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

    /// O "~" avisa que o numero e estimativa. Quando o audio existe, some.
    var durationLabel: String {
        narrationDuration > 0
            ? String(localized: "\(minutes) min")
            : String(localized: "~\(estimatedMinutes) min")
    }
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
    var fallbackSentences: [String] {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
