enum MakeupCategory: String, CaseIterable, Identifiable {
  case lips
  case blush
  case brow

  var id: Self { self }

  var title: String {
    switch self {
    case .lips: "Lips"
    case .blush: "Blush"
    case .brow: "Brows"
    }
  }
}
