import Foundation

/// Builds the app's `PremiumStore`: RevenueCat when the SDK is linked and an
/// API key is configured, otherwise the offline `MockPremiumStore`.
///
/// This is the ONE place that decides which store is live, so `ContentView`
/// stays agnostic.
enum PremiumStoreFactory {
  @MainActor
  static func make() -> any PremiumStore {
    #if canImport(RevenueCat)
    if let apiKey = AppSecrets.revenueCatAPIKey {
      return RevenueCatPremiumStore(apiKey: apiKey)
    }
    #endif
    return MockPremiumStore()
  }
}
