//
//  NarrationPlayer.swift
//  Magic World
//
//  Toca a narracao pre-gerada do capitulo e publica o indice da sentenca
//  corrente para o read-along.
//
//  Categoria .playback + modo .spokenAudio + politica .longFormAudio:
//  e isso que faz o iOS tratar o app como audiolivro — continua com a tela
//  bloqueada, aparece direito na tela de bloqueio e no CarPlay, e pausa
//  (em vez de abaixar) quando outro audio entra.
//

import Foundation
import AVFoundation
import MediaPlayer
import Observation
import OSLog
import UIKit

@MainActor
@Observable
final class NarrationPlayer {

    // MARK: - Estado publicado

    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var currentSentenceIndex = -1
    private(set) var isLoaded = false
    /// Capitulo aberto sem MP3 correspondente: a UI mostra so o texto.
    private(set) var narrationUnavailable = false

    var rate: Float = 1.0 {
        didSet {
            rate = min(max(rate, 0.75), 1.5)
            if isPlaying { player?.rate = rate }
            updateNowPlaying()
        }
    }

    var progressFraction: Double {
        duration > 0 ? min(currentTime / duration, 1) : 0
    }

    /// Disparado quando a narracao chega ao fim. O Bool diz se estava
    /// tocando — quem encadeia usa isso pra decidir entre continuar
    /// tocando ou so avancar a pagina.
    var onChapterFinished: ((Bool) -> Void)?

    // MARK: - Privado

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var timings: ChapterTimings?
    private var story: Story?
    private var chapterIndex = 0
    private var wasPlayingBeforeInterruption = false
    private var remoteTargets: [(MPRemoteCommand, Any)] = []

    private let progress: ReadingProgress
    private let log = Logger(subsystem: "com.alexandre.juniort10.magicworld", category: "audio")

    init(progress: ReadingProgress) {
        self.progress = progress
    }

    // MARK: - Ciclo de vida

    /// Prepara um capitulo. Retomar de onde parou e o default.
    ///
    /// `autoplay` existe por causa do segundo plano: quando um capitulo
    /// acaba com a tela bloqueada, quem encadeia o proximo e este objeto,
    /// nao a interface. Sem isso o audio simplesmente para no fim de cada
    /// capitulo e a pessoa tem de desbloquear o telefone pra continuar.
    func load(story: Story, chapterIndex: Int, timings: ChapterTimings?,
              resume: Bool = true, autoplay: Bool = false) {
        teardown()

        self.story = story
        self.chapterIndex = chapterIndex
        self.timings = timings
        currentSentenceIndex = -1
        currentTime = 0
        duration = timings?.duration ?? story.chapters[safe: chapterIndex]?.audioDuration ?? 0

        guard let name = story.chapters[safe: chapterIndex]?.audioFile,
              let url = Bundle.main.url(forResource: name, withExtension: "mp3")
        else {
            narrationUnavailable = true
            isLoaded = false
            log.notice("sem narracao para \(story.id) cap \(chapterIndex)")
            return
        }

        narrationUnavailable = false
        configureSession()

        let item = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.actionAtItemEnd = .pause
        player = avPlayer

        addTimeObserver(to: avPlayer)
        addEndObserver(for: item)
        addInterruptionObserver()
        configureRemoteCommands()

        if resume {
            let saved = progress.position(storyId: story.id, chapterIndex: chapterIndex)
            // Perto do fim, recomecar o capitulo e menos irritante que cair no ultimo segundo.
            if saved > 1, duration == 0 || saved < duration - 5 {
                seek(to: saved)
            }
        }

        isLoaded = true
        updateNowPlaying()
        if autoplay { play() }
    }

