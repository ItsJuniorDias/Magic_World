//
//  ContentView.swift
//  Magic World
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        RootView()
    }
}

/// Host do preview: player e progresso precisam nascer juntos e sobreviver
/// aos redraws.
private struct PreviewHost: View {
    @State private var library = ContentLibrary()
    @State private var progress: ReadingProgress
    @State private var player: NarrationPlayer
    @State private var app = AppState(filename: "preview-app-state.json")
    @State private var store = Store()
    @State private var analytics = Analytics()
    @State private var packs = StoryPacks()

    init() {
        let progress = ReadingProgress(filename: "preview-progress.json")
        _progress = State(initialValue: progress)
        _player = State(initialValue: NarrationPlayer(progress: progress))
    }

    var body: some View {
        ContentView()
            .environment(library)
            .environment(progress)
            .environment(player)
            .environment(app)
            .environment(store)
            .environment(analytics)
            .environment(packs)
    }
}

#Preview {
    PreviewHost()
}
