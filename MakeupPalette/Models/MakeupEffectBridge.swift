@MainActor
protocol MakeupEffectBridge: AnyObject {
  var browEffect: MakeupOption? { get }
  var blushEffect: MakeupOption? { get }
  var lipsEffect: MakeupOption? { get }
  var opacity: Float { get }

  func applyBrowEffect(_ option: MakeupOption)
  func disableBrowEffect()
  func applyBlushEffect(_ option: MakeupOption)
  func disableBlushEffect()
  func applyLipsEffect(_ option: MakeupOption)
  func disableLipsEffect()
  func applyOpacity(_ value: Float)
}

extension MakeupEffectBridge {
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
