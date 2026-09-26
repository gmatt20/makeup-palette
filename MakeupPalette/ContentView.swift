import SwiftUI

struct ContentView: View {
  @State private var bridge = MockMakeupEffectBridge()
  @State private var premium = MockPremiumStore()

  var body: some View {
    DuoStudioLayout {
      CameraPreviewView {
        MockCameraFeedView()
      } effects: {
        MockCameraEffectsView(look: bridge.look)
      }
    } palette: {
      MakeupPaletteView(bridge: bridge, premium: premium)
    }
  }
}
