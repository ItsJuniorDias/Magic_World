//
//  ScrollRevealedTitle.swift
//  Magic World
//
//  O titulo aparece na barra so quando o texto grande do topo sai de vista.
//
//  O PROBLEMA
//
//  A Home tinha "Magic World" na barra e "Magic World" logo abaixo, ao
//  mesmo tempo. Duas vezes a mesma palavra em cento e cinquenta pontos de
//  tela, e uma delas sem funcao nenhuma enquanto a outra esta visivel.
//
//  Titulo de barra existe pra dizer onde voce esta quando o conteudo que
//  dizia isso ja rolou pra fora. Enquanto ele esta na tela, a barra e
//  repeticao.
//
//  POR QUE NAO USAR O TITULO GRANDE NATIVO
//
//  Porque o texto do topo destas telas nao e um titulo: e "Bom dia,
//  Alexandre" na Home e o nome com o selo de nivel na You. O titulo grande
//  do sistema so aceita uma string.
//
//  E POR QUE O navigationTitle TEM DE SAIR
//
//  Um item `.principal` e um `navigationTitle` definidos ao mesmo tempo
//  disputam o mesmo lugar, e quando o titulo do sistema ganha ele aparece
//  sempre — o efeito some sem erro nenhum, so parece que nada mudou.
//
//  Entao este modificador zera o titulo e assume a barra. O preco e o
//  rotulo do botao voltar nas telas empurradas, que passa a ser "Back" em
//  vez do nome da tela anterior.
//
//  A revelacao e proporcional a rolagem, nao um interruptor num limiar:
//  interruptor pisca quando o dedo para em cima do limite.
//
//  QUANDO COMECAR
//
//  Depois que o texto do topo saiu, nao antes. Eu tinha posto um numero
//  fixo, e ele ficava curto: a barra revelava "Magic World" enquanto o
//  "Magic World" grande ainda estava na tela, e as duas copias coexistiam
//  por um instante. So dava pra ver quando nao havia nome guardado — com
//  nome a linha grande diz outra coisa e a colisao nunca aparecia.
//
//  Numero fixo tambem quebraria no Dynamic Type: com corpo maior a
//  saudacao e mais alta e o gatilho ficaria curto de novo. Entao quem
//  chama informa a altura real do bloco que precisa sair primeiro.
//

import SwiftUI

extension View {
    /// Mostra `title` na barra conforme o conteudo rola.
    ///
    /// - Parameters:
    ///   - after: altura do bloco que precisa sair de vista primeiro. Meca
    ///     com `.measuredHeight(_:)` em vez de estimar — a altura muda com
    ///     o Dynamic Type.
    ///   - ramp: em quantos pontos vai de invisivel a visivel.
    func scrollRevealedTitle(_ title: LocalizedStringKey,
                             after start: CGFloat = 32,
                             ramp: CGFloat = 28) -> some View {
        modifier(ScrollRevealedTitle(title: title, start: start, ramp: ramp))
    }
}

/// Reporta a altura de uma view para um `@State` de quem a hospeda.
extension View {
    func measuredHeight(_ height: Binding<CGFloat>) -> some View {
        onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
            height.wrappedValue = $0
        }
    }
}

private struct ScrollRevealedTitle: ViewModifier {
    let title: LocalizedStringKey
    let start: CGFloat
    let ramp: CGFloat

    @State private var offset: CGFloat = 0

    private var shown: Double {
        guard ramp > 0 else { return offset > start ? 1 : 0 }
        return Double(min(1, max(0, (offset - start) / ramp)))
    }

    func body(content: Content) -> some View {
        content
            // Zera o titulo do sistema: sem isso ele e o item principal
            // disputam a barra e o efeito nao acontece.
            //
            // `Text(verbatim:)` e nao a string vazia direta: como literal,
            // o "" virava uma CHAVE no String Catalog, e chave vazia nao
            // gera nome de simbolo Swift — o build parava com "Unable to
            // derive a symbol name from this key". O Xcode reextraia a
            // cada build, entao apagar do catalogo nao resolvia.
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, new in
                offset = new
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(Typography.uiEmphasis)
                        .foregroundStyle(Palette.textPrimary)
                        .opacity(shown)
                        // Sobe os ultimos pontos junto com a opacidade. E o
                        // que o titulo grande do sistema faz, e sem isso a
                        // aparicao parece um piscar em vez de uma chegada.
                        .offset(y: (1 - shown) * 6)
                        // Acessibilidade nao acompanha opacidade: o leitor
                        // de tela anunciaria um titulo invisivel.
                        .accessibilityHidden(shown < 0.5)
                }
            }
    }
}
