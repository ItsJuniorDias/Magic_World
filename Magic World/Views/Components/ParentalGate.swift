//
//  ParentalGate.swift
//  Magic World
//
//  Portao parental. Guideline 1.3 — Safety, Kids Category.
//
//  A Apple exige que um app na categoria Kids peca permissao do responsavel
//  ANTES de duas coisas: sair do app (Safari, mail, App Store) e entrar em
//  qualquer fluxo de compra. Foi por isto que a versao 1.5 (120) foi
//  recusada.
//
//  TRES REGRAS QUE NAO PODEM SER QUEBRADAS
//
//  1. O portao nao pode ser desabilitado. Nao existe ajuste, chave, nem
//     "nao perguntar de novo".
//  2. Nada e lembrado entre uma apresentacao e outra. Sem UserDefaults,
//     sem janela de cinco minutos, sem "ja passou uma vez nesta sessao".
//     A conta e sorteada de novo toda vez, e o estado zera no onAppear.
//  3. O portao vem ANTES da acao. Quem chama guarda a acao aqui e ela so
//     roda depois que a conta foi resolvida.
//
//  Se alguem no futuro quiser "melhorar a experiencia" guardando que o
//  portao ja foi passado, isso e exatamente o que a revisao procura.
//
//  ONDE O PORTAO ESTA HOJE
//
//  Ele guarda o ATO, nao a tela que fala do ato. Sao tres lugares:
//
//      - PaywallView, botao Subscribe  — abre a folha de pagamento
//      - ProfileView, Manage / Restore — folha da App Store e Apple Account
//      - Terms e Privacy, onde aparecem — abrem o Safari
//
//  A tela de precos em si nao tem portao na porta: olhar preco nao e
//  comprar. Se a revisao discordar disso, o caminho de volta esta no
//  comentario de `RootView.autoPresentsIntroPaywall`.
//
//  COMO USAR
//
//      @State private var gate: ParentalGateAction?
//
//      Button { gate = ParentalGateAction { Task { await buy() } } } label: {
//          ...
//      }
//
//      // no final da tela, uma vez so:
//      .parentalGate($gate)
//

import Foundation
import SwiftUI

// MARK: - Regras

private enum GateRules {
    /// Tabuada do 1 ao 9. Mudar aqui e o unico lugar que precisa mudar se
    /// um dia a conta tiver de ficar mais dificil.
    static let factors = 1...9
    /// Depois disto o portao fecha a porta e manda chamar um adulto. Serve
    /// pra tentativa por forca bruta nao ser caminho.
    static let maxAttempts = 3
    /// O produto maximo e 81, entao dois digitos bastam.
    static let maxDigits = 2
    /// Largura da coluna no iPad. O app foi revisado num iPad Air de 11" e
    /// um teclado esticado de borda a borda naquela tela fica ridiculo.
    static let measure: CGFloat = 380
}

// MARK: - Acao guardada

/// A acao que so acontece depois que a conta foi resolvida.
///
/// E `Identifiable` de proposito: `fullScreenCover(item:)` recria a tela a
/// cada nova acao, e recriar e o que garante conta nova e tentativas
/// zeradas. Com `isPresented` a mesma instancia poderia sobreviver.
struct ParentalGateAction: Identifiable {
    let id = UUID()
    let run: () -> Void

    init(_ run: @escaping () -> Void) {
        self.run = run
    }
}

extension View {
    /// Apresenta o portao quando houver acao pendente, e so entao a executa.
    func parentalGate(_ action: Binding<ParentalGateAction?>) -> some View {
        modifier(ParentalGateModifier(action: action))
    }
}

private struct ParentalGateModifier: ViewModifier {
    @Binding var action: ParentalGateAction?

    func body(content: Content) -> some View {
        content.fullScreenCover(item: $action) { pending in
            ParentalGateView(
                onPass: {
                    let run = pending.run
                    action = nil
                    // O atraso nao e enfeite. Abrir o Safari ou apresentar o
                    // paywall no mesmo ciclo em que a folha esta saindo faz
                    // o UIKit engolir a segunda apresentacao — o portao
                    // fecha e nao acontece nada.
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(350))
                        run()
                    }
                },
                onCancel: { action = nil }
            )
        }
    }
}

// MARK: - Tela

struct ParentalGateView: View {
    let onPass: () -> Void
    let onCancel: () -> Void

    @State private var left = 1
    @State private var right = 1
    @State private var typed = ""
    @State private var attemptsLeft = GateRules.maxAttempts
    @State private var shake = 0

    private var isLocked: Bool { attemptsLeft <= 0 }
    private var answer: Int { left * right }

