//
//  Store.swift
//  Magic World
//
//  StoreKit 2. Sem RevenueCat, como no [[pedagogy]].
//
//  Tres coisas aqui sao faceis de errar e caras de descobrir depois:
//
//  1. O listener de Transaction.updates tem de comecar no lancamento do app
//     e nunca ser cancelado. E por ele que chega uma compra aprovada pelo
//     "Pedir para Comprar", uma renovacao, um reembolso, ou uma assinatura
//     que um familiar comprou. Sem ele o usuario paga e nao recebe nada.
//
//  2. transaction.finish() precisa ser chamado DEPOIS de conceder o acesso.
//     Transacao nao finalizada volta no listener em todo lancamento, pra
//     sempre.
//
//  3. Preco nunca e escrito no codigo. Vem de product.displayPrice, ja
//     formatado na moeda e no locale de quem esta olhando.
//

import Foundation
import StoreKit
import Observation
import OSLog

@MainActor
@Observable
final class Store {

    // MARK: - Produtos

    /// Os IDs vem do App Store Connect e tem de bater exatamente.
    ///
    /// NOTA: os dois foram criados com convencoes diferentes — um com
    /// namespace completo e o outro sem. Product ID nao pode ser alterado
    /// depois de criado, entao isto fica como esta ate alguem criar um
    /// substituto e depreciar o antigo.
    enum ProductID {
        static let monthly = "com.alexandre.juniort10.magicworld.monthly"
        static let annual = "pro_annual"
        static let all = [monthly, annual]
    }

    private(set) var products: [Product] = []
    private(set) var isSubscribed = false
    private(set) var isLoading = false
    /// Preenchido quando algo deu errado de um jeito que a interface precisa
    /// mostrar. Nao usar para cancelamento do usuario, que nao e erro.
    private(set) var loadError: String?

    /// "Pedir para Comprar": a crianca pediu e o responsavel ainda nao
    /// aprovou. Num app infantil este caminho e comum e a interface precisa
    /// dizer alguma coisa em vez de nao fazer nada.
    private(set) var hasPendingPurchase = false

    /// Guardado so pra deixar explicito que existe e que e proposital que
    /// ninguem o cancele.
    private var updates: Task<Void, Never>?
    private let log = Logger(subsystem: "com.alexandre.juniort10.magicworld", category: "store")

    /// Ordenados: mensal primeiro, anual depois.
    var sortedProducts: [Product] {
        products.sorted { a, b in
            (a.id == ProductID.monthly ? 0 : 1) < (b.id == ProductID.monthly ? 0 : 1)
        }
    }

    var monthly: Product? { products.first { $0.id == ProductID.monthly } }
    var annual: Product? { products.first { $0.id == ProductID.annual } }

    // MARK: - Ciclo de vida

    init() {
        // Comeca antes de qualquer compra e nao e cancelado enquanto o app
        // vive. Ver observacao 1 no topo.
        updates = Task.detached { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }

        Task {
            await load()
            await refreshEntitlements()
        }
    }

    // Sem deinit. Duas razoes, e a segunda e a que importa:
    //
    // 1. `deinit` e nonisolated e `updates` pertence a uma classe @MainActor,
    //    entao tocar nela ali nao compila.
    // 2. Este objeto vive o app inteiro e o listener NAO deve ser cancelado.
    //    Cancelar era contradizer a observacao 1 do topo do arquivo — foi
    //    limpeza por habito, num objeto que nunca e destruido.

    // MARK: - Carregamento

    func load() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            let loaded = try await Product.products(for: ProductID.all)
            products = loaded

