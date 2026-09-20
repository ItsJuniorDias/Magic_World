//
//  ProfileView.swift
//  Magic World
//
//  A terceira aba. Duas coisas moram aqui e as duas precisavam de casa:
//  o registro do que a pessoa leu, e os ajustes que ate agora nao tinham
//  tela nenhuma — nome, lembrete, assinatura, e apagar o progresso.
//
//  A ordem importa. O que a pessoa fez vem primeiro; os controles vem
//  depois. Uma aba de perfil que abre em "Gerenciar assinatura" e uma
//  cobranca, nao um perfil.
//

import SwiftUI
import StoreKit

struct ProfileView: View {
    @Environment(ContentLibrary.self) private var library
    @Environment(ReadingProgress.self) private var progress
    @Environment(AppState.self) private var app
    @Environment(Store.self) private var store
    @Environment(\.openURL) private var openURL

    @State private var showPaywall = false
    /// Acao segurada pelo portao parental ate um adulto resolver a conta.
    @State private var gate: ParentalGateAction?
    @State private var confirmingReset = false
    @State private var editingName = false
    @State private var managingSubscription = false
    @State private var restoreLabel = ""
    @State private var draftName = ""
    @State private var headerHeight: CGFloat = 0
    /// Alerta pedindo relancamento apos trocar de idioma. O String Catalog
    /// e resolvido no launch, entao trocar em runtime nao muda o que
    /// esta na tela — o alerta explica em vez de deixar a pessoa achando
    /// que nao funcionou.
    @State private var confirmingLanguageChange = false

