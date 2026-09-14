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

    @State private var showPaywall = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                // Uma capa por vez na tela, como no destaque da Home — e por
                // isso que aqui pode animar e a lista nao pode. O MotionCover
                // ja recorta e aplica o degrade, entao nao repetir isso aqui.
                //
                // Sem degrade: no detalhe o titulo vem ABAIXO da capa, nao
                // por cima dela. O escurecimento existe pra segurar texto, e
                // aqui nao ha texto pra segurar.
                MotionCover(story: story, showsScrim: false)
                    .frame(height: 280)
                    .overlay(alignment: .topLeading) {
                        if !store.canOpen(story) { PremiumBadge().padding(Space.md) }
                    }

                VStack(alignment: .leading, spacing: Space.sm) {
                    Text(story.title)
                        .font(Typography.title)
                        .foregroundStyle(Palette.textPrimary)
                    Text(story.creature)
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

                Text(story.summary)
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
            .padding(.horizontal, Space.screenMargin)
            .padding(.vertical, Space.lg)
            .frame(maxWidth: Typography.readingMeasure)
            .frame(maxWidth: .infinity)
        }
        .screenBackground()
        .sheet(isPresented: $showPaywall) { PaywallView(story: story) }
        .navigationTitle(story.title)
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
}

private struct ChapterRow: View {
    let chapter: Chapter
    let isComplete: Bool
    var isLocked = false

    var body: some View {
        HStack(spacing: Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(chapter.title)
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
