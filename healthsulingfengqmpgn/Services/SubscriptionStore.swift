import Foundation
import StoreKit

@MainActor
final class SubscriptionStore: ObservableObject {
    static let weeklyID = "com.silverdawn.frostyhill.myst.week.wear"
    static let yearlyID = "com.silverdawn.frostyhill.myst.year.wear"
    static let productIDs = [weeklyID, yearlyID]

    struct Plan: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let price: String
        let badge: String?
        let isBestValue: Bool
        let product: Product?
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPremium = false
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var isRestoring = false

    private let defaults = UserDefaults.standard
    private let forcePremium: Bool
    private var updatesTask: Task<Void, Never>?

    private enum Key {
        static let premium = "subscriptionPremium"
    }

    init() {
        #if DEBUG
        let freeOverride = ProcessInfo.processInfo.arguments.contains("-DSHFree")
        forcePremium = ProcessInfo.processInfo.arguments.contains("-DSHPremium") && !freeOverride
        #else
        let freeOverride = false
        forcePremium = false
        #endif
        isPremium = (defaults.bool(forKey: Key.premium) || forcePremium) && !freeOverride
        defaults.set(isPremium, forKey: Key.premium)
        updatesTask = listenForTransactions()
        Task { await loadProducts() }
    }

    deinit {
        updatesTask?.cancel()
    }

    var weeklyProduct: Product? {
        products.first { $0.id == Self.weeklyID }
    }

    var yearlyProduct: Product? {
        products.first { $0.id == Self.yearlyID }
    }

    func plan(for id: String) -> Plan {
        let product = products.first { $0.id == id }
        if id == Self.weeklyID {
            return Plan(
                id: id,
                title: "Weekly Pro",
                subtitle: "3-day free trial, then weekly",
                price: product?.displayPrice ?? "$7.99/wk",
                badge: "3-day free trial",
                isBestValue: false,
                product: product
            )
        }
        return Plan(
            id: id,
            title: "Yearly Pro",
            subtitle: "Best value · save over 90%",
            price: product?.displayPrice ?? "$39.99/yr",
            badge: "Best value",
            isBestValue: true,
            product: product
        )
    }

    var weeklyPlan: Plan { plan(for: Self.weeklyID) }
    var yearlyPlan: Plan { plan(for: Self.yearlyID) }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await Product.products(for: Self.productIDs)
            products = loaded.sorted { lhs, _ in lhs.id == Self.yearlyID }
        } catch {
            // Keep the paywall usable with the configured fallback prices. A
            // purchase attempt will surface the StoreKit error if needed.
            products = []
        }
    }

    @discardableResult
    func purchase(_ plan: Plan) async -> Bool {
        guard let product = plan.product else {
            errorMessage = "Unable to Purchase"
            return false
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    errorMessage = "Unable to Purchase"
                    return false
                }
                await transaction.finish()
                await refreshEntitlements()
                return isPremium
            case .userCancelled:
                return false
            case .pending:
                errorMessage = "Your purchase is pending approval."
                return false
            @unknown default:
                errorMessage = "Unable to Purchase"
                return false
            }
        } catch {
            errorMessage = "Unable to Purchase"
            return false
        }
    }

    func restore() async {
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !isPremium {
                errorMessage = "No purchases to be restored"
            }
        } catch {
            errorMessage = "No purchases to be restored"
        }
    }

    func refreshEntitlements() async {
        if forcePremium {
            setPremium(true)
            return
        }
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if Self.productIDs.contains(transaction.productID) && transaction.revocationDate == nil {
                active = true
            }
        }
        setPremium(active)
    }

    func setPremium(_ value: Bool) {
        isPremium = value
        defaults.set(value, forKey: Key.premium)
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self?.refreshEntitlements()
            }
        }
    }

    var featureList: [(String, String)] {
        [
            ("infinity", "Unlimited Measuring"),
            ("sparkles", "Unlimited AI Insights"),
            ("square.grid.2x2.fill", "All Features"),
            ("chart.xyaxis.line", "Advanced Analytics"),
            ("heart.text.square.fill", "Heart Rate Details"),
            ("waveform.path.ecg", "Extended HRV Metrics"),
            ("chart.line.uptrend.xyaxis", "Trends"),
            ("folder.fill", "Health Records"),
            ("magnifyingglass", "In-Depth Analysis"),
            ("lightbulb.fill", "Heart Insights")
        ]
    }
}
