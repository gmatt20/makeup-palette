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

      HStack(spacing: 8) {
        ForEach(look.activeOptions) { option in
          EffectBadge(title: option.category.title, option: option)
        }

        Spacer(minLength: 0)

        if !look.isEmpty {
          OpacityChip(opacity: look.opacity)
        }
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 32)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
