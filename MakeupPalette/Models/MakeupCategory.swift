enum MakeupCategory: String, CaseIterable, Identifiable {
  case brow
  case blush

  var id: Self { self }

  var title: String {
    switch self {
    case .brow: "Brows"
    case .blush: "Blush"
    }
  }
}
