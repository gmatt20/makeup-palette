enum MakeupCatalog {
  static let lipOptions: [MakeupOption] = [
    swatch(.lips, "lips.classicRed", "Classic Red", 0xC41E3A),
    swatch(.lips, "lips.nudeBeige", "Nude Beige", 0xC8A08A),
    swatch(.lips, "lips.rosyPink", "Rosy Pink", 0xD46A7E),
    swatch(.lips, "lips.berry", "Berry", 0x8E2A4F),
    swatch(.lips, "lips.coral", "Coral", 0xF26B5B),
    swatch(.lips, "lips.mauve", "Mauve", 0xA8757F),
    swatch(.lips, "lips.wine", "Wine", 0x5E1A2E),
    swatch(.lips, "lips.peach", "Peach", 0xF4A68A),
    swatch(.lips, "lips.hotPink", "Hot Pink", 0xE0457B),
    swatch(.lips, "lips.brickBrown", "Brick Brown", 0x9C4A3A)
  ]

  static let blushOptions: [MakeupOption] = [
    swatch(.blush, "blush.softPink", "Soft Pink", 0xF4A7B0),
    swatch(.blush, "blush.peach", "Peach", 0xF6A889),
    swatch(.blush, "blush.coral", "Coral", 0xE8837A),
    swatch(.blush, "blush.rose", "Rose", 0xD3727F),
    swatch(.blush, "blush.berry", "Berry", 0xB04A64),
    swatch(.blush, "blush.terracotta", "Terracotta", 0xC6705A)
  ]

  static let browOptions: [MakeupOption] = [
    swatch(.brow, "brow.taupe", "Taupe", 0x8B776B),
    swatch(.brow, "brow.softBrown", "Soft Brown", 0x6D4F3E),
    swatch(.brow, "brow.chestnut", "Chestnut", 0x794634),
    swatch(.brow, "brow.espresso", "Espresso", 0x352A28)
  ]

  static func options(for category: MakeupCategory) -> [MakeupOption] {
    switch category {
    case .lips: lipOptions
    case .blush: blushOptions
    case .brow: browOptions
    }
  }

  /// Builds a solid-color swatch whose preview tile and applied tint share one color.
  private static func swatch(
    _ category: MakeupCategory,
    _ id: String,
    _ name: String,
    _ rgb: UInt32
  ) -> MakeupOption {
    let color = MakeupColor(rgb: rgb)
    return MakeupOption(id: id, category: category, name: name, swatch: .color(color), tint: color)
  }
}
