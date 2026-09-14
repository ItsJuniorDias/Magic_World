//
//  Layout.swift
//  Magic World
//
//  Espacamento, raio e os poucos componentes que se repetem.
//
//  O raio varia por papel, de proposito. Um raio unico em tudo — capa,
//  cartao e botao com o mesmo canto — e o que faz interface parecer kit
//  pronto: some a hierarquia entre o que e conteudo e o que e controle.
//

import SwiftUI

enum Space {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let huge: CGFloat = 48

    /// Margem lateral padrao das telas.
    static let screenMargin: CGFloat = 20
}

enum Radius {
    /// Arte de capa. O maior, porque e o conteudo.
    static let cover: CGFloat = 20
    /// Cartoes e superficies.
    static let card: CGFloat = 16
    /// Botoes e campos.
    static let control: CGFloat = 12
    /// Selos e pilulas.
    static let pill: CGFloat = 999
}

// MARK: - Componentes

/// Selo de conteudo pago. Roxo, nunca ambar: assinatura nao e acao.
struct PremiumBadge: View {
    var body: some View {
        HStack(spacing: Space.xs) {
            Image(systemName: "crown.fill")
            Text("Premium")
        }
        .font(Typography.badge)
        .tracking(0.6)
        .textCase(.uppercase)
        .foregroundStyle(Palette.textPrimary)
        .padding(.horizontal, Space.sm)
        .padding(.vertical, 5)
        .background(Palette.arcane.opacity(0.9), in: .rect(cornerRadius: Radius.pill))
    }
}

/// Patente do leitor. Mesma forma do selo premium, cor diferente, porque
/// e conquista e nao trava.
struct RankBadge: View {
    let label: String

    var body: some View {
        Text(label)
            .font(Typography.badge)
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundStyle(Palette.lamplight)
            .padding(.horizontal, Space.md)
            .padding(.vertical, 6)
            .background(Palette.lamplight.opacity(0.12), in: .rect(cornerRadius: Radius.pill))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.pill)
                    .stroke(Palette.lamplight.opacity(0.35), lineWidth: 1)
            )
    }
}

/// Botao de acao primaria.
struct LamplightButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.uiEmphasis)
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.lg)
            .background(Palette.lamplight, in: .rect(cornerRadius: Radius.control))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            // Movimento so responde a acao do dedo; nada se mexe sozinho.
            .motion(Motion.tap, value: configuration.isPressed)
    }
}

/// Botao secundario, sem preenchimento.
struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.uiEmphasis)
            .foregroundStyle(Palette.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.lg)
            .background(Palette.surfaceRaised, in: .rect(cornerRadius: Radius.control))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .motion(Motion.tap, value: configuration.isPressed)
    }
}

/// Barra de progresso fina. Usada na capa e na jornada do perfil.
struct ProgressBar: View {
    let value: Double
    var tint: Color = Palette.lamplight

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.hairline)
                Capsule()
                    .fill(tint)
                    .frame(width: geo.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: 4)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(min(max(value, 0), 1) * 100)) percent")
    }
}

extension View {
    /// Fundo de tela padrao, ignorando as safe areas.
    func screenBackground() -> some View {
        background(Palette.ink.ignoresSafeArea())
    }

    /// Superficie de cartao.
    func cardSurface(radius: CGFloat = Radius.card) -> some View {
        background(Palette.surface, in: .rect(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Palette.hairline, lineWidth: 1)
            )
    }
}
