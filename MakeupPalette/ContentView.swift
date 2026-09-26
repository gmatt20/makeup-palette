import SwiftUI

struct ContentView: View {
  @State private var bridge = MockMakeupEffectBridge()
  // RevenueCat when the SDK + API key are configured, else the offline mock.
  @State private var premium: any PremiumStore = PremiumStoreFactory.make()

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
