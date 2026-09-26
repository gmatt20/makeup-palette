import SwiftUI

/// Long-press color editor for a swatch.
///
/// A circular hue/saturation wheel plus a brightness slider. Every change
/// streams back through `onColorChange`, so the FC updates as the user drags.
struct SwatchColorEditor: View {
  let option: MakeupOption
  var onColorChange: (MakeupOption) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var hue: Float
  @State private var saturation: Float
  @State private var brightness: Float

  init(option: MakeupOption, onColorChange: @escaping (MakeupOption) -> Void) {
    self.option = option
    self.onColorChange = onColorChange
    let hsb = (option.editableColor ?? MakeupColor(rgb: 0xFFFFFF)).hsb
    _hue = State(initialValue: hsb.hue)
    _saturation = State(initialValue: hsb.saturation)
    _brightness = State(initialValue: hsb.brightness)
  }

  private var currentColor: MakeupColor {
    MakeupColor(hue: hue, saturation: saturation, brightness: brightness)
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 22) {
        RoundedRectangle(cornerRadius: 18)
          .fill(Color(makeupColor: currentColor))
          .frame(height: 64)
          .overlay {
            RoundedRectangle(cornerRadius: 18)
              .strokeBorder(Color(white: 0.85), lineWidth: 1)
          }

        ColorWheel(hue: $hue, saturation: $saturation, brightness: brightness)
          .frame(width: 240, height: 240)

        brightnessSlider

        Spacer(minLength: 0)
      }
      .padding(24)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(.white)
      .navigationTitle(option.name)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
    .environment(\.colorScheme, .light)
    .onChange(of: currentColor) { _, newValue in
      onColorChange(option.recolored(to: newValue))
    }
  }

  private var brightnessSlider: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Brightness")
        .font(PaletteTypography.label)

      Slider(
        value: Binding(
          get: { Double(brightness) },
          set: { brightness = Float($0) }
        ),
        in: 0...1
      )
      .tint(Color(makeupColor: MakeupColor(hue: hue, saturation: saturation, brightness: 1)))
    }
  }
}

/// A hue (angle) + saturation (radius) color wheel. Brightness dims the disc
/// so the thumb reads true against the picked value.
private struct ColorWheel: View {
  @Binding var hue: Float
  @Binding var saturation: Float
  var brightness: Float

  var body: some View {
    GeometryReader { geo in
      let size = min(geo.size.width, geo.size.height)
      let radius = size / 2

      ZStack {
        Circle()
          .fill(
            AngularGradient(
              gradient: Gradient(colors: hueSpectrum),
              center: .center
            )
          )

        Circle()
          .fill(
            RadialGradient(
              colors: [.white, .white.opacity(0)],
              center: .center,
              startRadius: 0,
              endRadius: radius
            )
          )

        Circle()
          .fill(.black.opacity(1 - Double(brightness)))

        thumb(radius: radius)
      }
      .frame(width: size, height: size)
      .contentShape(Circle())
      .gesture(drag(radius: radius, center: CGPoint(x: size / 2, y: size / 2)))
    }
  }

  private var hueSpectrum: [Color] {
    stride(from: 0.0, through: 1.0, by: 1.0 / 12).map {
      Color(hue: $0, saturation: 1, brightness: 1)
    }
  }

  private func thumb(radius: CGFloat) -> some View {
    let angle = Double(hue) * 2 * .pi
    let r = Double(saturation) * Double(radius)
    return Circle()
      .fill(Color(makeupColor: MakeupColor(hue: hue, saturation: saturation, brightness: brightness)))
      .frame(width: 28, height: 28)
      .overlay { Circle().strokeBorder(.white, lineWidth: 3) }
      .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
      .offset(x: CGFloat(cos(angle)) * CGFloat(r), y: CGFloat(sin(angle)) * CGFloat(r))
  }

  private func drag(radius: CGFloat, center: CGPoint) -> some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { value in
        let dx = value.location.x - center.x
        let dy = value.location.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        saturation = Float(min(distance / radius, 1))
        var angle = atan2(dy, dx)
        if angle < 0 { angle += 2 * .pi }
        hue = Float(angle / (2 * .pi))
      }
  }
}
