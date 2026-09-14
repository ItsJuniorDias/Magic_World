//
//  OnboardingView.swift
//  Magic World
//
//  Tres passos, e cada um existe por um motivo:
//
//  1. Boas-vindas — diz o que o app e em uma frase.
//  2. Nome        — o app passa a chamar a crianca pelo nome. Pode pular.
//  3. Lembrete    — explica antes de pedir a permissao do sistema.
//
//  O onboarding do app antigo tinha uma tela inteira explicando que "cada
//  escolha molda sua aventura". Com a ramificacao cortada, ela virou promessa
//  falsa e saiu.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step = 0
    @State private var name = ""
    @State private var bedtime = Calendar.current.date(
        bySettingHour: 19, minute: 30, second: 0, of: .now
    ) ?? .now
    @State private var isRequestingPermission = false

    /// Foco do campo de nome do passo 2.
    ///
    /// O TabView NAO destroi a pagina que sai de vista: os tres passos
    /// existem ao mesmo tempo e so um aparece. Entao o campo de nome
    /// continua vivo, continua sendo o first responder, e o teclado
    /// atravessa pro passo 3 e cobre o seletor de hora — a pessoa chega na
    /// tela do lembrete com um teclado aberto que nao tem onde digitar.
    ///
    /// Tirar o foco na troca de passo resolve os dois caminhos de saida, o
    /// botao e o arrasto, num lugar so.
    @FocusState private var nameFieldFocused: Bool

    private let lastStep = 2

    /// Nome do imageset de fundo de cada passo. Vazio enquanto a imagem nao
    /// existe — o passo cai no fundo liso e nada quebra.
    private func background(for step: Int) -> String {
        ["onboarding-welcome", "onboarding-name", "onboarding-reminder"][step]
    }

    var body: some View {
        VStack(spacing: 0) {
            progressDots
                .padding(.top, Space.lg)

            TabView(selection: $step) {
                welcome.tag(0)
                nameStep.tag(1)
                reminderStep.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            // Vale tanto pro toque no botao quanto pro arraste entre
            // paginas, que nao passa por `advance()`.
            .onChange(of: step) { _, _ in nameFieldFocused = false }

            footer
        }
        .background {
            // O fundo troca com o passo, atras de tudo, com fade. A imagem
            // ja traz a metade de baixo em ink solido, entao o texto nao
            // precisa de scrim proprio aqui.
            Palette.ink.overlay {
                if let ui = UIImage(named: background(for: step)) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .id(step)
                        .transition(.opacity)
                }
            }
            .ignoresSafeArea()
            .motion(Motion.crossfade, value: step)
        }
        .tint(Palette.lamplight)
    }

    // MARK: - Passo 1

    private var welcome: some View {
        OnboardingPage(
            title: "Stories that read themselves to you",
            message: "Every chapter is narrated out loud, and the words light up as they're read. Follow along, or just listen with your eyes closed."
        )
    }

    // MARK: - Passo 2

    private var nameStep: some View {
        OnboardingPage(
            title: "What should we call you?",
            message: "We'll use it to welcome you back. You can skip this and stay anonymous."
        ) {
            TextField("", text: $name, prompt: Text("Your name").foregroundStyle(Palette.textTertiary))
                .font(Typography.storyBody)
                .foregroundStyle(Palette.textPrimary)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($nameFieldFocused)
                // A tecla de retorno faz o mesmo que o botao. Sem isto ela
                // so fecha o teclado e a pessoa tem de tocar em Continue
                // logo depois de ja ter dito que terminou.
                .submitLabel(.done)
                .onSubmit(advance)
                .padding(Space.lg)
                .background(Palette.surfaceRaised, in: .rect(cornerRadius: Radius.control))
                .padding(.horizontal, Space.screenMargin)
                .padding(.top, Space.xl)
        }
    }

    // MARK: - Passo 3

    private var reminderStep: some View {
        OnboardingPage(
            title: "A nudge at story time",
            message: "One reminder a day, at the hour you pick. Nothing else — no streaks to protect, no badges chasing you."
        ) {
            DatePicker(
                "Reminder time",
                selection: $bedtime,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .colorScheme(.dark)
            .padding(.top, Space.md)
        }
    }

    // MARK: - Rodape

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: Space.md) {
            Button(action: advance) {
                Text(step == lastStep ? "Turn on the reminder" : "Continue")
            }
            .buttonStyle(LamplightButtonStyle())
            .disabled(isRequestingPermission)

            Button(step == lastStep ? "Not now" : "Skip") {
                skip()
            }
            .font(Typography.caption)
            .foregroundStyle(Palette.textTertiary)
        }
        .padding(.horizontal, Space.screenMargin)
        .padding(.bottom, Space.xl)
    }

    private var progressDots: some View {
        HStack(spacing: Space.sm) {
            ForEach(0...lastStep, id: \.self) { index in
                Capsule()
                    .fill(index == step ? Palette.lamplight : Palette.hairline)
                    .frame(width: index == step ? 20 : 6, height: 6)
            }
        }
        .motion(Motion.state, value: step)
    }

    // MARK: - Acoes

    private func advance() {
        switch step {
        case 0:
            step = 1
        case 1:
            app.readerName = name
            step = 2
        default:
            Task { await enableReminderAndFinish() }
        }
    }

    private func skip() {
        if step == lastStep {
            finish()
        } else {
            step += 1
        }
    }

    /// Pede a permissao so aqui, depois da explicacao e do toque explicito.
    /// Se negarem, seguimos em frente — o lembrete e opcional e o app inteiro
    /// funciona sem ele.
    private func enableReminderAndFinish() async {
        isRequestingPermission = true
        defer { isRequestingPermission = false }

        let granted = await ReminderScheduler.requestAuthorization()
        if granted {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: bedtime)
            let hour = parts.hour ?? 19
            let minute = parts.minute ?? 30
            app.setBedtime(hour: hour, minute: minute)
            app.bedtimeReminderEnabled = true
            await ReminderScheduler.schedule(hour: hour, minute: minute)
        } else {
            app.bedtimeReminderEnabled = false
        }
        finish()
    }

    private func finish() {
        app.completeOnboarding()
    }
}

