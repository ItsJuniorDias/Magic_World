//
//  StickyHeader.swift
//  Magic World
//
//  Cabecalho que fica fixo no topo e recolhe conforme a lista rola.
//
//  O PROBLEMA QUE ELE RESOLVE
//
//  A Library empilha busca, escopo e habitats antes da primeira historia.
//  Numa tela de 393 pontos isso come um terco da altura, e some assim que a
//  pessoa rola — junto com a capacidade de trocar de filtro sem voltar pro
//  topo. Filtro que voce precisa procurar nao e filtro, e uma etapa.
//
//  Fixar tudo tambem nao serve: cento e oitenta pontos permanentes num
//  aparelho pequeno deixam duas historias e meia visiveis.
//
//  Entao o cabecalho tem duas alturas. Inteiro quando a lista esta no topo;
//  ao rolar, o que e contexto se apaga e o que e controle continua. Aqui a
//  busca e o escopo saem e os habitats ficam, porque trocar de habitat e o
//  que a pessoa faz varias vezes seguidas enquanto navega.
//
//  COMO
//
//  A posicao vem de `onScrollGeometryChange`, que informa o deslocamento
//  sem GeometryReader dentro do conteudo. GeometryReader ali dentro obriga
//  a LazyVStack a medir mais do que ela quer e desfaz metade do ganho de
//  ser lazy.
//
//  O recolhimento e proporcional ao deslocamento, nao um interruptor num
//  limiar. Interruptor pisca quando o dedo para em cima do limite; a
//  proporcao acompanha o dedo e nunca oscila.
//

import SwiftUI

struct StickyHeader<Expanded: View, Pinned: View, Content: View>: View {
    /// O que existe so no topo. Some ao rolar.
    @ViewBuilder var expanded: () -> Expanded
    /// O que fica sempre. E o unico conteudo do cabecalho recolhido.
    @ViewBuilder var pinned: () -> Pinned
    /// A lista.
    @ViewBuilder var content: () -> Content

    /// Quantos pontos de rolagem levam do inteiro ao recolhido.
    var travel: CGFloat = 72

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = 0
    /// Altura natural do bloco que recolhe, medida na primeira exibicao.
    @State private var expandedHeight: CGFloat = 0

    /// 0 no topo, 1 recolhido.
    private var collapse: CGFloat {
        guard travel > 0 else { return 0 }
        return min(1, max(0, offset / travel))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                content()
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, new in
                offset = new
            }
        }
    }

    private var header: some View {
        VStack(spacing: collapse >= 1 ? 0 : Space.md) {
            // Altura proporcional, medida uma vez.
            //
            // A primeira versao usava `maxHeight: collapse >= 1 ? 0 : nil`,
            // que so zerava no fim: o bloco encolhia visualmente enquanto o
            // espaco continuava reservado inteiro, e ai sumia de um golpe.
            // O recolhimento tem de acompanhar o dedo, entao a altura vem do
            // valor medido vezes (1 - collapse).
            //
            // A medicao e barata porque e um cabecalho pequeno e estatico,
            // fora da lista lazy.
            expanded()
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                    if expandedHeight == 0 { expandedHeight = $0 }
                }
                .opacity(1 - Double(collapse))
                .frame(height: expandedHeight > 0
                       ? expandedHeight * (1 - collapse) : nil,
                       alignment: .top)
                .clipped()
                // Meio caminho ja nao e alvo de toque: botao que aceita
                // dedo enquanto some faz a pessoa acertar o que nao queria.
                .allowsHitTesting(collapse < 0.5)

            pinned()
        }
        .padding(.bottom, Space.md)
        .background {
            // A faixa so ganha fundo e fio quando ha conteudo passando por
            // baixo. No topo ela e parte da tela, nao uma barra.
            Palette.ink
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Palette.hairline)
                        .frame(height: 1)
                        .opacity(Double(collapse))
                }
                .ignoresSafeArea(edges: .horizontal)
        }
        // Sem animacao no recolhimento em si: ele ja acompanha o dedo,
        // quadro a quadro. Animar por cima disso atrasaria o cabecalho em
        // relacao a lista. O que anima e so o fio, que aparece por estado.
        .motion(Motion.state, value: collapse >= 1)
    }
}
