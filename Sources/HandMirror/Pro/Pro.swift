import Combine
import Foundation
import StoreKit
import SwiftUI

// MARK: - Gate mode
//
// Early access lets every feature through; trialOrPaywall enforces the IAP.
enum ProGateMode: String {
    case earlyAccess
    case trialOrPaywall
}

// MARK: - Feature flag
//
// HandMirror Plus is all-or-nothing — the Plus tab in Settings is the entire
// premium surface, and we don't differentiate per-feature gating today.
enum ProFeature: Hashable {
    case plus
}

// MARK: - Legal URLs
//
// Required by App Store Review Guideline 3.1.2(c) — subscription apps must
// surface functional links to both the Terms of Use (EULA) and the privacy
// policy inside the purchase flow.
enum LegalURL {
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacy    = URL(string: "https://raghavanaidu46.github.io/HandMirror/privacy")!
}

// MARK: - Product IDs (must match App Store Connect)

enum ProProductID {
    static let lifetime = "com.rbchronicles.hand.mirror.pro"
    static let monthly  = "com.rbchronicles.hand.mirror.pro.monthly"

    /// Display order on the paywall (lifetime first as the recommended option).
    static let displayOrder: [String] = [lifetime, monthly]
    static let all: Set<String>      = [lifetime, monthly]
}

// MARK: - Pro entitlement manager

@MainActor
final class Pro: ObservableObject {

    /// Debug builds run in `.earlyAccess` so the dev loop never hits the
    /// paywall; release builds are always `.trialOrPaywall`. The release arm
    /// is the source of truth — never flip it in a shipping build.
    static let mode: ProGateMode = {
        #if DEBUG
        return .earlyAccess
        #else
        return .trialOrPaywall
        #endif
    }()

    @Published private(set) var isProUser: Bool = false
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoadingProducts: Bool = false
    /// True when the current Apple ID is still eligible for at least one
    /// intro offer in our subscription group. Drives whether the unlock CTA
    /// reads "Start Free Trial" or "Continue".
    @Published private(set) var isIntroOfferEligible: Bool = false
    /// True when the user's Pro entitlement comes from another Family
    /// Sharing member's purchase.
    @Published private(set) var isFamilyShared: Bool = false
    /// Product ID currently mid-purchase (for showing a spinner).
    @Published var purchaseInProgress: String? = nil

    private var transactionListener: Task<Void, Never>?

    init() {
        transactionListener = makeTransactionListener()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: Public

    /// True when the given feature should be available for the user.
    /// In `earlyAccess` mode every feature is unlocked unconditionally.
    func isFeatureUnlocked(_ feature: ProFeature) -> Bool {
        switch Self.mode {
        case .earlyAccess:    return true
        case .trialOrPaywall: return isProUser
        }
    }

    /// Convenience for "is the user in the Plus tier right now". Same answer
    /// as `isFeatureUnlocked(.plus)` — provided as a read-friendly name.
    var canUsePlus: Bool { isFeatureUnlocked(.plus) }

    /// Wraps a SwiftUI `Binding` so that switching it to a non-free value
    /// while not subscribed runs `onLocked` (typically opens the paywall)
    /// instead of writing the change. The current value is unaffected, so
    /// the toggle/picker visually snaps back. Equality-based free check: the
    /// free value is the only one allowed for non-Plus users.
    func gatedBinding<T: Equatable>(
        _ source: Binding<T>,
        freeValue: T,
        onLocked: @escaping () -> Void
    ) -> Binding<T> {
        Binding(
            get: { source.wrappedValue },
            set: { newValue in
                if newValue == freeValue || self.canUsePlus {
                    source.wrappedValue = newValue
                } else {
                    onLocked()
                }
            }
        )
    }

    // MARK: StoreKit

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let fetched = try await Product.products(for: Array(ProProductID.all))
            self.products = fetched.sorted { lhs, rhs in
                let order = ProProductID.displayOrder
                return (order.firstIndex(of: lhs.id) ?? 99) < (order.firstIndex(of: rhs.id) ?? 99)
            }
            await refreshIntroOfferEligibility()
        } catch {
            NSLog("Pro: failed to load products — \(error.localizedDescription)")
        }
    }

    /// Flips `isIntroOfferEligible` based on whether the current Apple ID can
    /// still redeem an intro offer in our subscription group. Eligibility is
    /// shared across all members of a group.
    private func refreshIntroOfferEligibility() async {
        var eligible = false
        for product in products {
            guard let sub = product.subscription, sub.introductoryOffer != nil else { continue }
            if await Product.SubscriptionInfo.isEligibleForIntroOffer(for: sub.subscriptionGroupID) {
                eligible = true
                break
            }
        }
        isIntroOfferEligible = eligible
    }

    /// Returns true when the purchase succeeded and the user is now entitled.
    @discardableResult
    func purchase(_ product: Product) async throws -> Bool {
        purchaseInProgress = product.id
        defer { purchaseInProgress = nil }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let tx = try checkVerified(verification)
            await tx.finish()
            await refreshEntitlements()
            return isProUser
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    /// Sync the local receipt cache with App Store and re-evaluate entitlement.
    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    // MARK: Private

    private func refreshEntitlements() async {
        var entitled = false
        var familyShared = false
        for await result in Transaction.currentEntitlements {
            guard
                let tx = try? checkVerified(result),
                ProProductID.all.contains(tx.productID),
                tx.revocationDate == nil
            else { continue }

            let active: Bool
            if let expiration = tx.expirationDate {
                active = expiration > Date()           // auto-renewable subscription
            } else {
                active = true                          // non-consumable / lifetime
            }
            if active {
                entitled = true
                if tx.ownershipType == .familyShared { familyShared = true }
            }
        }
        isProUser = entitled
        isFamilyShared = entitled && familyShared
    }

    private func makeTransactionListener() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                do {
                    let tx = try self.checkVerified(result)
                    await tx.finish()
                    await self.refreshEntitlements()
                } catch {
                    NSLog("Pro: transaction verification failed — \(error.localizedDescription)")
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified(_, let error):
            throw error
        }
    }
}