/// Layout compartilhado dos passos: arte em cima, texto embaixo, conteudo
/// opcional no fim. Repetir a estrutura e o que faz o fluxo parecer um fluxo.
private struct OnboardingPage<Extra: View>: View {
    let title: String
    let message: String
    @ViewBuilder var extra: () -> Extra

    /// Espaco reservado no topo pro desenho que vem do FUNDO. E `Color.clear`
    /// e nao `EmptyView`: EmptyView nao e uma view vazia com tamanho, e a
    /// ausencia de view, e `.frame` nele e ignorado em silencio. Foi assim
    /// que os 300 pontos sumiram e o texto subiu por cima da ilustracao.
    private let artHeight: CGFloat = 300

    init(
        title: String,
        message: String,
        @ViewBuilder extra: @escaping () -> Extra = { EmptyView() }
    ) {
        self.title = title
        self.message = message
        self.extra = extra
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Space.lg) {
                Spacer(minLength: Space.xl)
                // O que empurra o titulo pra baixo da zona de assunto da
                // imagem de fundo. Sem isso o texto cai em cima do desenho.
                Color.clear
                    .frame(height: artHeight)

                VStack(alignment: .leading, spacing: Space.md) {
                    Text(title)
                        .font(Typography.title)
                        .foregroundStyle(Palette.textPrimary)
                    Text(message)
                        .font(Typography.ui)
                        .foregroundStyle(Palette.textSecondary)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Space.screenMargin)

                extra()
                Spacer(minLength: Space.lg)
            }
            .frame(maxWidth: Typography.readingMeasure)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        // Arrastar a pagina pra baixo tambem fecha o teclado, que e o gesto
        // que a pessoa tenta antes de procurar um botao.
        .scrollDismissesKeyboard(.interactively)
    }
}
