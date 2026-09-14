//
//  Typography.swift
//  Magic World
//
//  Duas familias, papeis separados:
//
//  - Baloo 2  — titulos. Rounded caloroso de livro infantil, desenhado
//               direito. E o que a Comic Sans do app antigo tentava ser.
//  - Lexend   — corpo e interface. Desenhada a partir de pesquisa de
//               proficiencia de leitura; espacamento e proporcoes ajustados
//               pra aumentar velocidade e reduzir fadiga. Num app onde o
//               produto e o texto lido por crianca, isso e funcao, nao gosto.
//
//  Ambas SIL OFL 1.1, que permite embutir em produto comercial. Conferir o
//  OFL.txt que vem em cada download antes de publicar.
//
//  INSTALACAO
//  1. Arrastar os .ttf para Magic World/Resources/Fonts/
//  2. Build Settings > Info > "Fonts provided by application" (UIAppFonts)
//     com um item por arquivo.
//  3. Rodar `Typography.debugAvailableNames()` uma vez: o nome PostScript
//     quase nunca e o nome do arquivo, e e ele que o SwiftUI quer.
//
//  Enquanto os arquivos nao estiverem no bundle o app cai no rounded do
//  sistema, que e o parente mais proximo do Baloo — nao quebra, so fica
//  menos caracteristico.
//

import SwiftUI
import UIKit

enum Typography {

    private enum Family {
        static let display = "Baloo2-SemiBold"
        static let displayMedium = "Baloo2-Medium"
        static let body = "Lexend-Regular"
        static let bodyMedium = "Lexend-Medium"
        static let bodySemibold = "Lexend-SemiBold"
    }

    /// Escala modular de razao ~1.25, ancorada no corpo de 18pt.
    /// 18 e maior que o corpo padrao de iOS de proposito: o leitor tem 9 anos.
    enum Size {
        static let display: CGFloat = 34
        static let title: CGFloat = 26
        static let heading: CGFloat = 20
        static let body: CGFloat = 18
        static let ui: CGFloat = 16
        static let caption: CGFloat = 13
        static let badge: CGFloat = 12
    }

    // MARK: - Papeis

    /// Titulo da historia sobre a capa.
    static var display: Font {
        custom(Family.display, size: Size.display, relativeTo: .largeTitle, fallbackWeight: .semibold)
    }

    /// Titulo de tela.
    static var title: Font {
        custom(Family.displayMedium, size: Size.title, relativeTo: .title, fallbackWeight: .medium)
    }

    /// Cabecalho de secao e titulo de capitulo.
    static var heading: Font {
        custom(Family.displayMedium, size: Size.heading, relativeTo: .title3, fallbackWeight: .medium)
    }

    /// Texto da historia. O unico tamanho que importa de verdade.
    static var storyBody: Font {
        custom(Family.body, size: Size.body, relativeTo: .body, fallbackWeight: .regular, rounded: false)
    }

    /// Texto de interface: rotulos, resumos, botoes.
    static var ui: Font {
        custom(Family.body, size: Size.ui, relativeTo: .callout, fallbackWeight: .regular, rounded: false)
    }

    static var uiEmphasis: Font {
        custom(Family.bodyMedium, size: Size.ui, relativeTo: .callout, fallbackWeight: .medium, rounded: false)
    }

    /// Metadado: contagem de capitulos, duracao, progresso.
    static var caption: Font {
        custom(Family.bodyMedium, size: Size.caption, relativeTo: .caption, fallbackWeight: .medium, rounded: false)
    }

    /// Selo: PREMIUM, patente. Unico lugar do app com caixa alta.
    static var badge: Font {
        custom(Family.bodySemibold, size: Size.badge, relativeTo: .caption2, fallbackWeight: .semibold, rounded: false)
    }

    // MARK: - Metricas de leitura

    /// Entrelinha do corpo da historia. 0.55 do tamanho da fonte da um
    /// leading de ~1.55, que e o respiro que texto longo em fundo escuro pede.
    static let storyLineSpacing: CGFloat = Size.body * 0.55
    /// Largura maxima da coluna de leitura. Segura a medida perto de
    /// 65 caracteres no iPad em vez de esticar de borda a borda.
    static let readingMeasure: CGFloat = 660

    // MARK: - Resolucao

    private static func custom(
        _ name: String,
        size: CGFloat,
        relativeTo style: Font.TextStyle,
        fallbackWeight: Font.Weight,
        rounded: Bool = true
    ) -> Font {
        if isInstalled(name) {
            // relativeTo mantem o Dynamic Type funcionando com fonte custom.
            return .custom(name, size: size, relativeTo: style)
        }
        return .system(size: size, weight: fallbackWeight, design: rounded ? .rounded : .default)
    }

    private static var installedCache: [String: Bool] = [:]

    private static func isInstalled(_ name: String) -> Bool {
        if let cached = installedCache[name] { return cached }
        let exists = UIFont(name: name, size: 12) != nil
        installedCache[name] = exists
        return exists
    }

    /// True quando as duas familias carregaram. Util num assert de debug.
    static var customFontsLoaded: Bool {
        isInstalled(Family.display) && isInstalled(Family.body)
    }

    /// Imprime os nomes PostScript de tudo que o app enxerga. O nome do
    /// arquivo ("Baloo2-SemiBold.ttf") e o nome PostScript costumam divergir,
    /// e e o segundo que o SwiftUI aceita.
    static func debugAvailableNames() {
        for family in UIFont.familyNames.sorted() {
            let names = UIFont.fontNames(forFamilyName: family)
            print("\(family): \(names.joined(separator: ", "))")
        }
    }
}
