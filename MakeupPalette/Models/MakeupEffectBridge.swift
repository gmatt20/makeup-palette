@MainActor
protocol MakeupEffectBridge: AnyObject {
  var browEffect: MakeupOption? { get }
  var blushEffect: MakeupOption? { get }
  var lipsEffect: MakeupOption? { get }
  var eyebrowMask: EyebrowMask? { get }
  var opacity: Float { get }

  func applyBrowEffect(_ option: MakeupOption)
  func disableBrowEffect()
  func applyBlushEffect(_ option: MakeupOption)
  func disableBlushEffect()
  func applyLipsEffect(_ option: MakeupOption)
  func disableLipsEffect()
  func applyEyebrowMask(_ mask: EyebrowMask)
  func disableEyebrowMask()
  func applyOpacity(_ value: Float)
}

extension MakeupEffectBridge {
  /// The single snapshot the fake-camera reads. Derived from the applied
  /// effects and global opacity, so the FC never touches palette internals.
  var look: MakeupLook {
    var effects: [MakeupCategory: MakeupOption] = [:]
    for category in MakeupCategory.allCases {
      if let option = selectedOption(for: category) {
        effects[category] = option
      }
    }
    return MakeupLook(effects: effects, eyebrowMask: eyebrowMask, opacity: opacity)
  }

  func selectedOption(for category: MakeupCategory) -> MakeupOption? {
    switch category {
    case .brow: browEffect
    case .blush: blushEffect
    case .lips: lipsEffect
    }
  }

  func select(_ option: MakeupOption?, for category: MakeupCategory) {
    switch category {
    case .brow:
      if let option {
        applyBrowEffect(option)
      } else {
        disableBrowEffect()
      }
    case .blush:
      if let option {
        applyBlushEffect(option)
      } else {
        disableBlushEffect()
      }
    case .lips:
      if let option {
        applyLipsEffect(option)
      } else {
        disableLipsEffect()
      }
    }
  }
}
