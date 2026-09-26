import SwiftUI

/// Describes how palette swatches mirror themselves while the device is folded.
///
/// The mirror line is the phone's longer axis, so each box flips across it:
/// a portrait device (vertical long axis) mirrors horizontally, a landscape
/// device (horizontal long axis) mirrors vertically. Driven by the hinge in
/// `DuoStudioLayout` and read by each swatch through the environment.
struct SwatchReflection: Equatable {
  /// Whether the fold currently sits in the reflecting range (3°–87°).
  var isActive: Bool = false
  /// The phone's longer axis — the line each swatch mirrors across.
  var longAxis: Axis = .vertical
}

private struct SwatchReflectionKey: EnvironmentKey {
  static let defaultValue = SwatchReflection()
}

extension EnvironmentValues {
  var swatchReflection: SwatchReflection {
    get { self[SwatchReflectionKey.self] }
    set { self[SwatchReflectionKey.self] = newValue }
  }
}

/// Where the palette's opacity control sits, chosen from fold + orientation so
/// it hugs the hinge/crease when folded and drops to the bottom when flat.
enum OpacityPlacement {
  /// Horizontal, along the top edge — portrait fold, crease above the palette.
  case top
  /// Vertical, along the leading edge — landscape fold (~90°), crease at left.
  case leading
  /// Horizontal, along the bottom edge — fully open, no prominent crease.
  case bottom
}

private struct OpacityPlacementKey: EnvironmentKey {
  static let defaultValue: OpacityPlacement = .bottom
}

extension EnvironmentValues {
  var opacityPlacement: OpacityPlacement {
    get { self[OpacityPlacementKey.self] }
    set { self[OpacityPlacementKey.self] = newValue }
  }
}

extension View {
  /// Mirrors the view across the phone's longer axis while the fold is
  /// partially open, animating in and out as the hinge crosses the range.
  func swatchReflectionEffect(_ reflection: SwatchReflection) -> some View {
    let flipX = reflection.isActive && reflection.longAxis == .vertical
    let flipY = reflection.isActive && reflection.longAxis == .horizontal
    return scaleEffect(x: flipX ? -1 : 1, y: flipY ? -1 : 1)
      .animation(.easeInOut(duration: 0.25), value: reflection)
  }
}