            if loaded.isEmpty {
                // Este caso quase nunca e "a rede caiu". Quase sempre e uma
                // das tres abaixo, e vale dizer qual pra nao virar mistério.
                loadError = """
                Nenhum produto retornado. Verifique, nesta ordem:
                1. O bundle ID do app bate com o do registro no App Store \
                Connect onde as assinaturas foram criadas?
                2. Os Product IDs estao escritos exatamente iguais?
                3. Ha um acordo de Paid Applications ativo na conta?
                """
                log.error("Product.products devolveu vazio para \(ProductID.all)")
            } else if loaded.count < ProductID.all.count {
                let missing = Set(ProductID.all).subtracting(loaded.map(\.id))
                log.error("produtos ausentes: \(missing)")
            }
        } catch {
            loadError = error.localizedDescription
            log.error("falha ao carregar produtos: \(error.localizedDescription)")
        }
    }

    /// Percorre o que o usuario tem direito agora. Cobre compra propria,
    /// restauracao, e assinatura compartilhada por familiar.
    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if ProductID.all.contains(transaction.productID),
               transaction.revocationDate == nil {
                active = true
            }
        }
        isSubscribed = active
    }

    // MARK: - Compra

    enum PurchaseOutcome {
        case success
        case pending      // Pedir para Comprar, aguardando o responsavel
        case cancelled    // o usuario desistiu; nao e erro
        case failed(String)
    }

    func purchase(_ product: Product) async -> PurchaseOutcome {
        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    // Assinatura da App Store nao conferiu. Nao conceder.
                    log.error("transacao nao verificada para \(product.id)")
                    return .failed("Não foi possível verificar a compra.")
                }
                await refreshEntitlements()
                await transaction.finish()        // depois de conceder
                hasPendingPurchase = false
                return .success

            case .pending:
                hasPendingPurchase = true
                return .pending

            case .userCancelled:
                return .cancelled

            @unknown default:
                return .failed("Resultado desconhecido da App Store.")
            }
        } catch {
            log.error("compra falhou: \(error.localizedDescription)")
            return .failed(error.localizedDescription)
        }
    }

    /// Restaurar. Na pratica currentEntitlements ja resolve quase sempre;
    /// AppStore.sync() existe porque a App Store exige o botao e porque
    /// forca uma reconciliacao quando algo ficou preso.
    func restore() async -> Bool {
        do {
            try await AppStore.sync()
        } catch {
            log.error("sync falhou: \(error.localizedDescription)")
        }
        await refreshEntitlements()
        return isSubscribed
    }

    // MARK: - Listener

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else {
            log.error("update nao verificado, ignorando")
            return
        }
        await refreshEntitlements()
        await transaction.finish()
        if transaction.revocationDate != nil {
            log.info("transacao revogada: \(transaction.productID)")
        }
    }

    // MARK: - Acesso

    /// A unica pergunta que o resto do app faz.
    func canOpen(_ story: Story) -> Bool {
        story.isFree || isSubscribed
    }
}

// MARK: - Apresentacao

extension Product {
    /// "por mês" / "por ano", a partir do periodo real do produto.
    var periodLabel: String {
        guard let period = subscription?.subscriptionPeriod else { return "" }
        // Um `String(localized:)` por caso, com o singular separado do
        // plural: idioma nenhum monta "a cada N meses" colando um
        // numero num substantivo solto, entao a frase inteira precisa
        // ser a chave.
        switch (period.unit, period.value) {
        case (.month, 1): return String(localized: "per month")
        case (.year, 1): return String(localized: "per year")
        case (.month, let n): return String(localized: "every \(n) months")
        case (.week, 1): return String(localized: "per week")
        case (.week, let n): return String(localized: "every \(n) weeks")
        case (.day, 1): return String(localized: "per day")
        case (.day, let n): return String(localized: "every \(n) days")
        default: return ""
        }
    }

    /// Economia do anual contra doze mensais, calculada e nao escrita a mao.
    func savingsAgainst(_ monthly: Product?) -> Int? {
        guard let monthly,
              subscription?.subscriptionPeriod.unit == .year,
              monthly.subscription?.subscriptionPeriod.unit == .month
        else { return nil }
        let yearOfMonthly = monthly.price * 12
        guard yearOfMonthly > 0, price < yearOfMonthly else { return nil }
        let saved = (yearOfMonthly - price) / yearOfMonthly
        return Int((saved as NSDecimalNumber).doubleValue * 100)
    }

    /// Texto do periodo gratuito, quando houver, direto do produto.
    var trialLabel: String? {
        guard let offer = subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        let p = offer.period
        // Uma chave por unidade, com o plural resolvido no String
        // Catalog. Montar "\(n) \(unit) free" a partir de pecas — como
        // era antes — nao tem traducao possivel: em portugues o
        // substantivo muda de genero, em arabe ha seis formas de plural,
        // e nenhuma das duas coisas cabe numa variavel `unit`.
        switch p.unit {
        case .day:   return String(localized: "\(p.value) days free")
        case .week:  return String(localized: "\(p.value) weeks free")
        case .month: return String(localized: "\(p.value) months free")
        case .year:  return String(localized: "\(p.value) years free")
        @unknown default: return nil
        }
    }
}
