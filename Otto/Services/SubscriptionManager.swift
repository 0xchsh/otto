import StoreKit
import SwiftUI

@Observable
@MainActor
final class SubscriptionManager: Sendable {
    nonisolated init() {}
    private(set) var isSubscribed = false
    private(set) var products: [String: Product] = [:]
    var isPurchasing = false
    var purchaseError: String?

    var shouldShowPaywall = false

    static let monthlyID = "ch.sh.otto.monthly"
    static let yearlyID = "ch.sh.otto.yearly"
    private static let productIDs: Set<String> = [monthlyID, yearlyID]

    var monthlyProduct: Product? { products[Self.monthlyID] }
    var yearlyProduct: Product? { products[Self.yearlyID] }

    // MARK: - Products

    func fetchProducts() async {
        do {
            let storeProducts = try await Product.products(for: Self.productIDs)
            for product in storeProducts {
                products[product.id] = product
            }
        } catch {
            purchaseError = "Failed to load products."
        }
    }

    // MARK: - Subscription Status

    func refreshSubscriptionStatus() async {
        var hasEntitlement = false
        for id in Self.productIDs {
            if let result = await Transaction.currentEntitlement(for: id) {
                if case .verified = result {
                    hasEntitlement = true
                    break
                }
            }
        }
        isSubscribed = hasEntitlement
    }

    func updatePaywallVisibility() {
        shouldShowPaywall = !isSubscribed
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        isPurchasing = true
        purchaseError = nil

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshSubscriptionStatus()
                } else {
                    purchaseError = "Purchase could not be verified."
                }
            case .userCancelled:
                break
            case .pending:
                purchaseError = "Purchase is pending approval."
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }

        isPurchasing = false
    }

    // MARK: - Restore

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshSubscriptionStatus()
        } catch {
            purchaseError = "Could not restore purchases."
        }
    }

    // MARK: - Transaction Observer

    func observeTransactionUpdates() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                await transaction.finish()
                await refreshSubscriptionStatus()
            }
        }
    }
}
