//
//  ReaderView.swift
//  Magic World
//
//  A tela onde o app se decide. Tudo aqui serve a uma coisa: acompanhar a
//  frase que esta sendo narrada sem esforco, no escuro.
//
//  O destaque nao e um bloco solido atras do texto. E o inverso: o que ja
//  passou e o que ainda vem escurecem, e a frase corrente fica na luz —
//  com um lavado ambar de baixa opacidade so pra ancorar o olho de quem
//  ainda esta aprendendo a seguir a linha.
//

import SwiftUI

/// O `.plain` nao esmaece botao desabilitado de forma confiavel e nao da
/// nenhum retorno ao toque. Num controle de audio, onde a pessoa toca sem
/// olhar, os dois importam.
private struct TransportButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? (configuration.isPressed ? 0.55 : 1) : 0.28)
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .motion(Motion.tap, value: configuration.isPressed)
            .contentShape(.rect)
    }
}

struct ReaderView: View {
    let story: Story
    @State private var chapterIndex: Int

    @Environment(ContentLibrary.self) private var library
    @Environment(ReadingProgress.self) private var progress
    @Environment(NarrationPlayer.self) private var player
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var followNarration = true
    /// Fica true entre o fim de um capitulo e a carga do proximo, para
    /// que o encadeamento continue tocando em vez de so virar a pagina.
    @State private var continuePlaying = false

    init(story: Story, chapterIndex: Int) {
        self.story = story
        _chapterIndex = State(initialValue: chapterIndex)
    }

    private var chapter: Chapter? { story.chapters[safe: chapterIndex] }
    private var timings: ChapterTimings? {
        library.timings(storyId: story.id, chapterIndex: chapterIndex)
    }

    /// Com timings, a segmentacao vem do arquivo; sem, do texto.
    private var sentences: [String] {
        if let timings { return timings.sentences.map(\.text) }
        return chapter?.fallbackSentences ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.lg) {
                        if let chapter {
                            Text(chapter.title)
                                .font(Typography.heading)
                                .foregroundStyle(Palette.lamplight)
                                .padding(.bottom, Space.xs)
                        }

                        ForEach(Array(sentences.enumerated()), id: \.offset) { index, sentence in
                            sentenceView(sentence, at: index)
                        }
                    }
                    .padding(.horizontal, Space.screenMargin)
                    .padding(.top, Space.xl)
                    .padding(.bottom, Space.huge)
                    .frame(maxWidth: Typography.readingMeasure, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .onChange(of: player.currentSentenceIndex) { _, new in
                    guard followNarration, new >= 0 else { return }
                    withMotion(Motion.settle) {
                        proxy.scrollTo(new, anchor: .center)
                    }
                }
            }

