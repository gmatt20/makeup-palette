import SwiftUI

struct MockCameraFeedView: View {
  var body: some View {
    ZStack {
      LinearGradient(
        colors: [Color(white: 0.22), Color(white: 0.08)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )

      Image(systemName: "viewfinder")
        .font(.system(size: 64, weight: .ultraLight))
        .foregroundStyle(.white.opacity(0.75))
        .accessibilityHidden(true)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Camera preview placeholder")
  }
}
