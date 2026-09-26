import Foundation

/// Build-time secrets injected via `Config/Base.xcconfig` -> `Info.plist`.
enum AppSecrets {
  /// RevenueCat public Apple SDK key (`appl_...`). `nil` until configured, in
  /// which case the app falls back to `MockPremiumStore`.
  static var revenueCatAPIKey: String? {
    guard
      let raw = Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_APPLE_API_KEY") as? String
    else { return nil }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
