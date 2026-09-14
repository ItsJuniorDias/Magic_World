//
//  ChapterTimings.swift
//  Magic World
//
//  Alinhamento sentenca <-> audio, produzido pelo pipeline de narracao.
//
//  Regra importante: quando existe arquivo de timings, ele e a fonte da
//  segmentacao em sentencas — o app NAO resegmenta o texto por conta propria.
//  Resegmentar aqui e resegmentar no Python usando regras diferentes e como
//  o read-along sai do lugar no meio do capitulo.
//

import Foundation

struct ChapterTimings: Codable, Hashable {
    let storyId: String
    let chapterIndex: Int
    let duration: TimeInterval
    let sentences: [Sentence]

    struct Sentence: Codable, Identifiable, Hashable {
        let index: Int
        let start: TimeInterval
        let end: TimeInterval
        let text: String

        var id: Int { index }

        func contains(_ time: TimeInterval) -> Bool {
            time >= start && time < end
        }
    }

    /// Indice da sentenca tocando em `time`, ou -1 antes da primeira.
    /// Busca binaria: roda a cada tick do player.
    func sentenceIndex(at time: TimeInterval) -> Int {
        guard !sentences.isEmpty else { return -1 }
        var low = 0
        var high = sentences.count - 1
        while low <= high {
            let mid = (low + high) / 2
            let s = sentences[mid]
            if time < s.start {
                high = mid - 1
            } else if time >= s.end {
                low = mid + 1
            } else {
                return mid
            }
        }
        // Caiu numa lacuna entre sentencas: mantem a anterior destacada.
        return max(-1, min(low, sentences.count) - 1)
    }

    func startTime(ofSentence index: Int) -> TimeInterval? {
        guard sentences.indices.contains(index) else { return nil }
        return sentences[index].start
    }
}
