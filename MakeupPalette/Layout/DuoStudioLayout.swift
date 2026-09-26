import SwiftUI

struct DuoStudioLayout<Camera: View, Palette: View, Crease: View>: View {
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var hingeIsOpen: Bool?
  @State private var hingeAngleDegrees: Double?
  @State private var hingeFullyOpen: Bool?

  private var camera: Camera
  private var palette: Palette
  /// Control placed inside the fold while partially folded, laid out along
  /// the crease's long axis.
  private var crease: (Axis) -> Crease

  init(
    @ViewBuilder camera: () -> Camera,
    @ViewBuilder palette: () -> Palette,
    @ViewBuilder crease: @escaping (Axis) -> Crease
  ) {
    self.camera = camera()
    self.palette = palette()
    self.crease = crease
  }

  var body: some View {
    if #available(iOS 27.1, *) {
      GeometryReader { geometry in
        let isInnerDisplay = !geometry.reservedRegions(
          kind: .division,
          options: .includeInactive
        ).isEmpty

        // Only active regions come back by default: the division is active
        // while partially folded and drops out once the device lies flat.
        let activeCrease = geometry.reservedRegions(kind: .division).first

        let isPortrait = geometry.size.height >= geometry.size.width
        let longAxis: Axis = isPortrait ? .vertical : .horizontal
        let isReflecting = hingeAngleDegrees.map { $0 > 3 && $0 < 87 } ?? false
        // Portrait fold: crease sits above the palette -> opacity on top.
        // Landscape: hug the crease (leading) at ~90°, drop to the bottom when
        // fully open.
        // A bent fold overrides all of that: opacity moves into the crease.
        let opacityPlacement: OpacityPlacement = activeCrease != nil
          ? .crease
          : isPortrait
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
          .overlay {
            if let activeCrease {
              creaseControl(in: activeCrease)
                .transition(.opacity)
            }
          }
          .animation(.smooth, value: activeCrease != nil)
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

  /// Centers the crease control on the division region, running along its
  /// long side with a little breathing room at each end.
  @available(iOS 27.1, *)
  private func creaseControl(in region: ReservedRegion) -> some View {
    let band = region.frame
    let axis: Axis = band.width >= band.height ? .horizontal : .vertical
    let length = min((axis == .horizontal ? band.width : band.height) - 48, 460)

    return crease(axis)
      .frame(
        width: axis == .horizontal ? max(length, 0) : nil,
        height: axis == .vertical ? max(length, 0) : nil
      )
      .position(x: band.midX, y: band.midY)
  }
}
