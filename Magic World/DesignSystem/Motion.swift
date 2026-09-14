//
//  Motion.swift
//  Magic World
//
//  As animacoes ja seguiam um padrao antes deste arquivo existir — so que
//  digitado a mao em cada lugar, com deriva. `0.12 easeOut` para toque
//  aparecia identico em tres sitios; `0.2` e `0.22` apareciam para a mesma
//  coisa em dois. E `reduceMotion` era checado em tres dos seis.
//
//  Entao isto nao inventa nada: nomeia o que ja estava la, arruma os dois
//  numeros que divergiam, e tira a checagem de acessibilidade das maos de
//  quem chama.
//
//  DUAS REGRAS
//
//  Nada de mola em conteudo. Mola tem passagem do alvo, e passagem do alvo
//  e movimento a mais numa tela que a crianca olha na hora de dormir. Mola
//  so em resposta a dedo, onde o exagero le como resposta e nao como
//  enfeite.
//
//  Nome por proposito, nao por duracao. `Motion.tap` diz o que esta
//  acontecendo; `.easeOut(duration: 0.12)` obriga quem le a adivinhar. E
//  quando a duracao mudar, muda num lugar so.
//

import SwiftUI

enum Motion {

    // MARK: - Duracoes

    /// Resposta ao dedo. Curto o bastante pra parecer instantaneo e longo
    /// o bastante pra nao piscar.
    static let tapDuration: Double = 0.12
    /// Troca de estado pequena: um chip que seleciona, uma frase que
    /// destaca, um passo de onboarding.
    static let stateDuration: Double = 0.22
    /// Movimento que a pessoa acompanha com o olho: rolar ate uma frase,
    /// um cabecalho que recolhe.
    static let settleDuration: Double = 0.35
    /// Troca de imagem. Longo de proposito: e o unico caso em que o
    /// movimento e o assunto, e nao o efeito colateral de outra coisa.
    static let crossfadeDuration: Double = 0.6
    /// A entrada e a saida da capa em movimento, dentro de cada volta do
    /// loop. Nao tem `Animation` correspondente logo abaixo porque nao e
    /// o SwiftUI que conduz: quem conduz e o relogio do proprio video, em
    /// MotionCover — e por isso que a saida termina no mesmo instante em
    /// que o loop volta.
    ///
    /// Curto demais e a emenda do clipe aparece; longo demais e a capa
    /// passa mais tempo nascendo e morrendo do que rodando. Em clipes de
    /// cinco segundos, 0,9 s deixa mais de tres segundos de video inteiro.
    static let coverFadeDuration: Double = 0.9

    // MARK: - Animacoes nomeadas

    static let tap: Animation = .easeOut(duration: tapDuration)
    static let state: Animation = .easeOut(duration: stateDuration)
    static let settle: Animation = .easeInOut(duration: settleDuration)
    static let crossfade: Animation = .easeIn(duration: crossfadeDuration)

    /// Para arrastar e soltar, onde o dedo dita o ritmo e a mola le como
    /// resposta fisica. Sem passagem do alvo: `bounce: 0`.
    static let follow: Animation = .spring(duration: stateDuration, bounce: 0)
}

// MARK: - Acessibilidade

/// `Reduzir Movimento` nao e sugestao. Quem liga isso tem transtorno
/// vestibular, enjoa com movimento, ou simplesmente nao quer — e nos tres
/// casos a resposta e a mesma.
///
/// A checagem ficava a cargo de quem chamava e por isso estava em metade
/// dos lugares. Estes modificadores fazem sozinhos: com Reduzir Movimento
/// ligado, a mudanca acontece na hora, sem transicao. O estado final e
/// sempre o mesmo — nada some, nada deixa de funcionar.
extension View {
    func motion<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(MotionModifier(animation: animation, value: value))
    }
}

private struct MotionModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

/// Versao imperativa, para `withAnimation`.
@MainActor
func withMotion(_ animation: Animation, _ body: () -> Void) {
    if UIAccessibility.isReduceMotionEnabled {
        body()
    } else {
        withAnimation(animation, body)
    }
}
