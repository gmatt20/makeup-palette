import SwiftUI

struct ContentView: View {
  @State private var bridge = MockMakeupEffectBridge()

  var body: some View {
    DuoStudioLayout {
      CameraPreviewView {
        MockCameraFeedView()
      } effects: {
        MockCameraEffectsView(
          browEffect: bridge.browEffect,
          blushEffect: bridge.blushEffect,
          opacity: bridge.opacity
        )
      }
    } palette: {
      MakeupPaletteView(bridge: bridge)
    }
  }
}
