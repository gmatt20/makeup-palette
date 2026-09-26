enum MakeupCatalog {
  static let browOptions: [MakeupOption] = [
    .init(id: "brow.taupe", category: .brow, name: "Taupe", swatch: .color(.init(rgb: 0x8B776B)), tint: .init(rgb: 0x8B776B)),
    .init(id: "brow.softBrown", category: .brow, name: "Soft Brown", swatch: .color(.init(rgb: 0x6D4F3E)), tint: .init(rgb: 0x6D4F3E)),
    .init(id: "brow.chestnut", category: .brow, name: "Chestnut", swatch: .color(.init(rgb: 0x794634)), tint: .init(rgb: 0x794634)),
    .init(id: "brow.espresso", category: .brow, name: "Espresso", swatch: .color(.init(rgb: 0x352A28)), tint: .init(rgb: 0x352A28))
  ]

  static let blushOptions: [MakeupOption] = [
    .init(id: "blush.rose", category: .blush, name: "Rose", swatch: .color(.init(rgb: 0xC67586)), tint: .init(rgb: 0xC67586)),
    .init(id: "blush.peach", category: .blush, name: "Peach", swatch: .color(.init(rgb: 0xE49B80)), tint: .init(rgb: 0xE49B80)),
    .init(id: "blush.coral", category: .blush, name: "Coral", swatch: .color(.init(rgb: 0xD96F73)), tint: .init(rgb: 0xD96F73)),
    .init(id: "blush.berry", category: .blush, name: "Berry", swatch: .color(.init(rgb: 0xA95170)), tint: .init(rgb: 0xA95170))
  ]

  static func options(for category: MakeupCategory) -> [MakeupOption] {
    switch category {
    case .brow: browOptions
    case .blush: blushOptions
    }
  }
}
