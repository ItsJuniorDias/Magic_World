//
//  AppState.swift
//  Magic World
//
//  Preferencias do app e favoritos. Tudo local, como o progresso —
//  nenhum identificador de dispositivo, nenhuma rede.
//

import Foundation
import Observation

@MainActor
@Observable
final class AppState {

    struct Stored: Codable {
        var hasCompletedOnboarding = false
        /// O paywall de entrada aparece uma vez, logo depois do onboarding.
        /// Guardado em disco: reaparecer a cada abertura seria cobranca, e
        /// quem ja disse nao uma vez nao precisa dizer de novo toda noite.
        var hasSeenIntroPaywall = false
        var readerName = ""
        var bedtimeReminderEnabled = false
        /// Minutos desde a meia-noite. Guardar componente em vez de Date
        /// evita o lembrete andar quando o fuso muda.
        var bedtimeMinutes = 19 * 60 + 30
        var favorites: Set<String> = []
        /// Codigo BCP-47 do idioma escolhido no app, ou nil pra seguir o
        /// idioma do sistema. Aplicado via `AppleLanguages` no
        /// `UserDefaults` — a mudanca so faz efeito no proximo lancamento
        /// do app, porque o String Catalog e resolvido no launch.
        var preferredLanguage: String? = nil
    }

    private(set) var stored: Stored {
        didSet { scheduleSave() }
    }

    private let fileURL: URL
    private var saveTask: Task<Void, Never>?

    init(filename: String = "app-state.json") {
        let dir = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appending(path: filename)

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(Stored.self, from: data) {
            stored = decoded
        } else {
            stored = Stored()
        }
    }

    // MARK: - Onboarding

    var hasCompletedOnboarding: Bool { stored.hasCompletedOnboarding }

    var hasSeenIntroPaywall: Bool { stored.hasSeenIntroPaywall }

    func markIntroPaywallSeen() {
        stored.hasSeenIntroPaywall = true
    }

    func completeOnboarding() {
        stored.hasCompletedOnboarding = true
    }

    var readerName: String {
        get { stored.readerName }
        set { stored.readerName = newValue }
    }

    /// Nome para saudacao. Vazio vira o generico, nunca "Ola, !".
    /// Ha um nome de verdade guardado. Distinto de `greetingName`, que
    /// devolve um substituto quando nao ha — util pra saudacao, mas mentira
    /// se usado como se fosse o nome da pessoa.
    var hasReaderName: Bool {
        !stored.readerName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var greetingName: String {
        let trimmed = stored.readerName.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? String(localized: "reader") : trimmed
    }

    // MARK: - Lembrete

    var bedtimeReminderEnabled: Bool {
        get { stored.bedtimeReminderEnabled }
        set { stored.bedtimeReminderEnabled = newValue }
    }

    var bedtimeHour: Int { stored.bedtimeMinutes / 60 }
    var bedtimeMinute: Int { stored.bedtimeMinutes % 60 }

    func setBedtime(hour: Int, minute: Int) {
        stored.bedtimeMinutes = hour * 60 + minute
    }

    /// Date apenas para alimentar o DatePicker; a fonte da verdade e o inteiro.
    var bedtimeDate: Date {
        Calendar.current.date(
            bySettingHour: bedtimeHour, minute: bedtimeMinute, second: 0, of: .now
        ) ?? .now
    }

    // MARK: - Idioma

    /// Codigo BCP-47 do idioma escolhido, ou nil pra seguir o sistema.
    var preferredLanguage: String? {
        get { stored.preferredLanguage }
        set {
            stored.preferredLanguage = newValue
            // AppleLanguages e uma lista; passamos so o escolhido, na
            // frente. Nil apaga a entrada e o sistema volta a mandar.
            let key = "AppleLanguages"
            if let code = newValue {
                UserDefaults.standard.set([code], forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

    /// Idiomas oferecidos ao usuario, na ordem em que aparecem no picker.
    /// Codigo + rotulo no proprio idioma (convencao: idioma se apresenta).
    static let availableLanguages: [(code: String, label: String)] = [
        ("en", "English"),
        ("pt-BR", "Português (Brasil)"),
        ("es", "Español"),
        ("fr", "Français"),
        ("de", "Deutsch"),
        ("it", "Italiano"),
        ("ar", "العربية"),
    ]

    // MARK: - Favoritos

    func isFavorite(_ storyId: String) -> Bool {
        stored.favorites.contains(storyId)
    }

    func toggleFavorite(_ storyId: String) {
        if stored.favorites.contains(storyId) {
            stored.favorites.remove(storyId)
        } else {
            stored.favorites.insert(storyId)
        }
    }

    var favoriteIds: Set<String> { stored.favorites }

    // MARK: - Persistencia

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }

    func flush() {
        saveTask?.cancel()
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(stored) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
