//
//  StoryCards.swift
//  Magic World
//
//  Tres formatos do mesmo conteudo, um por contexto:
//
//  - HeroStoryCard  : destaque da Home. Capa alta, titulo grande.
//  - ShelfStoryCard : cartao de prateleira horizontal.
//  - StoryListRow   : linha da Library, onde o que importa e comparar.
//
//  Todos apoiam no mesmo StoryCover, que resolve arte ausente sem
//  placeholder gritante — enquanto nao ha ilustracao, a superficie leva
//  o simbolo do habitat e fica quieta.
//

import SwiftUI

// MARK: - Capa

struct StoryCover: View {
    let story: Story
    var showsScrim = true

    private var hasArt: Bool {
        !story.coverAsset.isEmpty && UIImage(named: story.coverAsset) != nil
    }

    var body: some View {
        // Color.clear aceita exatamente o tamanho proposto pelo pai; a imagem
        // vai por cima e o .clipped() apara o excesso.
        //
        // O jeito obvio — Image().scaledToFill() solto num ZStack — nao
        // funciona: scaledToFill REPORTA um tamanho maior que o proposto
        // (capa 3:4 numa caixa larga fica 480 de altura, nao 300), o container
        // cresce junto, e qualquer coisa alinhada ao rodape dele vai parar
        // fora da area visivel.
        Color.clear
            .overlay {
                if hasArt {
                    Image(story.coverAsset)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Palette.surfaceRaised
                        Image(systemName: story.realm.symbol)
                            .font(.system(size: 34))
                            .foregroundStyle(Palette.textTertiary.opacity(0.5))
                    }
                }
            }
            .overlay { if showsScrim { Palette.coverScrim } }
            .clipped()
    }
}

// MARK: - Destaque

struct HeroStoryCard: View {
    let story: Story
    var progress: Double = 0
    /// Vem do HomeView com literais ("Continue reading", "Start here").
    /// LocalizedStringKey pra o String Catalog extrair as chaves — String
    /// puro deixaria o eyebrow em ingles em todos os idiomas.
    var eyebrow: LocalizedStringKey?

    @Environment(Store.self) private var store
    /// Destaque cresce com o espaco disponivel: 300 no iPhone fechado,
    /// 420 aberto em livro. Ver `FoldMetrics.heroHeight`.
    @Environment(\.fold) private var fold

    var body: some View {
        MotionCover(story: story)
            .frame(height: fold.heroHeight)
            // overlay, nao ZStack: overlay e dimensionado pela view que
            // hospeda, entao o texto fica ancorado na altura real do cartao.
            .overlay(alignment: .bottomLeading) { caption }
            .overlay(alignment: .topLeading) {
                if !store.canOpen(story) { PremiumBadge().padding(Space.md) }
            }
            .clipShape(.rect(cornerRadius: Radius.cover))
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            if let eyebrow {
                Text(eyebrow)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.lamplight)
            }
            Text(story.localizedTitle)
                .font(Typography.display)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
            Text(story.localizedCreature)
                .font(Typography.ui)
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(2)
            if progress > 0 {
                ProgressBar(value: progress).padding(.top, Space.xs)
            }
        }
        .padding(Space.lg)
    }
}

// MARK: - Prateleira

struct ShelfStoryCard: View {
    let story: Story

    @Environment(Store.self) private var store
    /// A largura do cartao vem do modo de layout: 164 no iPhone fechado,
    /// 200 aberto em livro, 220 em paisagem. Sem isso, a prateleira num
    /// foldable desdobrado mostra oito capas em miniatura em vez de tres
    /// ou quatro do tamanho certo.
    @Environment(\.fold) private var fold

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            StoryCover(story: story, showsScrim: false)
                .frame(width: fold.shelfCard.width, height: fold.shelfCard.height)
                .clipShape(.rect(cornerRadius: Radius.cover))
                .overlay(alignment: .topLeading) {
                    if !store.canOpen(story) { PremiumBadge().padding(Space.sm) }
                }

            Text(story.localizedTitle)
                .font(Typography.uiEmphasis)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(2, reservesSpace: true)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.leading)

            Text(story.localizedCreature)
                .font(Typography.caption)
                .foregroundStyle(Palette.textTertiary)
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)
        }
        .frame(width: fold.shelfCard.width, alignment: .leading)
    }
}