    private var achievements: [Achievement] {
        Achievements.all(library: library, progress: progress, app: app)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xxl) {
                    header
                    numbers
                    earnedFirst
                    settings
                }
                .padding(.top, Space.md)
                .padding(.bottom, Space.xxl)
                .frame(maxWidth: Typography.readingMeasure)
                .frame(maxWidth: .infinity)
            }
            .screenBackground()
            .toolbarBackground(Palette.ink, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .scrollRevealedTitle("You", after: headerHeight)
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .manageSubscriptionsSheet(isPresented: $managingSubscription)
            .parentalGate($gate)
            .alert("Your name", isPresented: $editingName) {
                TextField("Name", text: $draftName)
                Button("Cancel", role: .cancel) {}
                Button("Save") { app.readerName = draftName }
            } message: {
                Text("This is only used to greet you. It stays on this device.")
            }
            .onAppear { draftName = app.readerName }
            .alert("Start again?", isPresented: $confirmingReset) {
                Button("Cancel", role: .cancel) {}
                Button("Erase progress", role: .destructive) {
                    progress.reset()
                    // As traducoes automaticas em cache sao conteudo
                    // derivado: sem o progresso elas nao significam nada,
                    // e sao reconstruidas na proxima abertura. Deixar
                    // para tras faria "apagar tudo" nao apagar tudo.
                    TranslationCache().clear()
                }
            } message: {
                Text("""
                This clears every chapter you have finished and every \
                badge. Your favourites and your subscription stay.
                """)
            }
            .alert("Restart to change the language", isPresented: $confirmingLanguageChange) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("""
                Close the app and open it again for the new language \
                to apply everywhere.
                """)
            }
        }
    }

    // MARK: - Topo

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            if app.hasReaderName { RankBadge(label: progress.level.label) }

            // Sem nome guardado, o nivel vira o titulo. "reader" em corpo
            // 34 se le como se fosse o nome da pessoa, e nao e.
            Text(app.hasReaderName ? app.greetingName : progress.level.label)
                .font(Typography.display)
                .foregroundStyle(Palette.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            if let left = progress.chaptersToNextLevel,
               let next = nextLevel {
                VStack(alignment: .leading, spacing: Space.sm) {
                    ProgressBar(value: levelProgress)
                    // Plural resolvido no xcstrings via variations.plural
                    // sobre a chave "%lld more chapters to %@". Sem isso
                    // haveria duas chaves separadas, e "capitulo" no
                    // singular em portugues so ficaria certo por acaso.
                    Text(String(localized: "\(left) more chapters to \(next.label)"))
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
            } else {
                Text("You have read every chapter there is.")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.lamplight)
            }
        }
        .padding(.horizontal, Space.screenMargin)
        .measuredHeight($headerHeight)
    }

    private var nextLevel: ReadingProgress.Level? {
        ReadingProgress.Level.allCases
            .first { $0.threshold > progress.chaptersRead }
    }

    private var levelProgress: Double {
        guard let next = nextLevel else { return 1 }
        let floor = progress.level.threshold
        let span = next.threshold - floor
        guard span > 0 else { return 1 }
        return Double(progress.chaptersRead - floor) / Double(span)
    }

    // MARK: - Numeros

    private var numbers: some View {
        let finished = library.stories.filter { progress.completion(of: $0) >= 1 }.count
        let seconds = Achievements.listenedSeconds(library: library, progress: progress)
        return HStack(spacing: Space.md) {
            stat("\(finished)", "stories")
            // Rotulo distinto de "Chapters" (heading do detalhe): sem
            // isso, o Xcode gera o mesmo simbolo pra ambos e o build cai
            // com colisao de simbolo no String Catalog.
            stat("\(progress.chaptersRead)", "chapters read")
            stat(hours(seconds), "listened")
            stat("\(app.favoriteIds.count)", "kept")
        }
        .padding(.horizontal, Space.screenMargin)
    }

    /// `value` fica String — e um numero formatado, nao chave. `label`
    /// vira LocalizedStringKey pra "stories" / "chapters" / "kept"
    /// virarem chaves reais no String Catalog.
    private func stat(_ value: String, _ label: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Typography.title)
                .foregroundStyle(Palette.lamplight)
                .monospacedDigit()
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Palette.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.lg)
        .cardSurface()
    }

    private func hours(_ seconds: TimeInterval) -> String {
        seconds < 3600 ? "\(Int(seconds / 60))m" : "\(Int(seconds / 3600))h"
    }

    // MARK: - Conquistas

    /// Conquistadas primeiro, e as demais logo abaixo, sem esconder nada.
    /// Esconder o que falta transforma a tela numa caixa de surpresas e
    /// convida a leitura a virar caca ao premio.
    private var earnedFirst: some View {
        let all = achievements
        let earned = all.filter(\.isEarned)
        let rest = all.filter { !$0.isEarned }

        return VStack(alignment: .leading, spacing: Space.lg) {
            ShelfHeader(title: "Badges",
                        subtitle: String(localized: "\(earned.count) of \(all.count)"))

            LazyVGrid(columns: [.init(.adaptive(minimum: 150), spacing: Space.md)],
                      spacing: Space.md) {
                ForEach(earned) { BadgeTile(achievement: $0) }
                ForEach(rest) { BadgeTile(achievement: $0) }
            }
            .padding(.horizontal, Space.screenMargin)
        }
    }

    // MARK: - Idioma

    /// Cartao com o Picker de idioma. Ficou como bloco proprio para
    /// caber junto ao Toggle do lembrete, com o mesmo desenho de fundo.
    ///
    /// A troca so faz efeito no proximo launch — String Catalog resolve
    /// tudo com base em `AppleLanguages` do UserDefaults no momento do
    /// lancamento do processo. Sem o alerta explicativo, o usuario troca
    /// e nao ve nada mudar, o que le como bug.
    private var languagePicker: some View {
        let binding = Binding<String>(
            get: { app.preferredLanguage ?? "" },
            set: { new in
                let value: String? = new.isEmpty ? nil : new
                guard value != app.preferredLanguage else { return }
                app.preferredLanguage = value
                confirmingLanguageChange = true
            }
        )
        return VStack(alignment: .leading, spacing: Space.md) {
            HStack(spacing: Space.md) {
                Image(systemName: "globe")
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 24)
                Text("Language")
                    .font(Typography.uiEmphasis)
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                // Menu em vez de segmented: sete idiomas nao cabem na
                // largura, e escolha unica com muitas opcoes e caso de
                // menu no iOS.
                Picker("", selection: binding) {
                    Text("System").tag("")
                    ForEach(AppState.availableLanguages, id: \.code) { lang in
                        Text(lang.label).tag(lang.code)
                    }
                }
                .pickerStyle(.menu)
                .tint(Palette.lamplight)
            }
        }
        .padding(Space.lg)
        .cardSurface()
    }

    // MARK: - Ajustes

    private var settings: some View {
        @Bindable var app = app
        return VStack(alignment: .leading, spacing: Space.lg) {
            ShelfHeader(title: "Settings")

            VStack(spacing: Space.md) {
                row("person.fill", "Name",
                    app.readerName.isEmpty ? String(localized: "Not set") : app.readerName) {
                    editingName = true
                }

                // Toggle e picker no lugar, em vez de linha com seta que
                // abre outra tela pra mexer em dois controles.
                VStack(spacing: Space.md) {
                    Toggle(isOn: $app.bedtimeReminderEnabled) {
                        Label("Bedtime reminder", systemImage: "moon.stars.fill")
                            .font(Typography.uiEmphasis)
                            .foregroundStyle(Palette.textPrimary)
                    }
                    .tint(Palette.lamplight)

                    if app.bedtimeReminderEnabled {
                        DatePicker("At", selection: bedtime,
                                   displayedComponents: .hourAndMinute)
                            .font(Typography.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                .padding(Space.lg)
                .cardSurface()

                languagePicker

                // O que move dinheiro ou sai do app continua atras do portao.
                // Gerenciar assinatura abre a folha da App Store e restaurar
                // chama o dialogo de Apple Account: os dois sao comercio pra
                // Guideline 1.3 e continuam guardados aqui.
                //
                // "Unlock all fifty" nao. Ele so abre a tela de precos, e o
                // portao dela esta um passo adiante, no botao Subscribe.
                if store.isSubscribed {
                    row("crown.fill", "Manage subscription", String(localized: "Active")) {
                        gate = ParentalGateAction { managingSubscription = true }
                    }
                } else {
                    row("lock.open.fill", "Unlock all fifty",
                        String(localized: "\(library.freeStories.count) free now")) {
                        showPaywall = true
                    }
                }

                row("arrow.clockwise", "Restore purchases", restoreLabel) {
                    gate = ParentalGateAction {
                        Task {
                            restoreLabel = String(localized: "Checking…")
                            let ok = await store.restore()
                            restoreLabel = ok
                                ? String(localized: "Restored")
                                : String(localized: "Nothing found")
                        }
                    }
                }
                row("trash", "Erase progress", "") { confirmingReset = true }

                // Tambem aqui, e nao so no paywall: quem ja assinou nao
                // volta naquela tela, e continua tendo direito de reler o
                // que aceitou.
                //
                // Eram `Link`, que abre o Safari no toque. Viraram botao com
                // portao: sair do app e a outra metade da Guideline 1.3, e um
                // documento juridico no navegador e uma crianca fora do app.
                row("doc.text", "Terms of Use", "") {
                    gate = ParentalGateAction { openURL(Legal.terms) }
                }
                row("hand.raised", "Privacy Policy", "") {
                    gate = ParentalGateAction { openURL(Legal.privacy) }
                }
            }
            .padding(.horizontal, Space.screenMargin)
        }
    }

    /// O AppState guarda hora e minuto separados; o DatePicker quer Date.
    private var bedtime: Binding<Date> {
        Binding(
            get: { app.bedtimeDate },
            set: { new in
                let c = Calendar.current.dateComponents([.hour, .minute], from: new)
                app.setBedtime(hour: c.hour ?? 19, minute: c.minute ?? 30)
            })
    }

    /// `title` e sempre chave localizavel. `value` fica String porque
    /// mistura literal (que quem chama passa ja como
    /// `String(localized:)`) com dado do usuario (nome).
    private func row(_ symbol: String, _ title: LocalizedStringKey,
                     _ value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            rowContent(symbol, title, value)
        }
        .buttonStyle(.plain)
    }

    /// O visual da linha, separado da acao: as linhas de documento sao
    /// `Link` e nao `Button`, e sem isso o layout teria de ser escrito duas
    /// vezes e sairia do lugar na primeira mudanca.
    private func rowContent(_ symbol: String, _ title: LocalizedStringKey,
                            _ value: String) -> some View {
        HStack(spacing: Space.md) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 24)
            Text(title)
                .font(Typography.uiEmphasis)
                .foregroundStyle(Palette.textPrimary)
            Spacer()
            Text(value)
                .font(Typography.caption)
                .foregroundStyle(Palette.textTertiary)
            // `chevron.forward` vira automaticamente em RTL. Ver
            // comentario em HomeView.
            Image(systemName: "chevron.forward")
                .font(.system(size: 12))
                .foregroundStyle(Palette.textTertiary)
        }
        .padding(Space.lg)
        .cardSurface()
    }
}

