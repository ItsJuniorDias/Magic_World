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
