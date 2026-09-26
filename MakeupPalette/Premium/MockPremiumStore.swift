import Foundation
import Observation

/// Demo `PremiumStore` used until the RevenueCat SDK is wired in.
///
/// Grants entitlement instantly on `subscribe()` and persists it in
/// `UserDefaults`, so the paywall + unlock flow is fully demoable offline.
@MainActor
@Observable
final class MockPremiumStore: PremiumStore {
  private(set) var isSubscribed: Bool

  let monthlyPriceText = "$4.99"

  @ObservationIgnored private let defaults: UserDefaults
  private static let subscribedKey = "premium.subscribed"

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    isSubscribed = defaults.bool(forKey: Self.subscribedKey)
  }

  func subscribe() {
    isSubscribed = true
    defaults.set(true, forKey: Self.subscribedKey)
  }

  func restore() {
    isSubscribed = defaults.bool(forKey: Self.subscribedKey)
  }
}
