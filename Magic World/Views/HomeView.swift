//
//  HomeView.swift
//  Magic World
//
//  As prateleiras do app antigo eram "Most Watched" e contagem de views,
//  que vinham do Firestore. Sem backend nao existe contador, e inventar um
//  numero falso no cliente seria pior que nao ter.
//
//  Entao toda prateleira aqui sai de dado que o aparelho realmente tem:
//  o que a crianca comecou, o que foi publicado recentemente, os habitats,
//  e o que ela ja pode ler sem pagar.
//

import SwiftUI

struct HomeView: View {
    @Environment(ContentLibrary.self) private var library
    @Environment(ReadingProgress.self) private var progress
    @Environment(AppState.self) private var app
    @Environment(Store.self) private var store

    @State private var showPaywall = false
    /// Altura real da saudacao. A barra so revela o titulo depois que ela
    /// saiu, senao "Magic World" aparece em cima e embaixo ao mesmo tempo.
    @State private var greetingHeight: CGFloat = 0

    @Binding var selectedRealm: Story.Realm?
    @Binding var selectedTab: RootView.Tab

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Space.xxl) {
                    greeting

                    if !store.isSubscribed && !library.stories.isEmpty {
                        unlockBanner
                    }

                    if let hero = heroStory {
                        NavigationLink(value: hero.story) {
                            HeroStoryCard(
                                story: hero.story,
                                progress: hero.progress,
                                eyebrow: hero.eyebrow
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, Space.screenMargin)
                    }

                    if !continueReading.isEmpty {
                        shelf("Pick up where you left off", stories: continueReading)
                    }

                    realmsRow

                    if !newlyPublished.isEmpty {
                        shelf("Just arrived", stories: newlyPublished)
                    }

                    if !freeToStart.isEmpty {
                        shelf("Free to start", stories: freeToStart)
                    }

                    if library.stories.isEmpty { emptyState }
                }
                .padding(.bottom, Space.huge)
            }
            .screenBackground()
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .scrollRevealedTitle("Magic World", after: greetingHeight)
            // A barra precisa ser opaca: transparente, o conteudo rolado
            // sobe por tras dela e colide com a status bar.
            .toolbarBackground(Palette.ink, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationDestination(for: Story.self) { StoryDetailView(story: $0) }
        }
        .tint(Palette.lamplight)
    }

    // MARK: - Cabecalho

    private var greeting: some View {
        // A hora sempre em cima, em ambar. Embaixo, o nome de quem le — ou o
        // nome do app, que aqui nao repete nada: a barra so mostra "Magic
        // World" depois que esta linha sai de vista, que e o que o titulo
        // revelado faz. Eu tinha tirado isto pra resolver uma repeticao que
        // a propria revelacao ja tinha resolvido.
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(timeGreeting)
                .font(Typography.caption)
                .foregroundStyle(Palette.lamplight)
            Text(app.hasReaderName ? "Hello, \(app.greetingName)" : "Magic World")
                .font(Typography.title)
                .foregroundStyle(Palette.textPrimary)
        }
        .padding(.horizontal, Space.screenMargin)
        .padding(.top, Space.md)
        .measuredHeight($greetingHeight)
    }

    /// Uma linha, sem alarde, e some no instante em que a pessoa assina.
    /// Um app infantil nao deve empurrar assinatura toda hora.
    ///
    /// Abre o paywall direto. O portao parental nao esta mais na porta da
    /// tela de precos — esta no botao Subscribe, dentro dela. Ver
    /// `PaywallView.callToAction`.
    private var unlockBanner: some View {
        Button { showPaywall = true } label: {
            HStack(spacing: Space.md) {
                Image(systemName: "lock.open.fill")
                    .foregroundStyle(Palette.arcane)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(library.freeStories.count) stories free")
                        .font(Typography.uiEmphasis)
                        .foregroundStyle(Palette.textPrimary)
                    Text("Unlock the other \(library.stories.count - library.freeStories.count)")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textTertiary)
            }
            .padding(Space.lg)
            .cardSurface()
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Space.screenMargin)
    }

    private var timeGreeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning"
        case 12..<18: "Good afternoon"
        default: "Good evening"
        }
    }

    // MARK: - Prateleiras

    @ViewBuilder
    private func shelf(_ title: String, stories: [Story]) -> some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            ShelfHeader(title: title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: Space.lg) {
                    ForEach(stories) { story in
                        NavigationLink(value: story) {
                            ShelfStoryCard(story: story)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Space.screenMargin)
            }
        }
    }

    private var realmsRow: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            ShelfHeader(title: "Where they live")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.md) {
                    ForEach(library.populatedRealms) { realm in
                        Button {
                            // Filtrar habitat leva pra Library com o filtro
                            // aplicado, em vez de abrir uma terceira tela
                            // que faria a mesma coisa.
                            selectedRealm = realm
                            selectedTab = .library
                        } label: {
                            RealmChip(realm: realm, isSelected: false)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Space.screenMargin)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Space.md) {
            Image(systemName: "books.vertical")
                .font(.system(size: 40))
                .foregroundStyle(Palette.textTertiary)
            Text("No stories yet")
                .font(Typography.heading)
                .foregroundStyle(Palette.textPrimary)
            Text(library.loadErrors.isEmpty
                 ? "Add story files to Content/Stories and list their ids in stories.json."
                 : library.loadErrors.joined(separator: "\n"))
                .font(Typography.ui)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.huge)
    }

    // MARK: - Selecao

    /// O destaque e sempre o que ela ja comecou. Se nao comecou nada,
    /// a mais recente. Retomar vale mais que descobrir.
    private var heroStory: (story: Story, progress: Double, eyebrow: String)? {
        if let inProgress = continueReading.first {
            return (inProgress, progress.completion(of: inProgress), "Continue reading")
        }
        // Quem ainda nao comecou nada ve uma historia que pode abrir. Botar a
        // mais recente no destaque coloca um cadeado como primeira coisa da
        // primeira sessao, e isso e um paywall antes de qualquer valor.
        if let newestFree = library.recentlyPublished.first(where: \.isFree) {
            return (newestFree, 0, "Start here")
        }
        if let newest = library.recentlyPublished.first {
            return (newest, 0, "Start here")
        }
        return nil
    }

    private var continueReading: [Story] {
        library.stories
            .filter { story in
                let done = progress.completion(of: story)
                return done > 0 && done < 1
            }
            .sorted { progress.completion(of: $0) > progress.completion(of: $1) }
    }

    /// Tira o destaque da prateleira pra nao aparecer duas vezes na mesma tela.
    private var newlyPublished: [Story] {
        library.recentlyPublished
            .filter { $0.id != heroStory?.story.id }
            .prefix(8)
            .map { $0 }
    }

    private var freeToStart: [Story] {
        library.freeStories.filter { progress.completion(of: $0) == 0 }
    }
}
