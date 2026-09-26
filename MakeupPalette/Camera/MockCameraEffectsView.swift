import SwiftUI

struct MockCameraEffectsView: View {
  var lipsEffect: MakeupOption?
  var blushEffect: MakeupOption?
  var browEffect: MakeupOption?
  var opacity: Float

  var body: some View {
    VStack {
      Spacer()

      HStack(spacing: 8) {
        if let lipsEffect {
          EffectBadge(title: "Lips", option: lipsEffect)
        }

        if let blushEffect {
          EffectBadge(title: "Blush", option: blushEffect)
        }

        if let browEffect {
          EffectBadge(title: "Brows", option: browEffect)
        }

        Spacer(minLength: 0)
      }
      .opacity(Double(opacity))
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
