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
  private(set) var monthlyPriceText = "$4.99"

  @ObservationIgnored private let entitlementID = "premium"
  @ObservationIgnored private var monthlyPackage: Package?

  init(apiKey: String) {
    Purchases.logLevel = .warn
    Purchases.configure(withAPIKey: apiKey)

    Task { await refreshCustomerInfo() }
    Task { await loadOffering() }
    Task { await observeCustomerInfo() }
  }

  func subscribe() {
    Task {
      if monthlyPackage == nil { await loadOffering() }
      guard let package = monthlyPackage else { return }
      do {
        let result = try await Purchases.shared.purchase(package: package)
        if !result.userCancelled {
          apply(result.customerInfo)
        }
      } catch {
        print("RevenueCat purchase failed: \(error.localizedDescription)")
      }
    }
  }

  func restore() {
    Task {
      do {
        apply(try await Purchases.shared.restorePurchases())
      } catch {
        print("RevenueCat restore failed: \(error.localizedDescription)")
      }
    }
  }

  private func loadOffering() async {
    do {
      let offerings = try await Purchases.shared.offerings()
      if let package = offerings.current?.monthly ?? offerings.current?.availablePackages.first {
        monthlyPackage = package
        monthlyPriceText = package.storeProduct.localizedPriceString
      }
    } catch {
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
    isSubscribed = info.entitlements[entitlementID]?.isActive == true
  }
}
#endif
