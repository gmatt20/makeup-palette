import SwiftUI

/// Mock overlay standing in for the real face renderer.
///
/// Reads a `MakeupLook` and lists the active effects plus the global opacity.
/// A real 3D face view can replace this by consuming the same `MakeupLook`.
struct MockCameraEffectsView: View {
  var look: MakeupLook

  var body: some View {
    VStack {
      Spacer()

      // Stack the badges when the camera is too narrow for one row (e.g. a
      // quarter-screen Preview All cell).
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 8) {
          badges
          Spacer(minLength: 0)
          opacityChip
        }

        VStack(alignment: .leading, spacing: 6) {
          badges
          opacityChip
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 32)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  @ViewBuilder
  private var badges: some View {
    ForEach(look.activeOptions) { option in
      EffectBadge(title: option.category.title, option: option)
    }

    if let mask = look.eyebrowMask {
      MaskBadge(title: "Brow Shape", mask: mask)
    }
  }

  @ViewBuilder
  private var opacityChip: some View {
    if !look.isEmpty {
      OpacityChip(opacity: look.opacity)
    }
  }
}

private struct EffectBadge: View {
  var title: String
  var option: MakeupOption

  var body: some View {
    HStack(spacing: 7) {
      Circle()
        .fill(Color(makeupColor: option.tint))
        .frame(width: 16, height: 16)

      Text("\(title): \(option.name)")
        .font(.caption.weight(.semibold))
        .lineLimit(1)
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 11)
    .padding(.vertical, 8)
    .background(.black.opacity(0.55), in: Capsule())
  }
}

private struct MaskBadge: View {
  var title: String
  var mask: EyebrowMask

  var body: some View {
    HStack(spacing: 7) {
      Image(systemName: "theatermasks.fill")
        .font(.caption)

      Text("\(title): \(mask.name)")
        .font(.caption.weight(.semibold))
        .lineLimit(1)
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 11)
    .padding(.vertical, 8)
    .background(.black.opacity(0.55), in: Capsule())
  }
}

private struct OpacityChip: View {
  var opacity: Float

  var body: some View {
    Text("Opacity \(Int((opacity * 100).rounded()))%")
      .font(.caption.weight(.semibold))
      .monospacedDigit()
      .foregroundStyle(.white)
      .padding(.horizontal, 11)
      .padding(.vertical, 8)
      .background(.black.opacity(0.55), in: Capsule())
  }
}