// MARK: - Linha da biblioteca

struct StoryListRow: View {
    let story: Story
    let completion: Double
    let isFavorite: Bool
    let onToggleFavorite: () -> Void

    @Environment(Store.self) private var store
    /// Altura da linha vem do modo de layout — a mesma linha compacta
    /// que serve num iPhone de 375pt fica anemica num foldable aberto.
    /// Ver `FoldMetrics.rowHeight`.
    @Environment(\.fold) private var fold

    /// Todas as linhas tem a altura da capa. Sem isso a lista fica com
    /// cartoes de alturas diferentes conforme o titulo caiba em uma ou
    /// duas linhas, e o olho le isso como bagunca antes de ler qualquer
    /// palavra.
    private var rowHeight: CGFloat { fold.rowHeight }

    var body: some View {
        HStack(alignment: .top, spacing: Space.lg) {
            StoryCover(story: story, showsScrim: false)
                .frame(width: 92, height: rowHeight)
                .clipShape(.rect(cornerRadius: Radius.card))

            VStack(alignment: .leading, spacing: Space.xs) {
                // reservesSpace mantem a altura de duas linhas mesmo quando
                // o titulo cabe em uma. minimumScaleFactor evita truncar os
                // titulos longos do acervo em vez de encolher um pouco.
                Text(story.localizedTitle)
                    .font(Typography.uiEmphasis)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(2, reservesSpace: true)
                    .minimumScaleFactor(0.85)

                Text(story.localizedCreature)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(2, reservesSpace: true)

                Spacer(minLength: 0)

                metadata

                // Sempre ocupa a altura, mesmo sem progresso: caso contrario
                // uma historia comecada fica com o cartao mais alto que as
                // outras e a lista volta a desalinhar.
                ProgressBar(value: completion)
                    .opacity(completion > 0 ? 1 : 0)
            }
            .frame(height: rowHeight)

            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 17))
                    .foregroundStyle(isFavorite ? Palette.rose : Palette.textTertiary)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFavorite ? "Remove from favourites" : "Add to favourites")
        }
        .padding(Space.md)
        .cardSurface()
    }

    /// Simbolo e rotulo separados em vez de Label: o Label quebra o texto
    /// em duas linhas quando a coluna aperta, e "Open Skies" fazia isso.
    private var metadata: some View {
        HStack(spacing: Space.xs) {
            Image(systemName: story.realm.symbol)
            Text(story.realm.label)
            Text("·")
            Text(story.durationLabel)
            if !store.canOpen(story) {
                Image(systemName: "crown.fill")
                    .foregroundStyle(Palette.arcane)
            }
        }
        .font(Typography.caption)
        .foregroundStyle(Palette.textTertiary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

// MARK: - Pilula de habitat

struct RealmChip: View {
    let realm: Story.Realm
    let isSelected: Bool

    var body: some View {
        HStack(spacing: Space.xs) {
            Image(systemName: realm.symbol)
            Text(realm.label)
        }
        .font(Typography.caption)
        .foregroundStyle(isSelected ? Palette.ink : Palette.textSecondary)
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
        .background(
            isSelected ? Palette.lamplight : Palette.surfaceRaised,
            in: .rect(cornerRadius: Radius.pill)
        )
    }
}

/// Cabecalho de prateleira. Sem "ver tudo →": a seta grudada em texto de
/// link e enfeite, e a Library ja e o "ver tudo" do app.
struct ShelfHeader: View {
    /// Titulo e sempre chave de traducao — vem do codigo, com literal.
    let title: LocalizedStringKey
    /// Contagem a direita, quando houver. "5 de 16" ao lado de "Badges"
    /// diz mais que o titulo sozinho e nao ocupa linha propria.
    /// Chega ja localizado por quem chama (via `String(localized:)`).
    var subtitle: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Typography.heading)
                .foregroundStyle(Palette.textPrimary)
            if let subtitle {
                Spacer()
                Text(subtitle)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textTertiary)
                    .monospacedDigit()
            }
        }
            .padding(.horizontal, Space.screenMargin)
    }
}