    func play() {
        guard let player else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            log.error("sessao de audio nao ativou: \(error.localizedDescription)")
        }
        player.play()
        // Depois do play(): setar a taxa antes do item ficar pronto faz o
        // AVPlayer zerar ela de volta.
        player.rate = rate
        isPlaying = true
        updateNowPlaying()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        persistPosition()
        updateNowPlaying()
    }

    func toggle() {
        isPlaying ? pause() : play()
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        let clamped = min(max(0, time), duration > 0 ? duration : time)
        let target = CMTime(seconds: clamped, preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = clamped
        refreshSentence(at: clamped)
        updateNowPlaying()
    }

    func skip(by seconds: TimeInterval) {
        seek(to: currentTime + seconds)
    }

    /// Pula para o inicio de uma sentenca — usado ao tocar no texto.
    func seekToSentence(_ index: Int) {
        guard let start = timings?.startTime(ofSentence: index) else { return }
        seek(to: start)
    }

    /// Libera tudo. Chamar no onDisappear do leitor.
    func teardown() {
        persistPosition()
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }
        interruptionObserver = nil
        removeRemoteCommands()
        player?.pause()
        player = nil
        isPlaying = false
        isLoaded = false
        // Depois do persistPosition la em cima, que ainda precisa do tempo.
        // Sem zerar, o proximo leitor herda a frase destacada do conto
        // anterior enquanto a narracao dele baixa.
        currentTime = 0
        currentSentenceIndex = -1
        narrationUnavailable = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Sessao

    private func configureSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .spokenAudio,
                policy: .longFormAudio,
                options: []
            )
        } catch {
            log.error("categoria de audio falhou: \(error.localizedDescription)")
        }
    }

    private func addTimeObserver(to player: AVPlayer) {
        // 4 ticks por segundo: suficiente para o destaque nao ficar atrasado
        // sem redesenhar o texto sem necessidade.
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.currentTime = time.seconds
                if self.duration == 0,
                   let itemDuration = player.currentItem?.duration.seconds,
                   itemDuration.isFinite {
                    self.duration = itemDuration
                }
                self.refreshSentence(at: time.seconds)
                self.persistPositionThrottled()
            }
        }
    }

    private func addEndObserver(for item: AVPlayerItem) {
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let story = self.story else { return }
                let wasPlaying = self.isPlaying
                self.isPlaying = false
                self.progress.markComplete(storyId: story.id, chapterIndex: self.chapterIndex)
                self.onChapterFinished?(wasPlaying)
            }
        }
    }

    /// Ligacao, Siri, outro app: pausa e, se o sistema pedir, retoma sozinho.
    private func addInterruptionObserver() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            MainActor.assumeIsolated {
                guard let self,
                      let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: raw)
                else { return }

                switch type {
                case .began:
                    self.wasPlayingBeforeInterruption = self.isPlaying
                    self.pause()
                case .ended:
                    guard let optionsRaw = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw)
                    if options.contains(.shouldResume), self.wasPlayingBeforeInterruption {
                        self.play()
                    }
                @unknown default:
                    break
                }
            }
        }
    }

    // MARK: - Read-along

    private func refreshSentence(at time: TimeInterval) {
        guard let timings else { return }
        let index = timings.sentenceIndex(at: time)
        if index != currentSentenceIndex {
            currentSentenceIndex = index
        }
    }

    // MARK: - Posicao

    private var lastPersist: TimeInterval = 0

    private func persistPositionThrottled() {
        guard currentTime - lastPersist > 5 || currentTime < lastPersist else { return }
        lastPersist = currentTime
        persistPosition()
    }

    private func persistPosition() {
        guard let story, currentTime > 0 else { return }
        progress.record(storyId: story.id, chapterIndex: chapterIndex, position: currentTime)
    }

    // MARK: - Tela de bloqueio

    private func updateNowPlaying() {
        guard let story, let chapter = story.chapters[safe: chapterIndex] else { return }
        var info: [String: Any] = [
            // Tela de bloqueio segue o idioma da UI, mesmo com audio ingles.
            MPMediaItemPropertyTitle: chapter.localizedTitle,
            MPMediaItemPropertyAlbumTitle: story.localizedTitle,
            MPMediaItemPropertyArtist: "Magic World",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(rate) : 0,
            MPNowPlayingInfoPropertyIsLiveStream: false
        ]
        if duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        if !story.coverAsset.isEmpty, let image = UIImage(named: story.coverAsset) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func configureRemoteCommands() {
        removeRemoteCommands()
        let center = MPRemoteCommandCenter.shared()

        let play = center.playCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.play() }
            return .success
        }
        remoteTargets.append((center.playCommand, play))

        let pause = center.pauseCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.pause() }
            return .success
        }
        remoteTargets.append((center.pauseCommand, pause))

        center.skipForwardCommand.preferredIntervals = [15]
        let forward = center.skipForwardCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.skip(by: 15) }
            return .success
        }
        remoteTargets.append((center.skipForwardCommand, forward))

        center.skipBackwardCommand.preferredIntervals = [15]
        let back = center.skipBackwardCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.skip(by: -15) }
            return .success
        }
        remoteTargets.append((center.skipBackwardCommand, back))

        let scrub = center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            MainActor.assumeIsolated { self?.seek(to: event.positionTime) }
            return .success
        }
        remoteTargets.append((center.changePlaybackPositionCommand, scrub))
    }

    private func removeRemoteCommands() {
        for (command, target) in remoteTargets {
            command.removeTarget(target)
        }
        remoteTargets = []
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
