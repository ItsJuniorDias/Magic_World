//
//  MotionCover.swift
//  Magic World
//
//  A capa em movimento do destaque da Home.
//
//  Um loop de cinco segundos numa tela de leitura noturna e um risco de
//  tres naturezas, e as tres estao tratadas aqui:
//
//  BATERIA. Video decodificando enquanto ninguem olha e desperdicio puro.
//  Este player para quando o app vai pro fundo, quando a view sai da tela,
//  e nao comeca em Modo de Pouca Energia.
//
//  DESCONFORTO. Movimento continuo e um problema real para quem tem
//  transtorno vestibular, e "Reduzir Movimento" nos Ajustes existe
//  exatamente pra isso. Com ele ligado, a capa fica parada. Nao e um
//  degrade: e a resposta certa.
//
//  EMENDA. Os clipes nao fecham em si mesmos — o ultimo quadro nao e
//  vizinho do primeiro — entao a volta do loop apareceria como um corte
//  seco a cada cinco segundos. Por isso o video entra em fade no comeco
//  de cada volta e sai em fade no fim dela: o corte acontece com a
//  camada em zero, e quem esta na tela naquele instante e a capa parada,
//  que e a mesma arte. A emenda deixa de existir.
//
//  Em todos os casos o fallback e a mesma imagem estatica que o resto do
//  app usa, entao nunca ha buraco na tela.
//

import AVFoundation
import SwiftUI

struct MotionCover: View {
    let story: Story
    /// A capa parada continua sendo o que aparece primeiro e o que fica
    /// quando o video nao roda. O video entra por cima quando comeca.
    var cornerRadius: CGFloat = Radius.cover
    /// O degrade vai ACIMA do video, nao abaixo. Com imagem parada dava pra
    /// conferir a legibilidade uma vez; com video o brilho muda ao longo do
    /// loop, e basta um quadro claro pra engolir o titulo.
    var showsScrim = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var isVisible = false

    private var url: URL? {
        Bundle.main.url(forResource: story.id, withExtension: "mp4")
    }

    /// Pouca Energia e uma decisao do usuario sobre o aparelho inteiro.
    /// Nao cabe ao app decidir que a capa dele e excecao.
    ///
    /// Guardado em estado, e nao lido a cada desenho: como propriedade
    /// computada ele so era reavaliado quando a view redesenhava por outro
    /// motivo, entao ligar Pouca Energia com a Home aberta nao parava
    /// nada — que e exatamente o momento em que a pessoa quer que pare.
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    private var shouldAnimate: Bool {
        url != nil && !reduceMotion && !lowPower
    }

