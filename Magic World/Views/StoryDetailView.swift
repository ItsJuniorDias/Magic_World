//
//  StoryDetailView.swift
//  Magic World
//
//  Saiu de dentro do LibraryView: agora tres telas navegam pra ca.
//

import SwiftUI

struct StoryDetailView: View {
    let story: Story

    @Environment(ReadingProgress.self) private var progress
    @Environment(AppState.self) private var app
    @Environment(Store.self) private var store
    @Environment(StoryPacks.self) private var packs
    /// Capa cresce com o espaco: 280 no iPhone fechado, 380 aberto em
    /// livro. Ver `FoldMetrics.coverHeight`.
    @Environment(\.fold) private var fold

    @State private var showPaywall = false

    var body: some View {
        ScrollView {
            // Em `.book` (foldable aberto em retrato) a tela vira dois
            // paineis, capa a esquerda e texto+capitulos a direita, com a
            // faixa da dobra reservada. Em `.compact` e `.wide` cai no
            // empilhado de sempre — a coluna unica de leitura ancora em
            // `readingMeasure` como antes.
            if fold.mode == .book {
                HStack(alignment: .top, spacing: fold.creaseInset) {
                    coverBlock
                        .frame(maxWidth: .infinity)
                    textBlock
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, fold.screenMargin)
                .padding(.vertical, Space.lg)
            } else {
                VStack(alignment: .leading, spacing: Space.xl) {
                    coverBlock
                    textBlock
                }
                .padding(.horizontal, Space.screenMargin)
                .padding(.vertical, Space.lg)
                .frame(maxWidth: Typography.readingMeasure)
                .frame(maxWidth: .infinity)
            }
        }
        .screenBackground()
        // Quem pode abrir o conto provavelmente vai abrir: a narracao desce
        // enquanto a pessoa le o resumo, e o leitor ja abre com audio. O id
        // faz o prefetch disparar tambem logo depois de assinar aqui mesmo.
        // Conto trancado nao baixa nada — ver StoryPacks.
        // Fora do ingles nao ha narracao pra ouvir (ver ContentLanguage),
        // entao nao ha nada que valha a pena adiantar.
        .task(id: store.canOpen(story)) {
            if store.canOpen(story), ContentLanguage.hasNarration {
                packs.prefetch(.narration, for: story.id)
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView(story: story) }
        .navigationTitle(story.localizedTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    app.toggleFavorite(story.id)
                } label: {
                    Image(systemName: app.isFavorite(story.id) ? "heart.fill" : "heart")
                        .foregroundStyle(app.isFavorite(story.id) ? Palette.rose : Palette.textSecondary)
                }
                .accessibilityLabel(app.isFavorite(story.id) ? "Remove from favourites" : "Add to favourites")
            }
        }
    }

    // MARK: - Blocos

    /// A capa em movimento, dimensionada pelo modo de layout. Vive num
    /// bloco separado pra poder migrar entre coluna unica (empilhado) e
    /// painel esquerdo (book) sem duplicar codigo.
    ///
    /// O MotionCover ja recorta e aplica o degrade. Sem degrade aqui: no
    /// detalhe o titulo vem ABAIXO da capa, nao por cima dela — o
    /// escurecimento existe pra segurar texto e aqui nao ha texto pra
    /// segurar.
    private var coverBlock: some View {
        MotionCover(story: story, showsScrim: false)
            .frame(height: fold.coverHeight)
            .overlay(alignment: .topLeading) {
                if !store.canOpen(story) { PremiumBadge().padding(Space.md) }
            }
    }

    /// Titulo, resumo, botao de acao e lista de capitulos. E o que vai
    /// pra direita no split em book mode.
    private var textBlock: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            VStack(alignment: .leading, spacing: Space.sm) {
                Text(story.localizedTitle)
                    .font(Typography.title)
                    .foregroundStyle(Palette.textPrimary)
                Text(story.localizedCreature)
                    .font(Typography.uiEmphasis)
                    .foregroundStyle(Palette.lamplight)
            }

            HStack(spacing: Space.md) {
                Label(story.realm.label, systemImage: story.realm.symbol)
                Text("\(story.chapters.count) chapters")
                Text(story.durationLabel)
            }
            .font(Typography.caption)
            .foregroundStyle(Palette.textTertiary)

            Text(story.localizedSummary)
                .font(Typography.storyBody)
                .lineSpacing(Typography.storyLineSpacing * 0.6)
                .foregroundStyle(Palette.textPrimary)

            if store.canOpen(story) {
                if let resume = progress.resumeChapter(of: story) {
                    NavigationLink {
                        ReaderView(story: story, chapterIndex: resume.index)
                    } label: {
                        Text(progress.completion(of: story) > 0
                             ? "Continue reading" : "Start reading")
                    }
                    .buttonStyle(LamplightButtonStyle())
                }
            } else {
                // Abre a tela de precos direto. O portao parental mora no
                // botao Subscribe la dentro — ver PaywallView.callToAction.
                Button { showPaywall = true } label: {
                    Label("Unlock all fifty stories", systemImage: "lock.fill")
                }
                .buttonStyle(LamplightButtonStyle())
            }

            VStack(alignment: .leading, spacing: Space.md) {
                Text("Chapters")
                    .font(Typography.heading)
                    .foregroundStyle(Palette.textPrimary)

                ForEach(story.chapters) { chapter in
                    if store.canOpen(story) {
                        NavigationLink {
                            ReaderView(story: story, chapterIndex: chapter.index)
                        } label: {
                            ChapterRow(
                                chapter: chapter,
                                isComplete: progress.isComplete(
                                    storyId: story.id, chapterIndex: chapter.index),
                                isLocked: false
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button { showPaywall = true } label: {
                            ChapterRow(chapter: chapter, isComplete: false, isLocked: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct ChapterRow: View {
    let chapter: Chapter
    let isComplete: Bool
    var isLocked = false

    var body: some View {
        HStack(spacing: Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(chapter.localizedTitle)
                    .font(Typography.uiEmphasis)
                    .foregroundStyle(isLocked ? Palette.textSecondary : Palette.textPrimary)
                Text("\(chapter.wordCount) words")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textTertiary)
            }
            Spacer()
            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.arcane)
            } else if isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.lamplight)
            }
        }
        .padding(Space.lg)
        .cardSurface()
    }
}
