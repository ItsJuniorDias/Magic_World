//
//  ReadingProgress.swift
//  Magic World
//
//  Substitui o par IDFV + Firestore do app antigo. Grava em Application Support,
//  que sobrevive a atualizacao do app e entra no backup do iCloud — ou seja,
//  o progresso deixa de sumir quando a crianca reinstala.
//
//  Nenhum identificador de dispositivo, nenhuma rede: nada aqui sai do aparelho.
//

import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class ReadingProgress {

    struct ChapterState: Codable, Hashable {
        var position: TimeInterval = 0
        var isComplete = false
        var lastOpened: Date = .now
    }

    enum Level: String, Codable, CaseIterable {
        case apprentice, sorcerer, wizard, archmage

        var label: String {
            switch self {
            case .apprentice: String(localized: "Apprentice")
            case .sorcerer: String(localized: "Sorcerer")
            case .wizard: String(localized: "Wizard")
            case .archmage: String(localized: "Archmage")
            }
        }

        var threshold: Int {
            switch self {
            case .apprentice: 0
            case .sorcerer: 10
            case .wizard: 50
            case .archmage: 100
            }
        }

        static func forChaptersRead(_ count: Int) -> Level {
            allCases.last { count >= $0.threshold } ?? .apprentice
        }
    }

    private(set) var states: [String: ChapterState] = [:]

    private let log = Logger(subsystem: "com.alexandre.juniort10.magicworld", category: "progress")
    private let fileURL: URL
    /// Evita gravar em disco a cada tick do player.
    private var saveTask: Task<Void, Never>?

    var chaptersRead: Int { states.values.filter(\.isComplete).count }
    var level: Level { .forChaptersRead(chaptersRead) }

    /// Quantos capitulos faltam para o proximo nivel, ou nil no ultimo.
    var chaptersToNextLevel: Int? {
        guard let next = Level.allCases.first(where: { $0.threshold > chaptersRead }) else { return nil }
        return next.threshold - chaptersRead
    }

    init(filename: String = "reading-progress.json") {
        let dir = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appending(path: filename)
        loadFromDisk()
    }

    // MARK: - Leitura

    private func key(_ storyId: String, _ chapterIndex: Int) -> String {
        "\(storyId)#\(chapterIndex)"
    }

    func state(storyId: String, chapterIndex: Int) -> ChapterState {
        states[key(storyId, chapterIndex)] ?? ChapterState(position: 0, isComplete: false)
    }

    func position(storyId: String, chapterIndex: Int) -> TimeInterval {
        state(storyId: storyId, chapterIndex: chapterIndex).position
    }

    func isComplete(storyId: String, chapterIndex: Int) -> Bool {
        state(storyId: storyId, chapterIndex: chapterIndex).isComplete
    }

    /// Fracao concluida da historia, para a barra na capa.
    func completion(of story: Story) -> Double {
        guard !story.chapters.isEmpty else { return 0 }
        let done = story.chapters.filter { isComplete(storyId: story.id, chapterIndex: $0.index) }.count
        return Double(done) / Double(story.chapters.count)
    }

    /// Capitulo onde retomar: o primeiro nao concluido.
    func resumeChapter(of story: Story) -> Chapter? {
        story.chapters.first { !isComplete(storyId: story.id, chapterIndex: $0.index) }
            ?? story.chapters.last
    }

    // MARK: - Escrita

    func record(storyId: String, chapterIndex: Int, position: TimeInterval) {
        let k = key(storyId, chapterIndex)
        var s = states[k] ?? ChapterState()
        s.position = max(0, position)
        s.lastOpened = .now
        states[k] = s
        scheduleSave()
    }

    func markComplete(storyId: String, chapterIndex: Int) {
        let k = key(storyId, chapterIndex)
        var s = states[k] ?? ChapterState()
        guard !s.isComplete else { return }
        s.isComplete = true
        s.position = 0
        s.lastOpened = .now
        states[k] = s
        scheduleSave()
    }

    func reset() {
        states = [:]
        scheduleSave()
    }

    // MARK: - Persistencia

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.saveToDisk()
        }
    }

    /// Chamar quando o app vai para segundo plano, para nao perder o debounce.
    func flush() {
        saveTask?.cancel()
        saveToDisk()
    }

    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(states)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            log.error("falha ao gravar progresso: \(error.localizedDescription)")
        }
    }

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            states = try JSONDecoder().decode([String: ChapterState].self, from: data)
        } catch {
            // Arquivo corrompido nao pode impedir o app de abrir.
            log.error("progresso ilegivel, comecando do zero: \(error.localizedDescription)")
            states = [:]
        }
    }
}