    var body: some View {
        StoryCover(story: story, showsScrim: false)
            .overlay {
                if shouldAnimate, let url {
                    LoopingVideo(url: url, isPlaying: isVisible && scenePhase == .active)
                        // Assimetrica de proposito. A ENTRADA nao anima aqui:
                        // quem faz o fade de entrada e a propria camada de
                        // video, no relogio do clipe, e um segundo fade por
                        // cima so atrasaria o primeiro. A SAIDA continua
                        // precisando: quando Reduzir Movimento ou Pouca
                        // Energia liga no meio da tela, a camada some de uma
                        // vez, e sumir de uma vez e o corte que este arquivo
                        // inteiro existe pra evitar.
                        .transition(.asymmetric(
                            insertion: .identity,
                            removal: .opacity.animation(Motion.crossfade)))
                }
            }
            .overlay { if showsScrim { Palette.coverScrim } }
            .clipShape(.rect(cornerRadius: cornerRadius))
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false }
            .onReceive(NotificationCenter.default.publisher(
                for: .NSProcessInfoPowerStateDidChange)) { _ in
                lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Camada de video

/// AVPlayerLayer cru, sem os controles do VideoPlayer.
///
/// AVPlayerLooper e o jeito certo de repetir: ele enfileira o mesmo item
/// adiante no AVQueuePlayer, entao a volta nao tem o engasgo que
/// `seek(to: .zero)` no fim da reproducao produz.
private struct LoopingVideo: UIViewRepresentable {
    let url: URL
    let isPlaying: Bool
    var fadeDuration: Double = Motion.coverFadeDuration

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.prepare(url: url, fadeDuration: fadeDuration)
        return view
    }

    func updateUIView(_ view: PlayerView, context: Context) {
        isPlaying ? view.play() : view.pause()
    }

    static func dismantleUIView(_ view: PlayerView, coordinator: ()) {
        view.teardown()
    }

    final class PlayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        private var looper: AVPlayerLooper?
        private var player: AVQueuePlayer?
        private var fadeClock: CADisplayLink?
        private var fadeDuration: Double = Motion.coverFadeDuration

        private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

        func prepare(url: URL, fadeDuration: Double) {
            self.fadeDuration = fadeDuration

            let item = AVPlayerItem(url: url)
            let queue = AVQueuePlayer()
            queue.isMuted = true
            // Os loops nao tem faixa de audio, mas silenciar tambem impede
            // que a sessao de audio seja tocada — a narracao e quem manda
            // nela, e uma capa nao pode interromper um capitulo tocando.
            queue.preventsDisplaySleepDuringVideoPlayback = false
            looper = AVPlayerLooper(player: queue, templateItem: item)
            player = queue

            playerLayer.player = queue
            playerLayer.videoGravity = .resizeAspectFill
            // Comeca zerada. O primeiro quadro nao aparece de estalo: ele
            // nasce da capa parada, do mesmo jeito que toda volta do loop.
            playerLayer.opacity = 0

            let clock = CADisplayLink(target: self, selector: #selector(stepFade))
            // `.common`, nao `.default`: a Home e uma ScrollView, e no modo
            // padrao o display link congela enquanto o dedo arrasta. O fade
            // pararia no meio exatamente durante o scroll — que e quando a
            // pessoa mais olha pra capa.
            clock.add(to: .main, forMode: .common)
            // O fade e uma rampa lenta; nao fica mais liso a 120 Hz. Pedir
            // menos deixa o sistema escolher o quadro barato.
            clock.preferredFrameRateRange = CAFrameRateRange(minimum: 20, maximum: 30, preferred: 24)
            clock.isPaused = true
            fadeClock = clock
        }

        func play() {
            player?.play()
            fadeClock?.isPaused = false
        }

        func pause() {
            player?.pause()
            // Sem relogio andando nao ha opacidade nova pra calcular, e
            // manter o display link vivo com o video parado e a mesma
            // conta de bateria que o resto do arquivo evita.
            fadeClock?.isPaused = true
        }

        func teardown() {
            // CADisplayLink RETEM o alvo. Sem invalidate esta view nunca
            // morre, e um player mudo fica decodificando pra ninguem.
            fadeClock?.invalidate()
            fadeClock = nil
            player?.pause()
            looper?.disableLooping()
            playerLayer.player = nil
            player = nil
            looper = nil
        }

        /// A opacidade sai do relogio do proprio video, nao de um timer
        /// paralelo. E o unico jeito de o fim do fade e a volta do loop
        /// serem o mesmo instante depois de uma pausa no meio — um timer
        /// solto acumularia a diferenca e a emenda voltaria a aparecer.
        @objc private func stepFade() {
            guard let item = player?.currentItem else { return }

            let duration = item.duration.seconds
            let time = item.currentTime().seconds
            // Enquanto o item nao fica pronto a duracao vem NaN. Continuar
            // em zero nesse intervalo e o comportamento certo: a capa
            // parada segura a tela ate haver video de verdade pra mostrar.
            guard duration.isFinite, duration > 0, time.isFinite else { return }

            // Clipe curto nao pode ser so entrada e saida: o fade nunca
            // passa de um terco de cada ponta, entao sempre sobra video
            // rodando inteiro no meio.
            let ramp = min(fadeDuration, duration / 3)
            let linear = max(0, min(time / ramp, (duration - time) / ramp, 1))

            // Escrita direta, sem animacao implicita. Isto roda 24 vezes por
            // segundo: se cada valor virasse uma animacao de 0,25 s elas se
            // empilhariam e o fade ficaria arrastado e tremido.
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            playerLayer.opacity = Float(smoothstep(linear))
            CATransaction.commit()
        }

        /// Rampa reta tem canto: da pra ver o quadro exato em que o fade
        /// comeca e o quadro em que ele para. Isto arredonda as duas pontas.
        private func smoothstep(_ t: Double) -> Double {
            t * t * (3 - 2 * t)
        }
    }
}
