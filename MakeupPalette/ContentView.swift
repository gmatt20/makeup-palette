import SwiftUI

struct ContentView: View {
  /// The real face session. `@State` keeps one instance alive across posture changes, so the
  /// applied look, viewing angle, and restored makeup survive folding and rotation.
  @State private var bridge = FaceMakeupEffectBridge()

  var body: some View {
    DuoStudioLayout {
      CameraPreviewView {
        MakeupFacePreview(controller: bridge.face)
      } effects: {
        // The renderer draws the makeup on the portrait itself, so the mock effect badges are
        // no longer needed here. To keep the old mock camera instead, swap the two lines above
        // back to MockCameraFeedView() and MockCameraEffectsView(look: bridge.look).
        EmptyView()
      }
    } palette: {
      MakeupPaletteView(bridge: bridge)
    }
  }
}