// MARK: - Selo

/// O selo desenhado, com o simbolo do sistema como reserva.
///
/// Sem a imagem instalada o app usa o SF Symbol e nada quebra — que e o
/// que permite gerar os selos depois, ou nunca.
private struct BadgeIcon: View {
    let achievement: Achievement

    /// Setenta e dois.
    ///
    /// Comecou em 24, que e tamanho de glifo, e a arte virava mancha. A 44
    /// ela se lia mas ainda parecia um icone de lista. A 72 e o que o
    /// cartao mostra primeiro — que e o que um selo deveria ser.
    ///
    /// O cartao tem uns 170 pontos de largura e 16 de folga de cada lado,
    /// entao 72 ocupa pouco mais da metade do espaco util e sobra ar dos
    /// dois lados.
    private let side: CGFloat = 72

    var body: some View {
        Group {
            if let art = achievement.art,
               let ui = UIImage(named: "badge-\(art)") {
                // `renderingMode` e `resizable` so existem em `Image`, e
                // `scaledToFit` ja devolve `some View` — depois dele o
                // compilador nao acha nenhum dos dois. A ordem importa e nao
                // e intercambiavel.
                //
                // A arte ja e ambar; trancada, o cinza vem do template.
                Image(uiImage: ui)
                    .renderingMode(achievement.isEarned ? .original : .template)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: achievement.symbol)
                    .font(.system(size: side * 0.6))
            }
        }
        .frame(width: side, height: side)
        .foregroundStyle(achievement.isEarned
                         ? Palette.lamplight : Palette.textTertiary)
    }
}

