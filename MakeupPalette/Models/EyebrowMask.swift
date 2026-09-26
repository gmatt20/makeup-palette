/// A brow-shape stencil backed by a PNG asset.
///
/// Independent of brow color: the FC renders this mask over the brow region
/// while `browEffect` supplies the tint. Kept as its own type so brow shape and
/// brow color can be applied and cleared separately.
struct EyebrowMask: Identifiable, Equatable {
  let id: String
  let name: String
  /// Name of the PNG stencil asset in the asset catalog.
  let assetName: String
}
