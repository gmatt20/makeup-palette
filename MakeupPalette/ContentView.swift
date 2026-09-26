import SwiftUI

struct ContentView: View {
  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "paintpalette.fill")
        .font(.system(size: 48))
        .foregroundStyle(.tint)
        .accessibilityHidden(true)

      Text("Makeup Palette")
        .font(.title.bold())
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(uiColor: .systemBackground))
  }
}

