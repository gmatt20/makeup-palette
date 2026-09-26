import SwiftUI

struct ContentView: View {
  @State private var bridge = MockMakeupEffectBridge()

  var body: some View {
    DuoStudioLayout {
      CameraPreviewView {
        MockCameraFeedView()
      } effects: {
        MockCameraEffectsView(look: bridge.look)
      }
    } palette: {
      MakeupPaletteView(bridge: bridge)
    }
  }
}