    var body: some View {
        ZStack {
            Palette.ink.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Space.xl) {
                    header

                    if isLocked {
                        locked
                    } else {
                        question
                        display
                        keypad
                    }

                    Button("Not now", action: onCancel)
                        .buttonStyle(QuietButtonStyle())
                }
                .padding(.horizontal, Space.screenMargin)
                .padding(.vertical, Space.xxl)
                .frame(maxWidth: GateRules.measure)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear(perform: reset)
    }

    // MARK: Topo

    private var header: some View {
        VStack(spacing: Space.md) {
            // Cinza, e nao ambar nem roxo. Os dois acentos tem papel
            // proprio no app — acao e assinatura — e um icone decorativo
            // aqui gastaria um deles a toa.
            Image(systemName: "figure.and.child.holdinghands")
                .font(.system(size: 44))
                .foregroundStyle(Palette.textSecondary)

            Text("Ask a grown-up")
                .font(Typography.title)
                .foregroundStyle(Palette.textPrimary)

            Text("A grown-up needs to answer this before we continue.")
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Conta

    private var question: some View {
        // Em algarismo. Por extenso o enunciado tambem servia de barreira de
        // leitura pra quem ainda nao le bem — se um dia isso fizer falta, e
        // esta linha que volta a ser texto.
        //
        // O sinal e o "×" de multiplicacao (U+00D7), nao a letra x: o VoiceOver
        // le "times" com ele e "x" com a letra.
        Text("What is \(left) × \(right)?")
            .font(Typography.title)
            .monospacedDigit()
            .foregroundStyle(Palette.textPrimary)
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.isHeader)
    }

    private var display: some View {
        VStack(spacing: Space.sm) {
            Text(typed.isEmpty ? " " : typed)
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Palette.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 72)
                .cardSurface(radius: Radius.control)
                .modifier(ShakeEffect(travel: CGFloat(shake)))

            if attemptsLeft < GateRules.maxAttempts {
                Text("Not quite. \(attemptsLeft) \(attemptsLeft == 1 ? "try" : "tries") left.")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textTertiary)
            }
        }
    }

    // MARK: Teclado

    private var keypad: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: Space.md), count: 3),
            spacing: Space.md
        ) {
            ForEach(1...9, id: \.self) { digit in
                key("\(digit)") { type(digit) }
            }
            key(symbol: "delete.left") { _ = typed.popLast() }
            key("0") { type(0) }
            key(symbol: "checkmark", tint: Palette.lamplight, action: check)
                .disabled(typed.isEmpty)
                .opacity(typed.isEmpty ? 0.4 : 1)
        }
    }

    private func key(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Typography.heading)
                .monospacedDigit()
                .foregroundStyle(Palette.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Palette.surfaceRaised, in: .rect(cornerRadius: Radius.control))
        }
        .buttonStyle(.plain)
    }

    private func key(symbol: String,
                     tint: Color = Palette.textSecondary,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Palette.surfaceRaised, in: .rect(cornerRadius: Radius.control))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol == "checkmark" ? "Check answer" : "Delete")
    }

    // MARK: Bloqueio

    private var locked: some View {
        VStack(spacing: Space.md) {
            Image(systemName: "lock.fill")
                .font(.system(size: 28))
                .foregroundStyle(Palette.textTertiary)
            Text("Let's try again later.")
                .font(Typography.uiEmphasis)
                .foregroundStyle(Palette.textPrimary)
            Text("Ask a grown-up to help you with this one.")
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, Space.xxl)
    }

    // MARK: Logica

    private func type(_ digit: Int) {
        guard typed.count < GateRules.maxDigits else { return }
        typed.append(String(digit))
    }

    private func check() {
        guard Int(typed) == answer else {
            attemptsLeft -= 1
            typed = ""
            // Conta nova a cada erro: sem isso, errar vira tentativa e erro
            // sobre a mesma pergunta, que e justamente o que uma crianca faz.
            newChallenge()
            withMotion(Motion.settle) { shake += 1 }
            return
        }
        onPass()
    }

    /// Chamado no `onAppear`. Todo estado nasce aqui e morre com a tela —
    /// e o que garante que nada seja lembrado entre uma vez e outra.
    private func reset() {
        newChallenge()
        typed = ""
        attemptsLeft = GateRules.maxAttempts
    }

    private func newChallenge() {
        left = Int.random(in: GateRules.factors)
        right = Int.random(in: GateRules.factors)
    }
}

// MARK: - Erro

/// Uma sacudida so, de ida e volta, a cada resposta errada.
///
/// Vai junto com `withMotion`, que ja verifica Reduzir Movimento: com a
/// opcao ligada o valor salta direto pro fim e o deslocamento termina em
/// zero, entao nada se mexe e nada fica torto.
private struct ShakeEffect: GeometryEffect {
    var travel: CGFloat

    var animatableData: CGFloat {
        get { travel }
        set { travel = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(translationX: 8 * sin(travel * .pi * 3), y: 0)
        )
    }
}

#Preview {
    ParentalGateView(onPass: {}, onCancel: {})
}
