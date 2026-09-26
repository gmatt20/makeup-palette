import Foundation
import Observation

@MainActor
@Observable
final class MockMakeupEffectBridge: MakeupEffectBridge {
  private(set) var browEffect: MakeupOption?
  private(set) var blushEffect: MakeupOption?
  private(set) var lipsEffect: MakeupOption?
  private(set) var eyebrowMask: EyebrowMask?
  private(set) var opacity: Float

  @ObservationIgnored private let defaults: UserDefaults
  private static let opacityKey = "makeup.globalOpacity"

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    let savedOpacity = defaults.object(forKey: Self.opacityKey) == nil
      ? 1
      : defaults.float(forKey: Self.opacityKey)
    opacity = savedOpacity.isFinite ? min(max(savedOpacity, 0), 1) : 1
  }

  func applyBrowEffect(_ option: MakeupOption) {
    guard option.category == .brow else { return }
    browEffect = option
  }

  func disableBrowEffect() {
    browEffect = nil
  }

  func applyBlushEffect(_ option: MakeupOption) {
    guard option.category == .blush else { return }
    blushEffect = option
  }

  func disableBlushEffect() {
    blushEffect = nil
  }

  func applyLipsEffect(_ option: MakeupOption) {
    guard option.category == .lips else { return }
    lipsEffect = option
  }

  func disableLipsEffect() {
    lipsEffect = nil
  }

  func applyEyebrowMask(_ mask: EyebrowMask) {
    eyebrowMask = mask
  }

  func disableEyebrowMask() {
    eyebrowMask = nil
  }

  func applyOpacity(_ value: Float) {
    guard value.isFinite else { return }
    opacity = min(max(value, 0), 1)
    defaults.set(opacity, forKey: Self.opacityKey)
  }
}
