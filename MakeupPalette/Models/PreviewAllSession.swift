/// A "Preview All" session: one category's options tried on side by side,
/// four fake cameras at a time.
///
/// Pure value logic — the layout owns it, the palette starts it, and each
/// camera only ever receives a finished `MakeupLook`, so the MP/FC seam holds.
struct PreviewAllSession: Equatable {
  /// How many cameras share the screen.
  static let cameraCount = 4

  var category: MakeupCategory
  /// Which window of four is on screen. Always within `0..<pageCount`.
  private(set) var page = 0

  init(category: MakeupCategory) {
    self.category = category
  }

  var options: [MakeupOption] { MakeupCatalog.options(for: category) }

  var pageCount: Int {
    max(1, (options.count + Self.cameraCount - 1) / Self.cameraCount)
  }

  /// The options on screen, in reading order (top-left, top-right,
  /// bottom-left, bottom-right). A short final page wraps around to the start
  /// of the catalog so all four cameras stay filled.
  var visibleOptions: [MakeupOption] {
    let all = options
    guard !all.isEmpty else { return [] }
    let start = page * Self.cameraCount
    return (0..<min(Self.cameraCount, all.count)).map { all[(start + $0) % all.count] }
  }

  mutating func showNextPage() {
    page = (page + 1) % pageCount
  }

  mutating func showPreviousPage() {
    page = (page - 1 + pageCount) % pageCount
  }

  /// One look per visible option: `base` with this category swapped out, so
  /// the other applied regions, brow mask, and opacity carry over. A custom
  /// recolor the user already applied is kept for its matching option.
  func looks(over base: MakeupLook) -> [(option: MakeupOption, look: MakeupLook)] {
    let applied = base.option(for: category)
    return visibleOptions.map { option in
      var look = base
      look.effects[category] = applied?.id == option.id ? applied : option
      return (option, look)
    }
  }
}
