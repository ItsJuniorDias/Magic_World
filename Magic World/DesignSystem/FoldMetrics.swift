//
//  FoldMetrics.swift
//  Magic World
//
//  Metricas que dependem do tamanho da tela. O foldable exige um jogo a
//  mais: fechado ele e um iPhone, aberto e outra coisa, e a mesma tela
//  passa dos 375pt de largura pra 700+ ao virar a dobra.
//
//  Ha tres modos que interessam pro app:
//
//    .compact  iPhone Duo fechado (tela externa), iPhone comum.
//              horizontalSizeClass == .compact.
//    .book     iPhone Duo aberto em retrato (livro), iPad em retrato.
//              horizontal == .regular && vertical == .regular.
//    .wide     iPhone Duo aberto em paisagem, iPad em paisagem.
//              horizontal == .regular && vertical == .compact.
//
//  A ideia e nao adivinhar por device: SwiftUI ja informa a size class,
//  e ela reflete o estado da dobra sem precisar de API nova. Se o iPhone
//  Duo tiver uma trait especifica pra dobra (angulo, book/tent), este e
//  o lugar de plugar; por enquanto, size class basta.
//
//  A dobra fisica — a faixa no meio da tela desdobrada — vira
//  `creaseInset`: um espaco horizontal a mais que os splits respeitam.
//  Sem specs oficiais o valor e conservador, e a ideia e ter um numero
//  so pra ajuste posterior em vez de espalhar constantes.
//

import SwiftUI

enum LayoutMode {
    case compact
    case book
    case wide

    /// Ha espaco horizontal pra dividir a tela em duas colunas.
    var isSplittable: Bool { self != .compact }
}

/// Metricas ajustadas ao layout corrente. Tudo que era numero fixo em
/// vista — altura de capa, largura de cartao de prateleira, linha da
/// biblioteca — passa por aqui. Ajustar as tres colunas ajusta o app.
struct FoldMetrics {
    let mode: LayoutMode

    /// Margem lateral padrao. Cresce no aberto pra a coluna nao virar
    /// faixa esticada de ponta a ponta.
    var screenMargin: CGFloat {
        switch mode {
        case .compact: return 20
        case .book, .wide: return 32
        }
    }

    /// Faixa da dobra, no eixo horizontal. Espaco extra entre metades
    /// num split HORIZONTAL: num foldable aberto em retrato (`.book`), a
    /// dobra corre pelo meio verticalmente, entao um split lado-a-lado
    /// tem de respeitar essa zona morta.
    ///
    /// Em `.wide` (paisagem aberto) a dobra corre horizontalmente e uma
    /// inset horizontal nao protege ninguem — nesse caso e um split
    /// VERTICAL que quer folga, e a chave passa a ser `creaseInsetV`.
    /// Enquanto o layout nao usa split em paisagem, fica zero.
    var creaseInset: CGFloat {
        switch mode {
        case .compact: return 0
        case .book:    return 24
        case .wide:    return 0
        }
    }

    /// Contraparte de `creaseInset` para split VERTICAL (empilhado). So
    /// tem valor em `.wide`, onde a dobra atravessa horizontalmente.
    var creaseInsetV: CGFloat {
        switch mode {
        case .compact, .book: return 0
        case .wide:           return 20
        }
    }

    /// Cartao de prateleira horizontal.
    var shelfCard: CGSize {
        switch mode {
        case .compact: return CGSize(width: 164, height: 214)
        case .book:    return CGSize(width: 200, height: 260)
        case .wide:    return CGSize(width: 220, height: 286)
        }
    }

    /// Altura do destaque da Home.
    var heroHeight: CGFloat {
        switch mode {
        case .compact: return 300
        case .book:    return 420
        case .wide:    return 360
        }
    }

    /// Altura da capa no detalhe.
    var coverHeight: CGFloat {
        switch mode {
        case .compact: return 280
        case .book:    return 380
        case .wide:    return 320
        }
    }

    /// Altura da linha na Library.
    var rowHeight: CGFloat {
        switch mode {
        case .compact: return 122
        case .book:    return 148
        case .wide:    return 140
        }
    }
}

// MARK: - Ambiente

private struct FoldMetricsKey: EnvironmentKey {
    static let defaultValue = FoldMetrics(mode: .compact)
}

extension EnvironmentValues {
    /// Metricas resolvidas a partir da size class corrente. Ler em vista
    /// com `@Environment(\.fold) var fold`.
    var fold: FoldMetrics {
        get { self[FoldMetricsKey.self] }
        set { self[FoldMetricsKey.self] = newValue }
    }
}

/// Resolve size class e injeta o `FoldMetrics` no ambiente. Aplicar uma
/// vez no topo da arvore (RootView, OnboardingView) cobre tudo abaixo.
///
/// Fica num modifier em vez de dentro do RootView porque o Onboarding
/// aparece ANTES do TabView e tambem precisa das metricas — sem isso
/// o passo de "Bem-vindo" ficava com 20pt de margem lateral na tela
/// desdobrada de 800+ e o texto virava uma linha ridiculamente longa.
struct FoldAware: ViewModifier {
    @Environment(\.horizontalSizeClass) private var hClass
    @Environment(\.verticalSizeClass) private var vClass

    func body(content: Content) -> some View {
        content.environment(\.fold, FoldMetrics(mode: resolvedMode))
    }

    private var resolvedMode: LayoutMode {
        switch (hClass, vClass) {
        case (.regular, .regular): return .book
        case (.regular, .compact): return .wide
        default:                   return .compact
        }
    }
}

extension View {
    /// Injeta `FoldMetrics` no ambiente com base na size class corrente.
    func foldAware() -> some View {
        modifier(FoldAware())
    }
}
