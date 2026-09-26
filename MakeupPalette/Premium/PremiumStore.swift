/// The subscription gate for premium makeup shades and full features.
///
/// The palette reads `isSubscribed` to decide whether a premium swatch is
/// locked, and calls `subscribe()` / `restore()` from the paywall. This is the
/// single seam the rest of the app depends on — swap `MockPremiumStore` for a
/// `RevenueCatPremiumStore` (below) without touching any UI.
///
/// ## RevenueCat integration point
/// A real implementation wraps the RevenueCat SDK:
/// - `Purchases.configure(withAPIKey:)` at launch.
/// - `isSubscribed` mirrors `customerInfo.entitlements["premium"]?.isActive`.
/// - `subscribe()` fetches the current offering and calls
///   `Purchases.shared.purchase(package:)` for the $4.99/mo package.
/// - `restore()` calls `Purchases.shared.restorePurchases()`.
/// Keep it `@Observable` so `isSubscribed` changes drive the UI live.
@MainActor
protocol PremiumStore: AnyObject {
  /// Whether the user currently has the premium entitlement.
  var isSubscribed: Bool { get }

  /// The displayed price of the monthly plan (e.g. "$4.99").
  var monthlyPriceText: String { get }

  /// True while a purchase/restore is in flight (drives the paywall spinner).
  var isPurchasing: Bool { get }

  /// A human-readable message from the last failed purchase/restore, or nil.
  var lastPurchaseError: String? { get }

  /// Begin/complete the purchase flow. The mock grants entitlement instantly.
  func subscribe()

  /// Restore a previously purchased subscription.
  func restore()
}
