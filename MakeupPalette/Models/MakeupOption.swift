struct MakeupOption: Identifiable, Equatable {
  let id: String
  let category: MakeupCategory
  let name: String
  let swatch: MakeupSwatch
  let tint: MakeupColor
}
