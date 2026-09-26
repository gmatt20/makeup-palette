import SwiftUI

struct MakeupPaletteView<Bridge: MakeupEffectBridge>: View {
  var bridge: Bridge
  /// Asks the layout to open the 2×2 "Preview All" grid for a category.
  var onPreviewAll: (MakeupCategory) -> Void

  @State private var editingOption: MakeupOption?
  @State private var editingCategory: MakeupCategory?

  // Chosen by the layout from fold + orientation so opacity hugs the hinge.
  @Environment(\.opacityPlacement) private var opacityPlacement

  var body: some View {
    placedContent
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

  @ViewBuilder
  private var placedContent: some View {
    switch opacityPlacement {
    case .leading:
      HStack(spacing: 0) {
        verticalOpacity
        makeupList
      }
    case .top:
      VStack(spacing: 0) {
        horizontalOpacity
          .padding(.horizontal, 20)
          .padding(.top, 14)
          .padding(.bottom, 6)
        makeupList
      }
    case .bottom:
      VStack(spacing: 0) {
        makeupList
        horizontalOpacity
          .padding(.horizontal, 20)
          .padding(.top, 6)
          .padding(.bottom, 16)
      }
    case .crease:
      makeupList
    }
  }

  private var verticalOpacity: some View {
    VerticalOpacitySlider(opacity: bridge.opacity) { bridge.applyOpacity($0) }
      .frame(width: 58)
      .padding(.leading, 8)
      .padding(.vertical, 18)
  }

  private var horizontalOpacity: some View {
    HorizontalOpacitySlider(opacity: bridge.opacity) { bridge.applyOpacity($0) }
  }

  private var makeupList: some View {
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
            },
            onPreviewAll: { onPreviewAll(category) }
          )
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 24)
    }
    .scrollIndicators(.hidden)
  }
}

private struct PaletteCategoryRow: View {
  var category: MakeupCategory
  var options: [MakeupOption]
  var appliedOption: MakeupOption?
  var onSelect: (MakeupOption?) -> Void
  var onEdit: (MakeupOption) -> Void
  var onPreviewAll: () -> Void

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

          PreviewAllButton(category: category, action: onPreviewAll)

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

/// Tile between "None" and the swatches that opens the 2×2 Preview All grid,
/// trying four of the row's options on at once.
private struct PreviewAllButton: View {
  var category: MakeupCategory
  var action: () -> Void

  @Environment(\.swatchReflection) private var reflection

  var body: some View {
    Button(action: action) {
      VStack(spacing: 8) {
        Image(systemName: "square.grid.2x2")
          .font(.title2)
          .frame(width: 66, height: 66)
          .background(Color(white: 0.95), in: RoundedRectangle(cornerRadius: 14))
          .overlay {
            RoundedRectangle(cornerRadius: 14)
              .strokeBorder(Color(white: 0.8), lineWidth: 1)
          }

        Text("Preview All")
          .font(PaletteTypography.label)
          .lineLimit(1)
      }
      .frame(width: 90, height: 104)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .swatchReflectionEffect(reflection)
    .accessibilityLabel("\(category.title), Preview All")
    .accessibilityHint("Shows four \(category.title.lowercased()) options side by side")
  }
}

/// Horizontal opacity slider for the top (portrait, at the crease) and bottom
/// (fully open) placements. Writes straight through to the FC via `applyOpacity`.
private struct HorizontalOpacitySlider: View {
  var opacity: Float
  var onChange: (Float) -> Void

  var body: some View {
    HStack(spacing: 12) {
      Text("Opacity")
        .font(PaletteTypography.section)

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

      Text("\(Int((min(max(opacity, 0), 1) * 100).rounded()))%")
        .font(PaletteTypography.label)
        .monospacedDigit()
        .frame(width: 44, alignment: .trailing)
    }
    .accessibilityElement(children: .combine)
    .accessibilityHint("Adjusts all applied makeup effects")
  }
}

/// Vertical opacity slider pinned to the palette's left edge, sitting at the
/// hinge when the device is open in landscape at ~90°. Writes straight through
/// to the FC via `applyOpacity` and applies to every active effect.
private struct VerticalOpacitySlider: View {
  var opacity: Float
  var onChange: (Float) -> Void

  private let accent = Color(red: 0.71, green: 0.32, blue: 0.43)
  private let trackWidth: CGFloat = 8
  private let thumbSize: CGFloat = 26

  private var clamped: CGFloat { CGFloat(min(max(opacity, 0), 1)) }
  private var percent: Int { Int((min(max(opacity, 0), 1) * 100).rounded()) }

  var body: some View {
    VStack(spacing: 10) {
      Text("\(percent)%")
        .font(PaletteTypography.label)
        .monospacedDigit()

      GeometryReader { geo in
        let height = geo.size.height
        let usable = max(height - thumbSize, 1)
        let thumbY = (1 - clamped) * usable + thumbSize / 2

        ZStack {
          Capsule()
            .fill(Color(white: 0.9))
            .frame(width: trackWidth)

          VStack(spacing: 0) {
            Spacer(minLength: 0)
            Capsule()
              .fill(accent)
              .frame(width: trackWidth, height: clamped * usable + thumbSize / 2)
          }

          Circle()
            .fill(.white)
            .frame(width: thumbSize, height: thumbSize)
            .overlay { Circle().strokeBorder(accent, lineWidth: 2) }
            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            .position(x: geo.size.width / 2, y: thumbY)
        }
        .frame(width: geo.size.width, height: height)
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 0)
            .onChanged { value in
              let y = min(max(value.location.y - thumbSize / 2, 0), usable)
              onChange(Float(1 - (y / usable)))
            }
        )
      }
      .frame(maxWidth: .infinity)

      Text("Opacity")
        .font(.custom("HelveticaNeue-Bold", size: 12))
        .fixedSize()
        .rotationEffect(.degrees(-90))
        .frame(height: 64)
    }
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
