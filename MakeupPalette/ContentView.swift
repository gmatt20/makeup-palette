import SwiftUI

struct ContentView: View {
  /// The real face session. `@State` keeps one instance alive across posture changes, so the
  /// applied look, viewing angle, and restored makeup survive folding and rotation.
  @State private var bridge = FaceMakeupEffectBridge()
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
            MakeupFacePreview(controller: bridge.face)
          } effects: {
            // The renderer draws the makeup on the portrait itself, so the mock effect badges
            // are not needed here. To return to the mock camera, swap in MockCameraFeedView()
            // and MockCameraEffectsView(look: bridge.look).
            EmptyView()
          }
        } palette: {
          MakeupPaletteView(bridge: bridge) { category in
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
