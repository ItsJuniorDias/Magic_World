//
//  Magic_WorldApp.swift
//  Magic World
//

import SwiftUI
import UIKit

@main
struct Magic_WorldApp: App {
    @State private var library = ContentLibrary()
    @State private var progress: ReadingProgress
    @State private var player: NarrationPlayer
    @State private var app = AppState()
    @State private var store = Store()
    @State private var analytics = Analytics()
    @State private var packs = StoryPacks()

    @Environment(\.scenePhase) private var scenePhase

    init() {
        let progress = ReadingProgress()
        _progress = State(initialValue: progress)
        _player = State(initialValue: NarrationPlayer(progress: progress))
        Self.applySystemChrome()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Antes dos `.environment`: o modificador le app, store e
                // biblioteca do ambiente que eles montam.
                .modifier(ReminderSync())
                .environment(library)
                .environment(progress)
                .environment(player)
                .environment(app)
                .environment(store)
                .environment(analytics)
                .environment(packs)
        }
        .onChange(of: scenePhase) { _, phase in
            // Sem isso o debounce de gravacao pode ser perdido quando a
            // crianca fecha o app no meio de um capitulo.
            if phase != .active {
                progress.flush()
                app.flush()
                // Manda o que estiver na fila antes de o app dormir: e a
                // ultima chance antes de o sistema poder mata-lo.
                analytics.flush()
            } else {
                analytics.track(.appOpen)
                // O app pode ter dormido durante a virada da semana: com ele
                // suspenso, a espera do FreeWeek nao dispara.
                store.freeWeek.refresh()
            }
        }
    }

    /// A tab bar e a nav bar nativas nao leem o Palette sozinhas — sem isso
    /// elas voltam pro cinza translucido padrao e o app fica com duas
    /// linguagens de cor na mesma tela.
    private static func applySystemChrome() {
        let ink = UIColor(Palette.ink)
        let hairline = UIColor(Palette.hairline)

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = ink
        tab.shadowColor = hairline
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = ink
        nav.shadowColor = .clear
        nav.titleTextAttributes = [.foregroundColor: UIColor(Palette.textPrimary)]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor(Palette.textPrimary)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
    }
}

/// Mantem o lembrete agendado de acordo com o estado do app.
///
/// E um modificador de View, e nao uma propriedade do `App`, porque e no
/// body de uma View que a observacao do SwiftUI acompanha com certeza o
/// `freeWeek.current` — e e isso que faz o plano ser recalculado, e o
/// `.task(id:)` reagendar, quando a semana vira com o app aberto.
private struct ReminderSync: ViewModifier {
    @Environment(AppState.self) private var app
    @Environment(Store.self) private var store
    @Environment(ContentLibrary.self) private var library
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        // Reagenda quando qualquer coisa do plano muda: interruptor, hora,
        // assinatura, a semana virando. Tambem roda a cada lancamento, o que
        // pega troca de idioma.
        content
            .task(id: plan) {
                await ReminderScheduler.sync(plan)
            }
            // E a cada volta ao primeiro plano, porque a permissao nao esta
            // no plano. Ligar o lembrete no perfil muda o plano ANTES de a
            // pessoa responder ao pedido de permissao — a sincronizacao roda,
            // acha `.notDetermined` e nao agenda nada. O proprio alerta do
            // sistema tira o app do ativo e devolve, entao responder "Allow"
            // cai aqui. Cobre tambem quem religa as notificacoes nos Ajustes.
            // `sync` e idempotente: rodar a mais nao duplica nada.
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                let current = plan
                Task { await ReminderScheduler.sync(current) }
            }
    }

    /// O lembrete diario e, pra quem nao assina, as segundas de conto novo.
    private var plan: ReminderScheduler.Plan {
        var plan = ReminderScheduler.Plan(
            enabled: app.bedtimeReminderEnabled,
            hour: app.bedtimeHour,
            minute: app.bedtimeMinute,
            mondays: [])
        guard !store.isSubscribed,
              let current = store.freeWeek.current,
              let schedule = store.freeWeek.schedule
        else { return plan }

        // A semana corrente entra tambem: aberto numa segunda antes da hora
        // do lembrete, o aviso de hoje ainda tem de sair. O agendador pula
        // as que ja passaram.
        let weeks = [current] + schedule.upcoming(
            after: current.start, count: ReminderScheduler.mondaysAhead - 1)
        plan.mondays = weeks.map { week in
            .init(start: week.start,
                  titles: library.stories(ids: week.storyIDs).map(\.localizedTitle))
        }
        return plan
    }
}
