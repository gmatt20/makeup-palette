import SwiftUI

struct MakeupPaletteView<Bridge: MakeupEffectBridge>: View {
  var bridge: Bridge

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 28) {
          Text("Makeup")
            .font(PaletteTypography.title)
            .padding(.horizontal, 20)

          ForEach(MakeupCategory.allCases) { category in
            PaletteCategoryRow(
              category: category,
              options: MakeupCatalog.options(for: category),
              selectedID: bridge.selectedOption(for: category)?.id
            ) { option in
              bridge.select(option, for: category)
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 24)
      }
      .scrollIndicators(.hidden)

      Divider()

      PaletteOpacityControl(opacity: bridge.opacity) { value in
        bridge.applyOpacity(value)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.white)
    .foregroundStyle(.black)
    .environment(\.colorScheme, .light)
  }
}

private struct PaletteCategoryRow: View {
  var category: MakeupCategory
  var options: [MakeupOption]
  var selectedID: String?
  var onSelect: (MakeupOption?) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(category.title)
        .font(PaletteTypography.section)
        .padding(.horizontal, 20)

      ScrollView(.horizontal) {
        HStack(spacing: 10) {
          PaletteSwatchButton(
            category: category,
            option: nil,
            isSelected: selectedID == nil
          ) {
            onSelect(nil)
          }

          ForEach(options) { option in
            PaletteSwatchButton(
              category: category,
              option: option,
              isSelected: selectedID == option.id
            ) {
              onSelect(option)
            }
          }
        }
        .padding(.horizontal, 20)
      }
      .scrollIndicators(.hidden)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct PaletteSwatchButton: View {
  var category: MakeupCategory
  var option: MakeupOption?
  var isSelected: Bool
  var onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      VStack(spacing: 8) {
        ZStack {
          RoundedRectangle(cornerRadius: 14)
            .fill(Color(white: 0.95))

          swatchContent
        }
        .frame(width: 66, height: 66)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
          RoundedRectangle(cornerRadius: 14)
            .strokeBorder(isSelected ? .black : Color(white: 0.8), lineWidth: isSelected ? 2 : 1)
        }

        Text(option?.name ?? "None")
          .font(PaletteTypography.label)
          .lineLimit(1)
      }
      .frame(width: 90, height: 104)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(category.title), \(option?.name ?? "None")")
    .accessibilityValue(isSelected ? "Selected" : "Not selected")
  }

  @ViewBuilder
  private var swatchContent: some View {
    if let option {
      switch option.swatch {
      case .color(let color):
        Color(makeupColor: color)
      case .png(let assetName):
        Image(assetName)
          .resizable()
          .scaledToFill()
      }
    } else {
      Text("—")
        .font(.title2)
        .foregroundStyle(.secondary)
    }
  }
}

private struct PaletteOpacityControl: View {
  var opacity: Float
  var onChange: (Float) -> Void

  var body: some View {
    VStack(spacing: 10) {
      HStack {
        Text("Opacity")
          .font(PaletteTypography.section)

        Spacer()

        Text("\(Int((opacity * 100).rounded()))%")
          .font(PaletteTypography.label)
          .monospacedDigit()
      }

      Slider(
        value: Binding(
          get: { Double(opacity) },
          set: { onChange(Float($0)) }
        ),
        in: 0...1
      ) {
        Text("Opacity")
      }
      .labelsHidden()
      .tint(Color(red: 0.71, green: 0.32, blue: 0.43))
      .accessibilityHint("Adjusts all applied makeup effects")
    }
    .padding(.horizontal, 20)
    .padding(.top, 16)
    .padding(.bottom, 20)
  }
}