private struct BadgeTile: View {
    let achievement: Achievement

    var body: some View {
        // Centralizado, e nao alinhado a esquerda.
        //
        // Um selo e uma medalha: o desenho no meio e o nome embaixo. Com o
        // icone grande a esquerda e o texto abaixo dele, o cartao ficava
        // torto — todo o peso num canto e ar sobrando no outro.
        VStack(spacing: Space.sm) {
            BadgeIcon(achievement: achievement)
                .padding(.bottom, Space.xs)

            Text(achievement.title)
                .font(Typography.uiEmphasis)
                .foregroundStyle(achievement.isEarned
                                 ? Palette.textPrimary : Palette.textSecondary)
                .lineLimit(2, reservesSpace: true)

            // Conquistada mostra o que voce fez; nao conquistada mostra
            // quanto falta. Nunca as duas, e nunca "continue assim".
            Text(achievement.isEarned
                 ? achievement.detail
                 : (achievement.remaining ?? ""))
                .font(Typography.caption)
                .foregroundStyle(Palette.textTertiary)
                .lineLimit(2, reservesSpace: true)

            if !achievement.isEarned {
                ProgressBar(value: achievement.progress)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xl)
        .padding(.horizontal, Space.md)
        .cardSurface()
        .opacity(achievement.isEarned ? 1 : 0.72)
        .accessibilityElement(children: .combine)
        // Peca a peca: title, detail e remaining ja chegam localizados
        // do model. Concatenar como verbatim evita duas chaves ruins de
        // simbolo Swift no String Catalog — "%@. %@" nao gera simbolo
        // valido (so caracteres invalidos) e "%@. Not yet. %@" traduz o
        // "Not yet" separado. O texto especifico ("Not earned yet.") tem
        // simbolo distinto do titulo de capitulo "Not Yet" da historia
        // the-seal-who-waits.
        .accessibilityLabel(Text(verbatim: achievement.isEarned
            ? "\(achievement.title). \(achievement.detail)"
            : "\(achievement.title). \(String(localized: "Not earned yet.")) \(achievement.remaining ?? "")"))
    }
}
