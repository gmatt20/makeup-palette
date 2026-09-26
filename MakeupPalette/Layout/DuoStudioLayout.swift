import SwiftUI

struct DuoStudioLayout<Camera: View, Palette: View>: View {
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var hingeIsOpen: Bool?

  private var camera: Camera
  private var palette: Palette

  init(
    @ViewBuilder camera: () -> Camera,
    @ViewBuilder palette: () -> Palette
  ) {
    self.camera = camera()
    self.palette = palette()
  }

  var body: some View {
    if #available(iOS 27.1, *) {
      GeometryReader { geometry in
        let isInnerDisplay = !geometry.reservedRegions(
          kind: .division,
          options: .includeInactive
        ).isEmpty

        if hingeIsOpen ?? isInnerDisplay {
          ArrangementView {
            camera
          } secondary: {
            palette
          }
          .arrangementViewStyle(.split)
        } else {
          camera.ignoresSafeArea()
        }
      }
      .background(Color(white: 0.22).ignoresSafeArea())
      .onHingeChange { _, context in
        hingeIsOpen = context.hinge.map { $0.status != .closed }
      }
    } else {
      GeometryReader { geometry in
        if horizontalSizeClass == .regular {
          if geometry.size.width > geometry.size.height {
            HStack(spacing: 0) {
              camera
              palette
            }
          } else {
            VStack(spacing: 0) {
              camera
              palette
            }
          }
        } else {
          camera.ignoresSafeArea()
        }
      }
      .background(Color(white: 0.22).ignoresSafeArea())
    }
  }
}
