import Foundation
import StoreKit

@MainActor
class SubscriptionManager: ObservableObject {

    static let shared = SubscriptionManager()

    // MARK: - Product IDs
    // Matches App Store Connect subscription product ID
    static let subscriptionProductID = "com.mbm.subscription.monthly"
    static let subscriptionGroupID = "MBMPremium"

    // MARK: - Published Properties
    @Published private(set) var subscriptionStatus: SubscriptionStatus = .unknown
    @Published private(set) var product: Product?
    @Published private(set) var purchaseError: String?
    @Published private(set) var isLoading = false

    // MARK: - Subscription Status
    enum SubscriptionStatus: Equatable {
        case unknown
        case notSubscribed
        case subscribed
        case inTrial
        case expired
        case revoked
    }

    // MARK: - Transaction Listener
    private var transactionListener: Task<Void, Error>?

    init() {
        transactionListener = listenForTransactions()

        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load Products
    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.subscriptionProductID])
            if let subscription = products.first {
                self.product = subscription
            }
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    // MARK: - Update Subscription Status
    func updateSubscriptionStatus() async {
        isLoading = true
        defer { isLoading = false }

        // Check for active subscription
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }

            if transaction.productID == Self.subscriptionProductID {
                // Check if in trial period
                if let offerType = transaction.offerType, offerType == .introductory {
                    subscriptionStatus = .inTrial
                } else {
                    subscriptionStatus = .subscribed
                }
                return
            }
        }

        // No active subscription found
        subscriptionStatus = .notSubscribed
    }

    // MARK: - Purchase Subscription
    func purchase() async -> Bool {
        guard let product = product else {
            purchaseError = "Product not available"
            return false
        }

        isLoading = true
        purchaseError = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await updateSubscriptionStatus()
                    isLoading = false
                    return true
                case .unverified(_, let error):
                    purchaseError = "Purchase verification failed: \(error.localizedDescription)"
                    isLoading = false
                    return false
                }
            case .userCancelled:
                isLoading = false
                return false
            case .pending:
                purchaseError = "Purchase is pending approval"
                isLoading = false
                return false
            @unknown default:
                isLoading = false
                return false
            }
        } catch {
            purchaseError = "Purchase failed: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    // MARK: - Restore Purchases
    func restorePurchases() async {
        isLoading = true
        purchaseError = nil

        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
        } catch {
            purchaseError = "Restore failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Listen for Transactions
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else {
                    continue
                }

                await transaction.finish()
                await self.updateSubscriptionStatus()
            }
        }
    }

    // MARK: - Computed Properties

    // Set to true only for taking screenshots, false for App Store submission
    static let forceProForScreenshots = false

    var isSubscribed: Bool {
        if Self.forceProForScreenshots { return true }
        return subscriptionStatus == .subscribed || subscriptionStatus == .inTrial
    }

    var priceString: String {
        product?.displayPrice ?? "$2.99"
    }

    var trialDurationString: String {
        if let offer = product?.subscription?.introductoryOffer,
           offer.paymentMode == .freeTrial {
            let period = offer.period
            switch period.unit {
            case .day:
                return "\(period.value)-day"
            case .week:
                return "\(period.value)-week"
            case .month:
                return "\(period.value)-month"
            case .year:
                return "\(period.value)-year"
            @unknown default:
                return "3-day"
            }
        }
        return "3-day"
    }
}
