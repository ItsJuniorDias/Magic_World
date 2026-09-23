//
//  ContentLibrary.swift
//  Magic World
//
//  Le o conteudo embarcado no bundle: textos, timings e o manifesto. Nenhum
//  Firestore, nenhuma chamada de IA em runtime, e a biblioteca inteira abre
//  em modo aviao. O que precisa de rede e so o audio e o video de conto que
//  ainda nao desceu — esses sao On-Demand Resources, ver StoryPacks.
//

import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class ContentLibrary {
    private(set) var stories: [Story] = []
    private(set) var loadErrors: [String] = []

    private var timingsCache: [String: ChapterTimings] = [:]
    private let log = Logger(subsystem: "com.alexandre.juniort10.magicworld", category: "content")

    init(autoload: Bool = true) {
        if autoload { load() }
    }

    /// Le `stories.json` (a lista de ids) e depois um arquivo por historia.
    /// Uma historia com problema e registrada e pulada — nunca derruba o app.
    func load() {
        stories = []
        loadErrors = []

        guard let manifestURL = Bundle.main.url(forResource: "stories", withExtension: "json") else {
            loadErrors.append("stories.json nao encontrado no bundle")
            log.error("stories.json ausente")
            return
        }

        let decoder = Self.makeDecoder()
        let ids: [String]
        do {
            let data = try Data(contentsOf: manifestURL)
            ids = try decoder.decode(Manifest.self, from: data).stories
        } catch {
            loadErrors.append("stories.json ilegivel: \(error.localizedDescription)")
            log.error("manifesto ilegivel: \(error.localizedDescription)")
            return
        }

        var loaded: [Story] = []
        for id in ids {
            guard let url = Bundle.main.url(forResource: id, withExtension: "json") else {
                loadErrors.append("\(id).json nao encontrado")
                continue
            }
            do {
                let story = try decoder.decode(Story.self, from: Data(contentsOf: url))
                guard story.id == id else {
                    loadErrors.append("\(id).json tem id interno \"\(story.id)\"")
                    continue
                }
                loaded.append(story)
            } catch {
                loadErrors.append("\(id).json: \(error.localizedDescription)")
                log.error("falha em \(id): \(error.localizedDescription)")
            }
        }

        stories = loaded
        log.info("biblioteca carregada: \(loaded.count) historias, \(self.loadErrors.count) erros")
    }

    func story(id: String) -> Story? {
        stories.first { $0.id == id }
    }

    /// Os contos destes ids, na ordem dos ids. Id sem conto e pulado.
    func stories(ids: [String]) -> [Story] {
        ids.compactMap(story(id:))
    }

    /// Publicadas mais recentemente primeiro.
    var recentlyPublished: [Story] {
        stories.sorted { $0.publishedAt > $1.publishedAt }
    }

    /// Habitats que tem ao menos uma historia, na ordem do enum.
    var populatedRealms: [Story.Realm] {
        Story.Realm.allCases.filter { realm in
            stories.contains { $0.realm == realm }
        }
    }

    func stories(in realm: Story.Realm) -> [Story] {
        stories.filter { $0.realm == realm }
    }

    /// Timings de um capitulo, ou nil quando a narracao ainda nao foi gerada.
    func timings(storyId: String, chapterIndex: Int) -> ChapterTimings? {
        let key = "\(storyId)-\(chapterIndex)"
        if let cached = timingsCache[key] { return cached }

        guard let url = Bundle.main.url(forResource: "\(key)-timings", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(ChapterTimings.self, from: data)
        else { return nil }

        timingsCache[key] = decoded
        return decoded
    }

    /// Datas do conteudo vem como "2026-08-05". Locale POSIX e UTC fixos:
    /// sem isso o parse quebra em aparelho com calendario nao gregoriano.
    private static func makeDecoder() -> JSONDecoder {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(formatter)
        return decoder
    }

    private struct Manifest: Codable {
        let stories: [String]
    }
}
