import SwiftUI

/// Compact opacity slider that lives in the fold's division region while the
/// device is partially folded, running along the crease on either axis.
/// Writes straight through to the FC via `onChange`, like the palette sliders.
///
/// The track fills red from the "0%" end (leading / bottom): empty at 0%,
/// completely red at 100%. The thumb is a Liquid Glass knob.
struct CreaseOpacitySlider: View {
  var opacity: Float
  /// The crease's long direction — the slider track runs along it.
  var axis: Axis
  var onChange: (Float) -> Void

  private let trackThickness: CGFloat = 10
  private let thumbSize: CGFloat = 30
  /// Cross-axis size of the control, kept at a comfortable touch target.
  private let thickness: CGFloat = 44

  private var clamped: CGFloat { CGFloat(min(max(opacity, 0), 1)) }
  private var percent: Int { Int((min(max(opacity, 0), 1) * 100).rounded()) }

  var body: some View {
    GeometryReader { geo in
      let isHorizontal = axis == .horizontal
      let length = isHorizontal ? geo.size.width : geo.size.height
      let usable = max(length - thumbSize, 1)
      // Fill spans the whole track at 100% and nothing at 0%; any gap to the
      // thumb center stays hidden under the thumb.
      let filled = clamped * length
      // Thumb center, measured from the "0%" end, kept fully on the track.
      let thumbCenter = clamped * usable + thumbSize / 2
      let mid = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

      ZStack {
        Capsule()
          .fill(.white.opacity(0.25))
          .frame(
            width: isHorizontal ? length : trackThickness,
            height: isHorizontal ? trackThickness : length
          )
          .position(mid)

        // Clipping to the full track keeps the fill's end square against the
        // thumb while its outer end follows the track's rounded cap.
        Rectangle()
          .fill(.red)
          .frame(
            width: isHorizontal ? filled : trackThickness,
            height: isHorizontal ? trackThickness : filled
          )
          .position(
            x: isHorizontal ? filled / 2 : mid.x,
            y: isHorizontal ? mid.y : length - filled / 2
          )
          .mask {
            Capsule()
              .frame(
                width: isHorizontal ? length : trackThickness,
                height: isHorizontal ? trackThickness : length
              )
              .position(mid)
          }

        Color.clear
          .frame(width: thumbSize, height: thumbSize)
          .glassEffect(.regular.interactive(), in: Circle())
          .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
          .position(
            x: isHorizontal ? thumbCenter : mid.x,
            y: isHorizontal ? mid.y : length - thumbCenter
          )
      }
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            let along = isHorizontal ? value.location.x : length - value.location.y
            let progress = min(max(along - thumbSize / 2, 0), usable) / usable
            onChange(Float(progress))
          }
      )
    }
    .frame(
      width: axis == .vertical ? thickness : nil,
      height: axis == .horizontal ? thickness : nil
    )
    .accessibilityElement()
    .accessibilityLabel("Opacity")
    .accessibilityValue("\(percent) percent")
    .accessibilityHint("Adjusts all applied makeup effects")
    .accessibilityAdjustableAction { direction in
      switch direction {
      case .increment: onChange(min(opacity + 0.05, 1))
      case .decrement: onChange(max(opacity - 0.05, 0))
      default: break
      }
    }
  }
}
