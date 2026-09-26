/// An immutable snapshot of the look the fake-camera (FC) face should render.
///
/// This is the single surface the makeup palette (MP) writes and the FC reads.
/// A real 3D face renderer can replace the mock by consuming this value alone —
/// no palette or bridge changes required.
struct MakeupLook: Equatable {
  /// The applied option per region; absent regions are bare.
  var effects: [MakeupCategory: MakeupOption]
  /// Global strength applied to every effect, 0...1. The FC dims the rendered
  /// makeup by this amount — never the palette or its labels.
  var opacity: Float

  static let none = MakeupLook(effects: [:], opacity: 1)

  var isEmpty: Bool { effects.isEmpty }

  func option(for category: MakeupCategory) -> MakeupOption? {
    effects[category]
  }

  /// Active regions in palette order, for stable presentation.
  var activeOptions: [MakeupOption] {
    MakeupCategory.allCases.compactMap { effects[$0] }
  }
}
