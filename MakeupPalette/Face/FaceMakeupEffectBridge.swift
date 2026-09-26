import MakeupCore
import MakeupFace
import Observation
import SwiftUI

/// Implements the app's ``MakeupEffectBridge`` on top of the real face component.
///
/// The palette stays authoritative for what the user can choose. This type only translates:
/// it records the palette's intent synchronously — which is what ``MakeupEffectBridge/look``
/// reads back — and dispatches the render update to ``MakeupFaceController``.
///
/// `MakeupEffectBridge` is synchronous while the renderer is `async throws`, so a render can
/// still be in flight (or have failed) when the palette next reads `look`. Failures never
/// silently change the rendered look: they surface through
/// ``MakeupFaceController/commandError`` and ``MakeupFaceController/status`` for the UI to show.
@MainActor
@Observable
final class FaceMakeupEffectBridge: MakeupEffectBridge {
  /// The single face session for the whole app. Never recreate this on fold or rotation.
  let face = MakeupFaceController()

  private(set) var browEffect: MakeupOption?
  private(set) var blushEffect: MakeupOption?
  private(set) var lipsEffect: MakeupOption?
  private(set) var eyebrowMask: EyebrowMask?
  private(set) var opacity: Float = 1

  func applyBrowEffect(_ option: MakeupOption) {
    guard option.category == .brow else { return }
    browEffect = option
    send(.browFill, option)
  }

  func disableBrowEffect() {
    browEffect = nil
    Task { try? await face.clear(.browFill) }
  }

  func applyBlushEffect(_ option: MakeupOption) {
    guard option.category == .blush else { return }
    blushEffect = option
    send(.blush, option)
  }

  func disableBlushEffect() {
    blushEffect = nil
    Task { try? await face.clear(.blush) }
  }

  func applyLipsEffect(_ option: MakeupOption) {
    guard option.category == .lips else { return }
    lipsEffect = option
    send(.lipstick, option)
  }

  func disableLipsEffect() {
    lipsEffect = nil
    Task { try? await face.clear(.lipstick) }
  }

  /// Brow shape. Tracked in the look so it stays independent of brow tint.
  /// NOTE: the RealityKit `MakeupFaceController` does not yet implement a
  /// brow-shape stamp (no `setEyebrowStyle`), so this records state only; wire
  /// it to a controller method once brow-shape rendering exists.
  func applyEyebrowMask(_ mask: EyebrowMask) {
    eyebrowMask = mask
  }

  func disableEyebrowMask() {
    eyebrowMask = nil
  }

  /// The palette's global opacity becomes per-region intensity on every applied region.
  func applyOpacity(_ value: Float) {
    guard value.isFinite else { return }
    opacity = min(max(value, 0), 1)
    for treatment in [Treatment.browFill, .blush, .lipstick] {
      guard let style = face.look.treatments[treatment] else { continue }
      Task { try? await face.setMakeup(treatment, color: style.color, intensity: Double(opacity)) }
    }
  }

  private func send(_ treatment: Treatment, _ option: MakeupOption) {
    Task {
      do {
        try await face.setMakeup(treatment,
                                 color: try option.tint.coreColor(),
                                 intensity: Double(opacity))
      } catch {
        // The previously rendered look stays visible and saved. `face.commandError` carries
        // the reason so the palette can surface it rather than claiming success.
      }
    }
  }
}

private extension MakeupColor {
  /// The app models color as `Float` and does not validate it; `MakeupCore` validates and
  /// stores `Double`, throwing on non-finite or out-of-range components.
  func coreColor() throws -> MakeupCore.MakeupColor {
    try MakeupCore.MakeupColor(red: Double(red), green: Double(green), blue: Double(blue))
  }
}

private extension MakeupCategory {
  var coreTreatment: Treatment {
    switch self {
    case .lips: .lipstick
    case .blush: .blush
    case .brow: .browFill
    }
  }
}

extension MakeupFaceController {
  /// Renders a whole app `MakeupLook` (palette effects + global opacity) onto
  /// this face. Used by the Preview All grid, where each cell owns a controller
  /// and shows one variation. Applies treatments serially so the controller's
  /// in-flight guard is never tripped; requires the face to be `.ready`.
  func apply(_ appLook: MakeupLook) {
    let intensity = Double(min(max(appLook.opacity, 0), 1))
    Task {
      for category in MakeupCategory.allCases {
        let treatment = category.coreTreatment
        do {
          if let option = appLook.effects[category] {
            try await setMakeup(treatment, color: try option.tint.coreColor(), intensity: intensity)
          } else {
            try await clear(treatment)
          }
        } catch {
          // Keep whatever is currently rendered on this cell.
        }
      }
    }
  }
}
