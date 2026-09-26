import SwiftUI

struct ContentView: View {
  @State private var bridge = MockMakeupEffectBridge()

  var body: some View {
    DuoStudioLayout {
      CameraPreviewView {
        MockCameraFeedView()
      } effects: {
        MockCameraEffectsView(
          lipsEffect: bridge.lipsEffect,
          blushEffect: bridge.blushEffect,
          browEffect: bridge.browEffect,
          opacity: bridge.opacity
        )
      }
    } palette: {
      MakeupPaletteView(bridge: bridge)
    }
  }
}
