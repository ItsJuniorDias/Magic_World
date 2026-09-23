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
    @Environment(StoryPacks.self) private var packs

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

                    // Logo depois do que ela ja comecou: pra quem nao assina,
                    // e o que da pra abrir agora, e muda toda segunda.
                    if !store.isSubscribed && !freeThisWeek.isEmpty {
                        shelf("Free this week", stories: freeThisWeek)
                    }

                    realmsRow

                    if !newlyPublished.isEmpty {
                        shelf("Just arrived", stories: newlyPublished)
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
            // Os gratis da semana nao vem mais instalados com o app — mudam
            // toda segunda. Adiantar a narracao deles aqui devolve o que a
            // instalacao inicial garantia: quem nao assina ouve o conto
            // gratis numa noite sem sinal. O id refaz o pedido na virada, e
            // fica vazio pra quem assina — inclusive no lancamento, antes de
            // a assinatura ser conferida, quando `isSubscribed` ainda e falso
            // pra todo mundo e isto baixaria ~15 MB a toa.
            .task(id: freeNarrationToPrefetch) {
                guard ContentLanguage.hasNarration else { return }
                for id in freeNarrationToPrefetch {
                    packs.prefetch(.narration, for: id)
                }
            }
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
            // Ternario com Text separado em vez de operar sobre a string:
            // Text(String) usa o overload que NAO localiza. Duas Text
            // literais preservam o LocalizedStringKey, e o nome vira %@ na
            // chave "Hello, %@".
            Group {
                if app.hasReaderName {
                    Text("Hello, \(app.greetingName)")
                } else {
                    Text("Magic World")
                }
            }
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
                    Text("\(freeThisWeek.count) stories free this week")
                        .font(Typography.uiEmphasis)
                        .foregroundStyle(Palette.textPrimary)
                    Text("New ones every Monday")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                // `chevron.forward` (nao `.right`): a variante semantica
                // vira sozinha em RTL. Chevron.right ficaria apontando pro
                // lado errado em arabe.
                Image(systemName: "chevron.forward")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textTertiary)
            }
            .padding(Space.lg)
            .cardSurface()
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Space.screenMargin)
    }

    /// LocalizedStringKey em vez de String: sem isso, Text(timeGreeting)
    /// resolve pelo overload de StringProtocol e o app fica com "Good
    /// morning" em ingles mesmo em pt-BR.
    private var timeGreeting: LocalizedStringKey {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning"
        case 12..<18: "Good afternoon"
        default: "Good evening"
        }
    }

    // MARK: - Prateleiras

    @ViewBuilder
    private func shelf(_ title: LocalizedStringKey, stories: [Story]) -> some View {
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

    /// O destaque e sempre o que ela ja comecou e ainda pode abrir. Se nao
    /// ha, um gratis da semana que ela nao comecou. Retomar vale mais que
    /// descobrir.
    ///
    /// `eyebrow` volta como `LocalizedStringKey` pra o `HeroStoryCard`
    /// pegar o overload de Text que localiza — String traria os literais
    /// em ingles no idioma alvo.
    private var heroStory: (story: Story, progress: Double, eyebrow: LocalizedStringKey)? {
        // So o que ainda abre. Um conto gratis que trancou na virada da
        // semana continua na prateleira de retomar, com o cadeado — mas
        // nao no destaque, que viraria um "Continue reading" que nao continua.
        if let inProgress = continueReading.first(where: { store.canOpen($0) }) {
            return (inProgress, progress.completion(of: inProgress), "Continue reading")
        }
        // Quem ainda nao comecou nada ve uma historia que pode abrir. Botar a
        // mais recente no destaque coloca um cadeado como primeira coisa da
        // primeira sessao, e isso e um paywall antes de qualquer valor.
        // Se ja leu os tres, um deles mesmo assim — como o destaque antigo
        // fazia com o gratis mais novo. Qualquer outro seria um cadeado.
        if !store.isSubscribed,
           let free = freeThisWeek.first(where: { progress.completion(of: $0) == 0 })
                ?? freeThisWeek.first {
            return (free, 0, "Start here")
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

    /// Os tres da semana, na ordem do calendario — inclusive os que ela ja
    /// comecou ou terminou: a prateleira mostra o lote da semana inteiro,
    /// pra ficar claro o que abre agora e o que tranca na segunda.
    private var freeThisWeek: [Story] {
        library.stories(ids: store.freeWeek.storyIDs)
    }

    private var freeNarrationToPrefetch: [String] {
        guard store.hasCheckedEntitlements, !store.isSubscribed else { return [] }
        return store.freeWeek.storyIDs
    }
}