            controls
        }
        .screenBackground()
        .tint(Palette.lamplight)
        .navigationTitle(story.title)
        .navigationBarTitleDisplayMode(.inline)
        // Sem isso a tab bar flutuante fica por cima dos controles de audio.
        // O leitor e tela de foco: nada de navegacao lateral competindo.
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Reading speed", selection: Binding(
                        get: { player.rate },
                        set: { player.rate = $0 }
                    )) {
                        ForEach([0.75, 1.0, 1.25, 1.5] as [Float], id: \.self) { value in
                            Text(speedLabel(value)).tag(value)
                        }
                    }
                    Toggle("Follow the narration", isOn: $followNarration)
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
            }
        }
        .task(id: chapterIndex) { open() }
        .onDisappear { player.teardown() }
    }

    // MARK: - Texto

    @ViewBuilder
    private func sentenceView(_ sentence: String, at index: Int) -> some View {
        let isCurrent = index == player.currentSentenceIndex
        let lit = player.narrationUnavailable || isCurrent

        Text(sentence)
            .font(Typography.storyBody)
            .lineSpacing(Typography.storyLineSpacing)
            .foregroundStyle(lit ? Palette.textPrimary : Palette.textSecondary)
            .padding(.horizontal, Space.sm)
            .padding(.vertical, Space.xs)
            .background(
                isCurrent ? Palette.lamplightWash : .clear,
                in: .rect(cornerRadius: Radius.control)
            )
            .id(index)
            .contentShape(.rect)
            .onTapGesture { player.seekToSentence(index) }
            .motion(Motion.state, value: isCurrent)
    }

    // MARK: - Controles

    @ViewBuilder
    private var controls: some View {
        VStack(spacing: Space.md) {
            if player.narrationUnavailable {
                Text("Narration for this chapter hasn't been added yet.")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textTertiary)
            } else {
                Slider(
                    value: Binding(
                        get: { player.currentTime },
                        set: { player.seek(to: $0) }
                    ),
                    in: 0...max(player.duration, 1)
                )

                HStack {
                    Text(timeLabel(player.currentTime))
                    Spacer()
                    Text(timeLabel(player.duration))
                }
                .font(Typography.caption)
                .monospacedDigit()
                .foregroundStyle(Palette.textTertiary)
            }

            // Fora do else: sem narracao o leitor ainda precisa poder
            // trocar de capitulo.
            transport
        }
        .padding(.horizontal, Space.screenMargin)
        .padding(.top, Space.lg)
        .padding(.bottom, Space.sm)
        .background(
            Palette.surface
                .overlay(alignment: .top) { Palette.hairline.frame(height: 1) }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    /// Cinco botoes numa linha so, na ordem em que um audiolivro coloca:
    /// capitulo, quinze segundos, tocar, quinze segundos, capitulo. Os de
    /// capitulo ficam menores e mais apagados de proposito — quem esta
    /// ouvindo usa o do meio o tempo todo e os das pontas raramente.
    ///
    /// Nas bordas da historia eles ficam desabilitados em vez de sumirem,
    /// senao a linha inteira se reposiciona no primeiro e no ultimo
    /// capitulo.
    private var transport: some View {
        HStack(spacing: Space.xl) {
            Button { goToChapter(chapterIndex - 1) } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 20))
            }
            .disabled(chapterIndex == 0)
            .accessibilityLabel("Previous chapter")

            Button { player.skip(by: -15) } label: {
                Image(systemName: "gobackward.15")
                    .font(.system(size: 24))
            }
            .disabled(player.narrationUnavailable)
            .accessibilityLabel("Back fifteen seconds")

            Button { player.toggle() } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Palette.lamplight)
            }
            .disabled(player.narrationUnavailable)
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

            Button { player.skip(by: 15) } label: {
                Image(systemName: "goforward.15")
                    .font(.system(size: 24))
            }
            .disabled(player.narrationUnavailable)
            .accessibilityLabel("Forward fifteen seconds")

            Button { goToChapter(chapterIndex + 1) } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 20))
            }
            .disabled(chapterIndex >= story.chapters.count - 1)
            .accessibilityLabel("Next chapter")
        }
        .buttonStyle(TransportButtonStyle())
        .foregroundStyle(Palette.textSecondary)
        .frame(maxWidth: .infinity)
    }

    /// Trocar de capitulo com o dedo mantem o audio tocando, do mesmo jeito
    /// que o encadeamento automatico faz. Quem esta ouvindo e pula um
    /// capitulo quer o proximo tocando, nao uma pagina parada.
    private func goToChapter(_ index: Int) {
        guard story.chapters.indices.contains(index) else { return }
        continuePlaying = player.isPlaying
        chapterIndex = index
    }

    // MARK: - Apoio

    private func open() {
        player.load(story: story, chapterIndex: chapterIndex,
                    timings: timings, autoplay: continuePlaying)
        continuePlaying = false

        player.onChapterFinished = { wasPlaying in
            if chapterIndex < story.chapters.count - 1 {
                continuePlaying = wasPlaying
                chapterIndex += 1
            } else if !wasPlaying {
                // So volta sozinho se a pessoa estava lendo. Se o capitulo
                // acabou de tocar com a tela bloqueada, fechar a tela nao
                // ajuda ninguem.
                dismiss()
            }
        }
    }

    private func speedLabel(_ value: Float) -> String {
        value == 1.0 ? "Normal" : String(format: "%g×", value)
    }

    private func timeLabel(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
