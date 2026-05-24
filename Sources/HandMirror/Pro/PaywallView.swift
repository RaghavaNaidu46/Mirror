import SwiftUI
import StoreKit

/// HandMirror Plus paywall — shown when the user opens "HandMirror Plus…"
/// from the status-bar menu or tries to enable a Plus feature while in the
/// free tier. Macros-style sheet/window layout: title, feature highlights,
/// the two products, a primary CTA, and the legal links App Store Review
/// 3.1.2(c) requires for subscription flows.
struct PaywallView: View {
    @EnvironmentObject var pro: Pro
    @Environment(\.dismiss) private var dismiss

    @State private var selectedID: String?
    @State private var purchaseError: String?

    var body: some View {
        ZStack {
            backdrop

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    closeBar
                    heroOrb
                    titleBlock
                    featureList
                    productList
                    purchaseButton
                    footer
                }
            }
        }
        .frame(width: 460, height: 720)
        .task {
            if pro.products.isEmpty { await pro.loadProducts() }
            if selectedID == nil {
                selectedID = pro.products.first(where: { $0.id == ProProductID.lifetime })?.id
                    ?? pro.products.first?.id
            }
        }
        .onChange(of: pro.isProUser) { _, isPro in
            if isPro { dismiss() }
        }
    }

    // MARK: Subviews

    private var backdrop: some View {
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.10, blue: 0.12),
                Color(red: 0.06, green: 0.06, blue: 0.08),
            ],
            startPoint: .top, endPoint: .bottom
        )
        .overlay(
            RadialGradient(
                colors: [Color.red.opacity(0.18), .clear],
                center: .init(x: 0.5, y: 0.1),
                startRadius: 0, endRadius: 360
            )
        )
        .ignoresSafeArea()
    }

    private var closeBar: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var heroOrb: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.red.opacity(0.55), Color.orange.opacity(0.20), .clear],
                        center: .center, startRadius: 0, endRadius: 110
                    )
                )
                .frame(width: 180, height: 180)
                .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))

            Image(systemName: "camera.aperture")
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .padding(.bottom, 18)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HandMirror Plus")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)

            Text("Snaps with marker annotations, custom masks, mic check, native reactions, smart window, notch trigger, and alternative icons.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))

            trialBanner
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
        .padding(.bottom, 22)
    }

    @ViewBuilder
    private var trialBanner: some View {
        if pro.isIntroOfferEligible,
           let representative = pro.products.first(where: { Self.trialDescription(for: $0) != nil }),
           let trial = Self.trialDescription(for: representative) {
            HStack(spacing: 8) {
                Image(systemName: "gift").font(.system(size: 11))
                Text("\(trial) free trial · cancel anytime")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(Color.red.opacity(0.95))
            .padding(.top, 6)
        }
    }

    /// Returns "14 days", "1 week", etc. for the product's free-trial intro
    /// offer, or nil if it doesn't have one.
    static func trialDescription(for product: Product) -> String? {
        guard let offer = product.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        let value = offer.period.value
        let unit: String
        switch offer.period.unit {
        case .day:   unit = value == 1 ? "day"   : "days"
        case .week:  unit = value == 1 ? "week"  : "weeks"
        case .month: unit = value == 1 ? "month" : "months"
        case .year:  unit = value == 1 ? "year"  : "years"
        @unknown default: return nil
        }
        return "\(value) \(unit)"
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow("person.crop.rectangle.badge.plus", "Snaps with hand-drawn annotations")
            featureRow("theatermasks",                     "Window mask: default, square, circle, zoom & rotation")
            featureRow("waveform",                         "Mic Check live audio meter")
            featureRow("sparkles",                         "Native macOS reactions, on tap")
            featureRow("macwindow",                        "Smart Window: remembers position per app")
            featureRow("rectangle.center.inset.filled",    "Notch Trigger to open from the camera notch")
            featureRow("square.grid.2x2",                  "Alternative menu bar icons")
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 26)
    }

    private func featureRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.red.opacity(0.95))
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.red.opacity(0.12)))
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
        }
    }

    @ViewBuilder
    private var productList: some View {
        if pro.products.isEmpty {
            HStack {
                Spacer()
                ProgressView().controlSize(.small).tint(.white.opacity(0.6))
                Spacer()
            }
            .frame(height: 80)
            .padding(.bottom, 18)
        } else {
            VStack(spacing: 10) {
                ForEach(pro.products, id: \.id) { product in
                    ProductCard(
                        product: product,
                        isSelected: selectedID == product.id,
                        isRecommended: product.id == ProProductID.lifetime,
                        trialLabel: pro.isIntroOfferEligible ? Self.trialDescription(for: product).map { "FREE \($0.uppercased())" } : nil
                    ) {
                        selectedID = product.id
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
        }
    }

    private var purchaseButton: some View {
        Button {
            Task { await purchaseSelected() }
        } label: {
            ZStack {
                if pro.purchaseInProgress != nil {
                    ProgressView().controlSize(.small).tint(.black)
                } else {
                    Text(purchaseCTA)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.red)
                    .shadow(color: Color.red.opacity(0.4), radius: 12)
            )
        }
        .buttonStyle(.plain)
        .disabled(selectedID == nil || pro.purchaseInProgress != nil)
        .opacity(selectedID == nil ? 0.5 : 1)
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }

    /// CTA copy adapts to the selected product. If it has a free-trial intro
    /// offer the user is still eligible for, the button reads
    /// "Start 14-day free trial" (or whatever duration ASC sets). Otherwise
    /// it falls back to "Continue".
    private var purchaseCTA: String {
        guard pro.isIntroOfferEligible,
              let id = selectedID,
              let product = pro.products.first(where: { $0.id == id }),
              let trial = Self.trialDescription(for: product)
        else { return "Continue" }
        let hyphenated = trial.replacingOccurrences(of: " ", with: "-")
        let singular = hyphenated.hasSuffix("s") ? String(hyphenated.dropLast()) : hyphenated
        return "Start \(singular) free trial"
    }

    private var footer: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                Button {
                    Task { await pro.restore() }
                } label: {
                    Text("Restore Purchases")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Subscriptions auto-renew.\nCancel anytime in Settings.")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.trailing)
            }

            HStack(spacing: 6) {
                Link("Terms of Use", destination: LegalURL.termsOfUse)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))

                Text("·")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))

                Link("Privacy Policy", destination: LegalURL.privacy)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)

            if let purchaseError {
                Text(purchaseError)
                    .font(.system(size: 11))
                    .foregroundStyle(.red.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 28)
    }

    // MARK: Actions

    @MainActor
    private func purchaseSelected() async {
        guard
            let id = selectedID,
            let product = pro.products.first(where: { $0.id == id })
        else { return }
        purchaseError = nil
        do {
            _ = try await pro.purchase(product)
        } catch {
            purchaseError = error.localizedDescription
        }
    }
}

// MARK: - Product card

private struct ProductCard: View {
    let product: Product
    let isSelected: Bool
    let isRecommended: Bool
    let trialLabel: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.red : .white.opacity(0.25), lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                    if isSelected {
                        Circle().fill(Color.red).frame(width: 10, height: 10)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(planTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)

                        if let trialLabel {
                            Text(trialLabel)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.black)
                                .tracking(0.4)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Color.red))
                        }

                        if isRecommended {
                            Text("BEST VALUE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.red)
                                .tracking(0.4)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().strokeBorder(Color.red.opacity(0.5), lineWidth: 1))
                        }
                    }
                    Text(planSubtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(isSelected ? Color.red : .clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var planTitle: String {
        switch product.id {
        case ProProductID.lifetime: return "Lifetime"
        case ProProductID.monthly:  return "Monthly"
        default:                    return product.displayName
        }
    }

    private var planSubtitle: String {
        switch product.id {
        case ProProductID.lifetime: return "One-time purchase · yours forever"
        case ProProductID.monthly:  return "Billed monthly · cancel anytime"
        default:                    return product.description
        }
    }
}
