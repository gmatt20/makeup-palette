struct MakeupOption: Identifiable, Equatable {
  let id: String
  let category: MakeupCategory
  let name: String
  let swatch: MakeupSwatch
  let tint: MakeupColor

  /// The editable base color, present only for color swatches.
  var editableColor: MakeupColor? {
    if case .color(let color) = swatch { return color }
    return nil
  }

  /// A copy recolored to `color`, used by the long-press color editor.
  /// PNG swatches have no editable color and are returned unchanged.
  func recolored(to color: MakeupColor) -> MakeupOption {
    guard editableColor != nil else { return self }
    return MakeupOption(
      id: id,
      category: category,
      name: name,
      swatch: .color(color),
      tint: color
    )
  }
}
