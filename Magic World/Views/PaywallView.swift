//
//  PaywallView.swift
//  Magic World
//
//  Nada de preco escrito no codigo. Tudo que aparece aqui — valor, moeda,
//  periodo, teste gratis, economia do anual — sai do proprio Product, ja
//  formatado no locale de quem esta olhando.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    /// O conto que levou o usuario ate aqui, quando houver. Um paywall que
    /// diz o que voce estava tentando abrir converte melhor que um generico,
    /// e e mais honesto.
    var story: Story?

    /// Esta folha apareceu sozinha, logo depois do onboarding, sem ninguem
    /// tocar em nada. Acrescenta a saida no corpo da tela — ver `callToAction`.
    /// Nas outras tres entradas (faixa da Home, conto trancado, ajustes) fica
    /// falso: ali a pessoa pediu pra chegar, e o "Close" da barra basta.
    var isIntro = false

    @Environment(Store.self) private var store
    @Environment(Analytics.self) private var analytics
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var selected: Product.ID?
    /// Acao segurada pelo portao parental ate um adulto resolver a conta.
    @State private var gate: ParentalGateAction?
    @State private var isPurchasing = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    header
                    benefits

                    if store.isLoading && store.products.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Space.xl)
                    } else if let error = store.loadError {
                        unavailable(error)
                    } else {
                        options
                        callToAction
                    }

                    legal
                }
                .padding(.horizontal, Space.screenMargin)
                .padding(.vertical, Space.lg)
                .frame(maxWidth: Typography.readingMeasure)
                .frame(maxWidth: .infinity)
            }
            .screenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.ink, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Palette.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Restore") {
                        Task { await restore() }
                    }
                    .foregroundStyle(Palette.textSecondary)
                }
            }
        }
        .tint(Palette.lamplight)
        .parentalGate($gate)
        .task {
            analytics.track(.paywallView)
            if store.products.isEmpty { await store.load() }
            // Anual pre-selecionado. E o que a maioria quer e o que paga
            // melhor; quem quiser mensal troca com um toque.
            selected = store.annual?.id ?? store.monthly?.id
        }
        .onChange(of: store.isSubscribed) { _, subscribed in
            if subscribed { dismiss() }
        }
    }

    // MARK: - Topo

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            if let story {
                Text("To read \(story.title)")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.lamplight)
            }
            Text("All fifty stories")
                .font(Typography.display)
                .foregroundStyle(Palette.textPrimary)
                .minimumScaleFactor(0.8)
        }
        // Folga suficiente pra barra. Com Space.sm o topo das letras da
        // fonte display passava por baixo dos botoes e ficava cortado.
        .padding(.top, Space.xl)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            benefit("books.vertical.fill", "Fifty original stories",
                    "Four chapters each, about fifteen minutes of reading.")
            benefit("waveform", "Every chapter narrated",
                    "The words light up as they are read aloud.")
            // A narracao dos contos pagos e On-Demand Resources (ver
            // StoryPacks): baixa na primeira abertura. "Tudo esta no
            // aparelho" deixou de ser verdade, e promessa falsa em tela de
            // compra e motivo de recusa.
            benefit("airplane", "Plays with no signal",
                    "Each story downloads the first time you open it. After that, no connection needed.")
            benefit("person.2.fill", "Shared with the family",
                    "One subscription covers everyone in your family group.")
        }
    }

    private func benefit(_ symbol: String,
                         _ title: LocalizedStringKey,
                         _ detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: Space.md) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundStyle(Palette.lamplight)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.uiEmphasis)
                    .foregroundStyle(Palette.textPrimary)
                Text(detail)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }

    // MARK: - Planos

    private var options: some View {
        VStack(spacing: Space.md) {
            ForEach(store.sortedProducts) { product in
                Button {
                    selected = product.id
                } label: {
                    planRow(product)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func planRow(_ product: Product) -> some View {
        let isOn = selected == product.id
        return HStack(alignment: .center, spacing: Space.md) {
            Image(systemName: isOn ? "largecircle.fill.circle" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(isOn ? Palette.lamplight : Palette.textTertiary)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Space.sm) {
                    Text(product.displayName)
                        .font(Typography.uiEmphasis)
                        .foregroundStyle(Palette.textPrimary)
                    if let saving = product.savingsAgainst(store.monthly) {
                        Text("Save \(saving)%")
                            .font(Typography.badge)
                            .textCase(.uppercase)
                            .tracking(0.6)
                            .foregroundStyle(Palette.ink)
                            .padding(.horizontal, Space.sm)
                            .padding(.vertical, 3)
                            .background(Palette.lamplight, in: .rect(cornerRadius: Radius.pill))
                    }
                }
                // displayPrice ja vem na moeda e no formato certos.
                Text("\(product.displayPrice) \(product.periodLabel)")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
                if let trial = product.trialLabel {
                    Text(trial)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.lamplight)
                }
            }

            Spacer()
        }
        .padding(Space.lg)
        .background(
            isOn ? Palette.lamplight.opacity(0.10) : Palette.surface,
            in: .rect(cornerRadius: Radius.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card)
                .stroke(isOn ? Palette.lamplight.opacity(0.5) : Palette.hairline,
                        lineWidth: 1)
        )
    }

    // MARK: - Acao

    @ViewBuilder
    private var callToAction: some View {
        VStack(spacing: Space.md) {
            // O PORTAO PARENTAL DO APP INTEIRO ESTA NESTE BOTAO.
            //
            // Guideline 1.3 pede permissao do responsavel antes do comercio.
            // Comercio comeca aqui: e este toque, e so ele, que abre a folha
            // de pagamento da Apple. Ler precos nao gasta dinheiro; `buy()`
            // gasta. Por isso a conta de tabuada mudou de lugar — antes ela
            // guardava a PORTA do paywall, e hoje guarda o pagamento.
            //
            // A acao vai inteira pra dentro do `ParentalGateAction`: o portao
            // segura a closure e so a executa depois da resposta certa. Nao
            // chamar `buy()` fora daqui, em nenhuma hipotese, nem "so pra
            // testar" — e exatamente isso que a revisao procura.
            Button {
                gate = ParentalGateAction {
                    Task { await buy() }
                }
            } label: {
                if isPurchasing {
                    ProgressView().tint(Palette.ink)
                } else {
                    Text(selectedProduct?.trialLabel == nil ? "Subscribe" : "Start free trial")
                }
            }
            .buttonStyle(LamplightButtonStyle())
            .disabled(isPurchasing || selectedProduct == nil)

            // So na folha que apareceu sozinha. Nas outras a pessoa veio ate
            // aqui por vontade propria e ja tem o "Close" na barra; repetir a
            // saida ali seria pedir pra ela ir embora.
            if isIntro {
                Button("Not now") { dismiss() }
                    .buttonStyle(QuietButtonStyle())
            }

            if store.hasPendingPurchase {
                Text("Waiting for a parent to approve this purchase.")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.lamplight)
                    .multilineTextAlignment(.center)
            }

            if let message {
                Text(message)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func unavailable(_ detail: String) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("Subscriptions aren't available right now.")
                .font(Typography.uiEmphasis)
                .foregroundStyle(Palette.textPrimary)
            Text(detail)
                .font(Typography.caption)
                .foregroundStyle(Palette.textTertiary)
            Button("Try again") {
                Task { await store.load() }
            }
            .buttonStyle(QuietButtonStyle())
        }
        .padding(Space.lg)
        .cardSurface()
    }

    /// O texto de renovacao e os dois documentos. A App Store recusa uma
    /// tela de assinatura sem link pros termos e pra politica — e recusa
    /// tambem se eles estiverem so no rodape da loja e nao aqui.
    private var legal: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("""
            Payment is charged to your Apple Account. The subscription renews \
            automatically unless cancelled at least 24 hours before the end of \
            the period. Manage or cancel in Settings.
            """)

            // Sublinhados e nao so em ambar: cor sozinha nao diz que e um
            // link pra quem nao distingue as duas, e o resto do app usa
            // ambar pra coisas que nao sao clicaveis.
            //
            // Eram `Link`, que abre o Safari no toque. Sair do app e a outra
            // metade da Guideline 1.3, separada da compra e com portao
            // proprio — e agora que a tela inteira pode aparecer sozinha,
            // estes dois sao os unicos caminhos pra fora dela. Sem o portao
            // aqui, um dedo na folha de entrada poe a crianca no navegador.
            HStack(spacing: Space.xl) {
                Button("Terms of Use") {
                    gate = ParentalGateAction { openURL(Legal.terms) }
                }
                Button("Privacy Policy") {
                    gate = ParentalGateAction { openURL(Legal.privacy) }
                }
            }
            .buttonStyle(.plain)
            .underline()
            .foregroundStyle(Palette.textSecondary)
            .frame(maxWidth: .infinity)
        }
        .font(Typography.caption)
        .foregroundStyle(Palette.textTertiary)
        .multilineTextAlignment(.center)
        .padding(.top, Space.sm)
    }

    // MARK: - Apoio

    private var selectedProduct: Product? {
        store.products.first { $0.id == selected }
    }

    private func buy() async {
        guard let product = selectedProduct else { return }
        isPurchasing = true
        message = nil
        defer { isPurchasing = false }

        // Antes da compra: e o passo que a loja nao registra, e a diferenca
        // entre ele e o `subscribe` e a taxa de desistencia no cartao.
        analytics.track(.checkoutInitiated,
                        productId: product.id,
                        value: product.price,
                        currency: product.priceFormatStyle.currencyCode)

        switch await store.purchase(product) {
        case .success:
            analytics.track(product.trialLabel == nil ? .subscribe : .startTrial,
                            productId: product.id,
                            value: product.price,
                            currency: product.priceFormatStyle.currencyCode)
            dismiss()
        case .pending:
            message = nil        // a faixa de "aguardando" ja diz
        case .cancelled:
            message = nil        // desistir nao e erro e nao merece aviso
        case .failed(let reason):
            message = reason
        }
    }

    private func restore() async {
        message = nil
        if await store.restore() {
            dismiss()
        } else {
            message = "No active subscription found on this Apple Account."
        }
    }
}
