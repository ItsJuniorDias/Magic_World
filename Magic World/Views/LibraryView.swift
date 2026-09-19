//
//  LibraryView.swift
//  Magic World
//
//  O acervo inteiro, com dois eixos de filtro que nao se sobrepoem:
//  o escopo (tudo / favoritas / comecadas) e o habitat.
//
//  Sem aba de "Favoritos" separada: favorito e um recorte da biblioteca,
//  nao um lugar diferente. O app antigo tinha as duas coisas e as telas
//  eram identicas.
//

import SwiftUI

struct LibraryView: View {
    @Environment(ContentLibrary.self) private var library
    @Environment(ReadingProgress.self) private var progress
    @Environment(AppState.self) private var app

    @Binding var selectedRealm: Story.Realm?
    @State private var scope: Scope = .all
    @State private var search = ""

    enum Scope: String, CaseIterable, Identifiable {
        case all, favourites, started
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: String(localized: "All")
            case .favourites: String(localized: "Favourites")
            case .started: String(localized: "Started")
            }
        }
    }

    var body: some View {
        NavigationStack {
            // Escopo recolhe, habitat fica. Escopo e um modo que a pessoa
            // define uma vez; habitat e o que ela troca varias vezes
            // seguidas enquanto navega, e filtro que some ao rolar obriga a
            // voltar ao topo pra usar.
            StickyHeader {
                scopePicker
            } pinned: {
                realmFilter
            } content: {
                LazyVStack(alignment: .leading, spacing: Space.lg) {
                    if filtered.isEmpty {
                        emptyState
                    } else {
                        ForEach(filtered) { story in
                            NavigationLink(value: story) {
                                StoryListRow(
                                    story: story,
                                    completion: progress.completion(of: story),
                                    isFavorite: app.isFavorite(story.id),
                                    onToggleFavorite: { app.toggleFavorite(story.id) }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, Space.screenMargin)
                    }
                }
                .padding(.bottom, Space.huge)
            }
            .screenBackground()
            .navigationTitle("Library")
            // Titulo grande abre um vao vazio acima do campo de busca.
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.ink, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .searchable(text: $search, prompt: "Search stories and creatures")
            .navigationDestination(for: Story.self) { StoryDetailView(story: $0) }
        }
        .tint(Palette.lamplight)
    }

    // MARK: - Filtros

    private var scopePicker: some View {
        Picker("Scope", selection: $scope) {
            ForEach(Scope.allCases) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, Space.screenMargin)
        .padding(.top, Space.sm)
    }

    private var realmFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.sm) {
                Button {
                    selectedRealm = nil
                } label: {
                    Text("Everywhere")
                        .font(Typography.caption)
                        .foregroundStyle(selectedRealm == nil ? Palette.ink : Palette.textSecondary)
                        .padding(.horizontal, Space.md)
                        .padding(.vertical, Space.sm)
                        .background(
                            selectedRealm == nil ? Palette.lamplight : Palette.surfaceRaised,
                            in: .rect(cornerRadius: Radius.pill)
                        )
                }
                .buttonStyle(.plain)

                ForEach(library.populatedRealms) { realm in
                    Button {
                        // Tocar no habitat ja selecionado limpa o filtro.
                        selectedRealm = (selectedRealm == realm) ? nil : realm
                    } label: {
                        RealmChip(realm: realm, isSelected: selectedRealm == realm)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Space.screenMargin)
        }
    }

    // MARK: - Resultado

    private var filtered: [Story] {
        var result = library.stories

        if let selectedRealm {
            result = result.filter { $0.realm == selectedRealm }
        }

        switch scope {
        case .all:
            break
        case .favourites:
            result = result.filter { app.isFavorite($0.id) }
        case .started:
            result = result.filter { progress.completion(of: $0) > 0 }
        }

        let query = search.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            // Busca nos campos LOCALIZADOS e nos ingleses — assim uma
            // pessoa em pt-BR encontra "raposa" e uma pessoa procurando
            // pelo nome ingles ("fox") tambem acha.
            result = result.filter {
                $0.localizedTitle.localizedCaseInsensitiveContains(query)
                || $0.localizedCreature.localizedCaseInsensitiveContains(query)
                || $0.localizedSummary.localizedCaseInsensitiveContains(query)
                || $0.title.localizedCaseInsensitiveContains(query)
                || $0.creature.localizedCaseInsensitiveContains(query)
                || $0.summary.localizedCaseInsensitiveContains(query)
            }
        }

        return result.sorted { $0.publishedAt > $1.publishedAt }
    }

    /// Estado vazio diz o que fazer, nao so que esta vazio.
    private var emptyState: some View {
        VStack(spacing: Space.sm) {
            Image(systemName: emptyIcon)
                .font(.system(size: 34))
                .foregroundStyle(Palette.textTertiary)
            Text(emptyMessage)
                .font(Typography.ui)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.huge)
    }

    private var emptyIcon: String {
        switch scope {
        case .favourites: "heart"
        case .started: "book"
        case .all: "magnifyingglass"
        }
    }

    /// LocalizedStringKey pra o Text a seguir pegar o overload que
    /// localiza — String levaria a chave em branco no idioma alvo.
    private var emptyMessage: LocalizedStringKey {
        if !search.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Nothing matches that. Try a creature's name."
        }
        switch scope {
        case .favourites: return "Tap the heart on a story to keep it here."
        case .started: return "Stories you begin will show up here."
        case .all: return "No stories in this part of the world yet."
        }
    }
}
