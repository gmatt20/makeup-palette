import SwiftUI

struct ContentView: View {
  @State private var bridge = MockMakeupEffectBridge()
  // RevenueCat when the SDK + API key are configured, else the offline mock.
  @State private var premium: any PremiumStore = PremiumStoreFactory.make()
  /// Non-nil while "Preview All" replaces the studio with the 2×2 camera grid.
  @State private var previewAll: PreviewAllSession?

  var body: some View {
    ZStack {
      if let session = previewAll {
        PreviewAllGridView(
          session: session,
          baseLook: bridge.look,
          onPrevious: { previewAll?.showPreviousPage() },
          onNext: { previewAll?.showNextPage() },
          onCancel: { withAnimation(.smooth) { previewAll = nil } }
        )
        .transition(.opacity)
      } else {
        DuoStudioLayout {
          CameraPreviewView {
            MockCameraFeedView()
          } effects: {
            MockCameraEffectsView(look: bridge.look)
          }
        } palette: {
          MakeupPaletteView(bridge: bridge, premium: premium) { category in
            withAnimation(.smooth) { previewAll = PreviewAllSession(category: category) }
          }
        } crease: { axis in
          CreaseOpacitySlider(opacity: bridge.opacity, axis: axis) { bridge.applyOpacity($0) }
        }
        .transition(.opacity)
      }
    }
  }
}
