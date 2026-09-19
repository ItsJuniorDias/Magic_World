//
//  RootView.swift
//  Magic World
//
//  Porta de entrada: onboarding ou abas.
//
//  Tres abas. Home e Library cobrem a leitura — Favoritos e filtro dentro
//  da Library, nao aba propria, porque seria a mesma tela com menos coisa.
//
//  A terceira e You: o registro do que a pessoa leu, e os ajustes que ate
//  entao nao tinham tela nenhuma. Nome, lembrete, assinatura e apagar
//  progresso viviam espalhados ou so no onboarding.
//

import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var app
    @Environment(Store.self) private var store

    enum Tab: Hashable { case home, library, you }

    @State private var tab: Tab = .home
    /// Compartilhado: tocar num habitat na Home abre a Library ja filtrada.
    @State private var selectedRealm: Story.Realm?
    @State private var showIntroPaywall = false

    /// Paywall automatico logo depois do onboarding. LIGADO.
    ///
    /// A tela de assinatura passou a ser tratada como o que ela e: uma tela
    /// que MOSTRA precos. Quem entra nela nao comprou nada. O comercio — o
    /// toque que abre a folha de pagamento da Apple — acontece um passo
    /// depois, no botao Subscribe, e e la que o portao parental esta agora.
    /// Ver `PaywallView.callToAction`.
    ///
    /// O que sustenta isso na Guideline 1.3:
    ///
    ///  - a folha e dispensavel por tres caminhos (Close na barra, "Not now"
    ///    no corpo, e arrastar pra baixo);
    ///  - fechar deixa um app que funciona, porque ha contos livres;
    ///  - aparece UMA vez na vida do aparelho, nao a cada abertura;
    ///  - nenhum centavo sai sem a conta de tabuada.
    ///
    /// RISCO CONHECIDO: foi comercio sem portao que derrubou a 1.5 (120). Um
    /// revisor pode ler "purchasing opportunity" como a tela inteira e nao
    /// so o botao. Se a recusa vier por 1.3, virar `false` aqui devolve o
    /// comportamento antigo inteiro — o resto do codigo continua no lugar.
    private static let autoPresentsIntroPaywall = true

    var body: some View {
        Group {
            if app.hasCompletedOnboarding {
                TabView(selection: $tab) {
                    HomeView(selectedRealm: $selectedRealm, selectedTab: $tab)
                        .tabItem { Label("Home", systemImage: "house.fill") }
                        .tag(Tab.home)

                    LibraryView(selectedRealm: $selectedRealm)
                        .tabItem { Label("Library", systemImage: "books.vertical.fill") }
                        .tag(Tab.library)

                    ProfileView()
                        .tabItem { Label("You", systemImage: "sparkles") }
                        .tag(Tab.you)
                }
                .sheet(isPresented: $showIntroPaywall) {
                    // `isIntro` so muda uma coisa: acrescenta a saida no
                    // corpo da tela. Ninguem pediu por esta folha, entao o
                    // "Close" da barra sozinho nao basta.
                    PaywallView(isIntro: true)
                }
                .task { await presentIntroPaywall() }
            } else {
                OnboardingView()
            }
        }
        .tint(Palette.lamplight)
        .preferredColorScheme(.dark)
        // `foldAware` cobre TabView e Onboarding: a resolucao de
        // size class do iPhone Duo ocorre acima de tudo, num lugar so.
        .foldAware()
    }

    /// Uma vez so, e dispensavel: paywall que bloqueia o app inteiro sem
    /// nenhum conteudo aberto e reprovado na revisao. Aqui ha tres contos
    /// livres, entao fechar a folha deixa a pessoa com um app que funciona.
    ///
    /// O gatilho e a chegada nas abas, nao o fim do onboarding. Pra quem
    /// instala agora da no mesmo — as abas aparecem no instante seguinte.
    /// Pra quem ja tem o app, isso significa uma aparicao na primeira
    /// abertura depois da atualizacao, porque `hasSeenIntroPaywall` nasce
    /// falso. Quem ja assina nao ve nada, pelo guard la embaixo.
    ///
    /// Se voce quiser que so quem passou pelo onboarding veja, o lugar de
    /// mexer e aqui: guardar a data de `completeOnboarding()` e comparar.
    private func presentIntroPaywall() async {
        guard Self.autoPresentsIntroPaywall else { return }
        guard !app.hasSeenIntroPaywall else { return }
        // Espera os produtos: paywall que abre vazio e pior que paywall
        // nenhum, e a carga leva um instante.
        if store.products.isEmpty { await store.load() }
        guard !store.isSubscribed, !store.products.isEmpty else {
            // Sem produto pra mostrar, nao gasta a unica chance.
            return
        }
        // Um instante pra Home aparecer atras. Sem isso a primeira coisa que
        // a pessoa ve depois do onboarding e um pedido de dinheiro, e ela
        // fecha sem nunca ter visto o que esta comprando.
        try? await Task.sleep(for: .milliseconds(700))
        guard !Task.isCancelled else { return }

        app.markIntroPaywallSeen()
        showIntroPaywall = true
    }
}
