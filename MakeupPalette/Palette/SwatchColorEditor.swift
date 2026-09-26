import SwiftUI

/// Long-press color editor for a swatch.
///
/// Shows RGB sliders over a live preview and streams every change back through
/// `onColorChange`, so the fake-camera shell updates as the user drags.
struct SwatchColorEditor: View {
  let option: MakeupOption
  var onColorChange: (MakeupOption) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var color: MakeupColor

  init(option: MakeupOption, onColorChange: @escaping (MakeupOption) -> Void) {
    self.option = option
    self.onColorChange = onColorChange
    _color = State(initialValue: option.editableColor ?? MakeupColor(rgb: 0xFFFFFF))
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 24) {
        RoundedRectangle(cornerRadius: 20)
          .fill(Color(makeupColor: color))
          .frame(height: 96)
          .overlay {
            RoundedRectangle(cornerRadius: 20)
              .strokeBorder(Color(white: 0.85), lineWidth: 1)
          }

        VStack(spacing: 16) {
          channelSlider("Red", value: $color.red, tint: .red)
          channelSlider("Green", value: $color.green, tint: .green)
          channelSlider("Blue", value: $color.blue, tint: .blue)
        }

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
    .onChange(of: color) { _, newValue in
      onColorChange(option.recolored(to: newValue))
    }
  }

  private func channelSlider(_ label: String, value: Binding<Float>, tint: Color) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(label)
          .font(PaletteTypography.label)
        Spacer()
        Text("\(Int((value.wrappedValue * 255).rounded()))")
          .font(PaletteTypography.label)
          .monospacedDigit()
          .foregroundStyle(.secondary)
      }

      Slider(
        value: Binding(
          get: { Double(value.wrappedValue) },
          set: { value.wrappedValue = Float($0) }
        ),
        in: 0...1
      )
      .tint(tint)
    }
  }
}
