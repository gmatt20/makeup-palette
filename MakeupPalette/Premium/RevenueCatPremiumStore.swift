#if canImport(RevenueCat)
import Foundation
import Observation
import RevenueCat

/// Live `PremiumStore` backed by RevenueCat.
///
/// Expects a `premium` entitlement and a monthly package configured in the
/// RevenueCat dashboard (linked to an App Store Connect product). Until that
/// exists the SDK returns no offerings, so `isSubscribed` stays `false` and
/// `subscribe()` finds no package — the rest of the app is unaffected.
@MainActor
@Observable
final class RevenueCatPremiumStore: PremiumStore {
  private(set) var isSubscribed = false
  private(set) var isPurchasing = false
  private(set) var lastPurchaseError: String?
  private(set) var monthlyPriceText = "$4.99"

  @ObservationIgnored private var monthlyPackage: Package?
  @ObservationIgnored private var offeringsDiagnostic = "(offerings not loaded)"

  init(apiKey: String) {
    Purchases.logLevel = .warn
    Purchases.configure(withAPIKey: apiKey)

    Task { await refreshCustomerInfo() }
    Task { await loadOffering() }
    Task { await observeCustomerInfo() }
  }

  func subscribe() {
    lastPurchaseError = nil
    isPurchasing = true
    Task {
      defer { isPurchasing = false }
      if monthlyPackage == nil { await loadOffering() }
      guard let package = monthlyPackage else {
        lastPurchaseError = "No purchasable package. \(offeringsDiagnostic) In RevenueCat, mark the offering as Current and add a package linked to studio_monthly_499."
        return
      }
      do {
        let result = try await Purchases.shared.purchase(package: package)
        if !result.userCancelled {
          apply(result.customerInfo)
        }
      } catch {
        lastPurchaseError = error.localizedDescription
      }
    }
  }

  func restore() {
    lastPurchaseError = nil
    isPurchasing = true
    Task {
      defer { isPurchasing = false }
      do {
        apply(try await Purchases.shared.restorePurchases())
      } catch {
        lastPurchaseError = error.localizedDescription
      }
    }
  }

  private func loadOffering() async {
    do {
      let offerings = try await Purchases.shared.offerings()
      // Prefer the Current offering, but fall back to any offering so an
      // offering that wasn't marked "Current" still works for the demo.
      let offering = offerings.current ?? offerings.all.values.first
      let package = offering?.monthly ?? offering?.availablePackages.first
      offeringsDiagnostic = "(offerings=\(offerings.all.count), current=\(offerings.current?.identifier ?? "none"), packages=\(offering?.availablePackages.count ?? 0))"
      if let package {
        monthlyPackage = package
        monthlyPriceText = package.storeProduct.localizedPriceString
      }
    } catch {
      offeringsDiagnostic = "(offerings error: \(error.localizedDescription))"
      print("RevenueCat offerings failed: \(error.localizedDescription)")
    }
  }

  private func refreshCustomerInfo() async {
    guard let info = try? await Purchases.shared.customerInfo() else { return }
    apply(info)
  }

  private func observeCustomerInfo() async {
    for await info in Purchases.shared.customerInfoStream {
      apply(info)
    }
  }

  private func apply(_ info: CustomerInfo) {
    // Any active entitlement unlocks premium (this app has a single tier).
    // `active` is "active in any environment", so Test Store / sandbox
    // purchases register too, regardless of the entitlement's identifier.
    isSubscribed = !info.entitlements.active.isEmpty
  }
}
#endif
