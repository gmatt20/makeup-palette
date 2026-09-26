import SwiftUI

struct CameraPreviewView<Feed: View, Effects: View>: View {
  private var feed: Feed
  private var effects: Effects

  init(
    @ViewBuilder feed: () -> Feed,
    @ViewBuilder effects: () -> Effects
  ) {
    self.feed = feed()
    self.effects = effects()
  }

  var body: some View {
    ZStack {
      feed

      effects
        .allowsHitTesting(false)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.black)
    .clipped()
  }
}
