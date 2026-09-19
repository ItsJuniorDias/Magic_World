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
    @Environment(StoryPacks.self) private var packs
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var followNarration = true
    /// Fica true entre o fim de um capitulo e a carga do proximo, para
    /// que o encadeamento continue tocando em vez de so virar a pagina.
    @State private var continuePlaying = false
    /// O pacote com os MP3 do conto inteiro, segurado enquanto o leitor
    /// existe — inclusive de tela bloqueada, que e quando o encadeamento de
    /// capitulos precisa dele sem poder contar com rede. Ver StoryPacks.
    @State private var narration: PackAccess?
    /// "Try again" depois de uma falha de download reabre o capitulo.
    @State private var attempt = 0

    init(story: Story, chapterIndex: Int) {
        self.story = story
        _chapterIndex = State(initialValue: chapterIndex)
    }

    private var chapter: Chapter? { story.chapters[safe: chapterIndex] }
    private var timings: ChapterTimings? {
        library.timings(storyId: story.id, chapterIndex: chapterIndex)
    }

    /// Com timings, a segmentacao vem do arquivo; sem, do texto.
    ///
    /// Excecao: se o texto foi traduzido, os timings apontam pra frases
    /// EM INGLES que nao existem na tela — quebrariam a coluna. Nesse
    /// caso caimos no `fallbackSentences`, que quebra o texto traduzido
    /// na frase da lingua alvo. Highlighting perde a sincronia com o
    /// audio (que continua em ingles), mas ao menos o texto sai no
    /// idioma certo. Ver `textIsTranslated`.
    private var sentences: [String] {
        if let timings, !textIsTranslated { return timings.sentences.map(\.text) }
        return chapter?.fallbackSentences ?? []
    }

    /// O texto localizado difere da chave-fonte em ingles.
    private var textIsTranslated: Bool {
        guard let chapter else { return false }
        return chapter.text != chapter.localizedText
    }

    /// O conto tem narracao, mas ela ainda nao esta no aparelho. O texto e
    /// os timings vem do bundle, entao o leitor abre na hora e se le como
    /// texto puro; so a faixa de controles espera o audio.
    ///
    /// Falso fora do ingles: nao ha o que esperar quando nem vamos
    /// baixar o pacote.
    private var narrationPending: Bool {
        guard !narrationNotInThisLanguage else { return false }
        return packs.has(.narration, for: story.id) && narration?.isReady != true
    }

    /// Nao ha narracao na lingua corrente. Ver `ContentLanguage`: a
    /// faixa existe so em ingles, e tocar ingles pra quem escolheu outra
    /// lingua e entregar uma voz que a pessoa nao pediu.
    private var narrationNotInThisLanguage: Bool {
        !ContentLanguage.hasNarration
    }

    /// Sem audio pra seguir, todas as frases ficam acesas — destacar uma
    /// so faria sentido se alguma coisa estivesse andando.
    private var textOnly: Bool {
        narrationNotInThisLanguage || player.narrationUnavailable || narrationPending
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.lg) {
                        if let chapter {
                            Text(chapter.localizedTitle)
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
                    // Traducao muda o numero de frases; o indice do audio
                    // aponta pra outra segmentacao. Rolar por ele levaria
                    // pra uma frase que ninguem esta ouvindo.
                    guard !textIsTranslated else { return }
                    withMotion(Motion.settle) {
                        proxy.scrollTo(new, anchor: .center)
                    }
                }
            }

            controls
        }
        .screenBackground()
        .tint(Palette.lamplight)
        .navigationTitle(story.localizedTitle)
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
        .task(id: [chapterIndex, attempt]) { await open() }
        .onDisappear {
            player.teardown()
            narration?.release()
        }
    }

    // MARK: - Texto

    @ViewBuilder
    private func sentenceView(_ sentence: String, at index: Int) -> some View {
        // `noSync`: nao ha como acender frase-a-frase. Ou nao ha audio,
        // ou o texto na tela esta em outra lingua que a do audio ingles.
        // Em ambos os casos, todas as frases ficam claras.
        let noSync = textOnly || textIsTranslated
        let isCurrent = !noSync && index == player.currentSentenceIndex
        let lit = noSync || isCurrent

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
            if narrationNotInThisLanguage {
                // Antes de tudo: nao e capitulo sem audio nem download
                // pendente, e uma escolha de idioma. Dizer isso e o que
                // separa "ainda nao existe" de "existe, mas nao nesta
                // lingua" — a segunda tem conserto do lado da pessoa.
                // Literal unico com continuacao `\`, nao concatenacao com
                // `+`: "a" + "b" produz String, e Text(String) usa o
                // overload que NAO localiza — a frase saia em ingles em
                // todos os idiomas, que e exatamente o contrario do que
                // ela existe pra dizer.
                Text("""
                The narration is recorded in English only. Set the \
                language to English in You to listen.
                """)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textTertiary)
                    .multilineTextAlignment(.center)
            } else if narrationPending {
                narrationStatus
            } else if player.narrationUnavailable {
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
            .disabled(textOnly)
            .accessibilityLabel("Back fifteen seconds")

            Button { player.toggle() } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Palette.lamplight)
            }
            .disabled(textOnly)
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

            Button { player.skip(by: 15) } label: {
                Image(systemName: "goforward.15")
                    .font(.system(size: 24))
            }
            .disabled(textOnly)
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

    // MARK: - Download da narracao

    /// Ocupa o lugar do slider enquanto o audio nao chegou. Em toda falha a
    /// mensagem lembra que o texto continua ali: a crianca pode seguir lendo
    /// enquanto o adulto resolve a conexao.
    @ViewBuilder
    private var narrationStatus: some View {
        let size = ByteCountFormatter.string(
            fromByteCount: Int64(narration?.bytes ?? 0), countStyle: .file)

        switch narration?.phase ?? .idle {
        case .failed(let failure):
            VStack(spacing: Space.sm) {
                Text(failureMessage(failure, size: size))
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textTertiary)
                    .multilineTextAlignment(.center)
                Button("Try again") { attempt += 1 }
                    .font(Typography.uiEmphasis)
            }
        case .downloading(let fraction):
            VStack(spacing: Space.sm) {
                ProgressView(value: fraction)
                Text("Downloading the narration · \(size)")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textTertiary)
            }
            .accessibilityElement(children: .combine)
        case .idle, .ready:
            // Conferindo se o pacote ja esta no aparelho. Quase sempre dura
            // um instante, entao nada de numero nem de spinner girando.
            ProgressView(value: 0)
        }
    }

    private func failureMessage(_ failure: PackAccess.Failure, size: String) -> String {
        switch failure {
        case .network:
            "Connect to the internet to download the narration (\(size)). You can keep reading meanwhile."
        case .noSpace:
            "There isn't enough space on this device for the narration (\(size)). You can keep reading meanwhile."
        case .other:
            "The narration couldn't be downloaded. You can keep reading meanwhile."
        }
    }

    // MARK: - Apoio

    private func open() async {
        // Fora do ingles nao ha faixa pra tocar, entao nao ha pacote pra
        // baixar. Sao ~5 MB por conto: puxar isso pra deixar parado num
        // player desabilitado gastaria dados e espaco da pessoa a toa.
        // O leitor segue funcionando — e uma tela de texto.
        guard !narrationNotInThisLanguage else { return }

        if narration == nil {
            narration = packs.access(.narration, for: story.id)
        }
        if let narration {
            await narration.load()
            // A tela pode ter fechado, ou o capitulo mudado, durante o
            // download. Carregar o player agora ligaria um audio que ninguem
            // mais esta olhando — a Task do capitulo novo cuida do resto.
            guard !Task.isCancelled, narration.isReady else { return }
        }

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
