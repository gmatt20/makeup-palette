import SwiftUI

struct MakeupPaletteView<Bridge: MakeupEffectBridge>: View {
  var bridge: Bridge

  @State private var editingOption: MakeupOption?
  @State private var editingCategory: MakeupCategory?

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
              appliedOption: bridge.selectedOption(for: category),
              onSelect: { option in
                bridge.select(option, for: category)
              },
              onEdit: { option in
                // Make the swatch active so color tweaks preview live on the FC.
                bridge.select(option, for: category)
                editingCategory = category
                editingOption = option
              }
            )
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
    .sheet(item: $editingOption) { option in
      SwatchColorEditor(option: option) { recolored in
        if let category = editingCategory {
          bridge.select(recolored, for: category)
        }
      }
      .presentationDetents([.medium, .large])
    }
  }
}

private struct PaletteCategoryRow: View {
  var category: MakeupCategory
  var options: [MakeupOption]
  var appliedOption: MakeupOption?
  var onSelect: (MakeupOption?) -> Void
  var onEdit: (MakeupOption) -> Void

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
            isSelected: appliedOption == nil,
            onSelect: { onSelect(nil) },
            onEdit: {}
          )

          ForEach(options) { option in
            let isSelected = appliedOption?.id == option.id
            // When selected, show the live (possibly recolored) applied color.
            let display = isSelected ? (appliedOption ?? option) : option
            PaletteSwatchButton(
              category: category,
              option: display,
              isSelected: isSelected,
              onSelect: { onSelect(option) },
              onEdit: { onEdit(display) }
            )
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
  var onSelect: () -> Void
  var onEdit: () -> Void

  @Environment(\.swatchReflection) private var reflection

  private var isEditable: Bool { option?.editableColor != nil }

  var body: some View {
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
    .swatchReflectionEffect(reflection)
    .contentShape(Rectangle())
    // Press applies immediately; hold opens the color editor.
    .onTapGesture { onSelect() }
    .onLongPressGesture(minimumDuration: 0.35) {
      if isEditable { onEdit() }
    }
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isButton)
    .accessibilityLabel("\(category.title), \(option?.name ?? "None")")
    .accessibilityValue(isSelected ? "Selected" : "Not selected")
    .accessibilityAction(named: "Edit color") {
      if isEditable { onEdit() }
    }
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
