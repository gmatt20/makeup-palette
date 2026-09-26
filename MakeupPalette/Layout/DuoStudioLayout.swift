import SwiftUI

struct DuoStudioLayout<Camera: View, Palette: View>: View {
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var hingeIsOpen: Bool?
  @State private var hingeAngleDegrees: Double?
  @State private var hingeFullyOpen: Bool?

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

        let isPortrait = geometry.size.height >= geometry.size.width
        let longAxis: Axis = isPortrait ? .vertical : .horizontal
        let isReflecting = hingeAngleDegrees.map { $0 > 3 && $0 < 87 } ?? false
        // Portrait fold: crease sits above the palette -> opacity on top.
        // Landscape: hug the crease (leading) at ~90°, drop to the bottom when
        // fully open.
        let opacityPlacement: OpacityPlacement = isPortrait
          ? .top
          : ((hingeFullyOpen ?? false) ? .bottom : .leading)

        if hingeIsOpen ?? isInnerDisplay {
          ArrangementView {
            camera
          } secondary: {
            palette
              .environment(
                \.swatchReflection,
                SwatchReflection(isActive: isReflecting, longAxis: longAxis)
              )
              .environment(\.opacityPlacement, opacityPlacement)
          }
          // Give the camera the larger share of the split (≈64%) so the
          // makeup panel is the smaller region.
          .splitArrangementLayoutRatio(0.64)
          .arrangementViewStyle(.split)
        } else {
          camera.ignoresSafeArea()
        }
      }
      .background(Color(white: 0.22).ignoresSafeArea())
      .onHingeChange { _, context in
        hingeIsOpen = context.hinge.map { $0.status != .closed }
        hingeAngleDegrees = context.hinge.map { $0.angle.degrees }
        hingeFullyOpen = context.hinge.map { $0.status == .fullyOpen }
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
