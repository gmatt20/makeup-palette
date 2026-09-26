import SwiftUI

struct ContentView: View {
  var body: some View {
    CameraPreviewView {
      MockCameraFeedView()
    } effects: {
      EmptyView()
    }
    .ignoresSafeArea()
  }
}
