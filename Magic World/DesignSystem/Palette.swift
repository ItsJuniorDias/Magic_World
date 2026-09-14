//
//  Palette.swift
//  Magic World
//
//  Paleta ancorada em "noite": o app e lido na cama, com a luz apagada.
//  O fundo nao e cinza neutro, e azul-preto — as capas sao todas noturnas
//  e um preto neutro atras delas suja o azul da arte.
//
//  Tres acentos, cada um com UM papel. Se um acento comeca a aparecer em
//  dois papeis, o sistema perdeu a funcao e virou decoracao.
//

import SwiftUI

enum Palette {

    // MARK: - Noite (base)

    /// Fundo de tela.
    static let ink = Color(hex: 0x0D0F16)
    /// Cartoes e superficies elevadas.
    static let surface = Color(hex: 0x171A24)
    /// Superficie pressionada, campo de busca, estado ativo da tab bar.
    static let surfaceRaised = Color(hex: 0x212636)
    /// Divisores e contornos de 1px.
    static let hairline = Color(hex: 0x2C3244)

    // MARK: - Texto

    /// Branco levemente quente. Branco puro no escuro brilha demais e
    /// cansa numa sessao de leitura longa.
    static let textPrimary = Color(hex: 0xF2EFE9)
    static let textSecondary = Color(hex: 0x9AA0B4)
    static let textTertiary = Color(hex: 0x646B80)

    // MARK: - Acentos (um papel cada)

    /// Luz de lamparina. Acao primaria, progresso, frase sendo narrada.
    static let lamplight = Color(hex: 0xE9B44C)
    /// Fundo da frase corrente. E o mesmo ambar em opacidade baixa —
    /// destaca sem virar bloco solido atras do texto.
    static let lamplightWash = Color(hex: 0xE9B44C).opacity(0.14)
    /// Assinatura e conteudo pago. Nunca usar em botao de acao comum.
    static let arcane = Color(hex: 0x8B72D9)
    /// Favoritar. So o coracao.
    static let rose = Color(hex: 0xE4677F)

    // MARK: - Estado

    static let success = Color(hex: 0x6FBF8B)
    static let danger = Color(hex: 0xD9524F)

    /// Degrade que sobe da base da capa pra que o titulo tenha contraste
    /// sobre qualquer ilustracao, inclusive as claras.
    static let coverScrim = LinearGradient(
        colors: [.clear, Color(hex: 0x0D0F16).opacity(0.55), Color(hex: 0x0D0F16).opacity(0.95)],
        startPoint: .top,
        endPoint: .bottom
    )
}

extension Color {
    /// Inicializador por inteiro hexadecimal: `Color(hex: 0xE9B44C)`.
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
