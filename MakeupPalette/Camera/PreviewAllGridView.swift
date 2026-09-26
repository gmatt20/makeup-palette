import SwiftUI

/// Full-screen 2×2 grid of fake cameras, each wearing a different option from
/// one category, with vertical up / down / cancel controls at the bottom right.
///
/// Consumes only `MakeupLook`s, like the single-camera FC, so swapping in the
/// real face renderer here is the same drop-in as `MockCameraEffectsView`.
struct PreviewAllGridView: View {
  var session: PreviewAllSession
  var baseLook: MakeupLook
  var onPrevious: () -> Void
  var onNext: () -> Void
  var onCancel: () -> Void

  private let columns = [
    GridItem(.flexible(), spacing: 2),
    GridItem(.flexible(), spacing: 2)
  ]

  var body: some View {
    let cells = session.looks(over: baseLook)

    GeometryReader { geometry in
      // Two rows split the full height; the 2pt gutter is subtracted once.
      let rowHeight = (geometry.size.height - 2) / 2

      LazyVGrid(columns: columns, spacing: 2) {
        ForEach(cells, id: \.option.id) { cell in
          CameraPreviewView {
            MockCameraFeedView()
          } effects: {
            MockCameraEffectsView(look: cell.look)
          }
          .frame(height: rowHeight)
          .accessibilityElement(children: .combine)
          .accessibilityLabel("\(session.category.title) preview, \(cell.option.name)")
        }
      }
    }
    .background(.black)
    .ignoresSafeArea()
    .overlay(alignment: .bottomTrailing) {
      PreviewAllControls(
        session: session,
        onPrevious: onPrevious,
        onNext: onNext,
        onCancel: onCancel
      )
      .padding(.trailing, 12)
      .padding(.bottom, 8)
      // Hug the physical side in landscape instead of sitting inside the
      // (wide) sensor-housing safe-area inset; the bottom inset still keeps
      // the column clear of the home indicator and rounded corner.
      .ignoresSafeArea(.container, edges: .horizontal)
    }
    .sensoryFeedback(.selection, trigger: session.visibleOptions.map(\.id))
  }
}

private struct PreviewAllControls: View {
  var session: PreviewAllSession
  var onPrevious: () -> Void
  var onNext: () -> Void
  var onCancel: () -> Void

  private var canCycle: Bool { session.pageCount > 1 }

  var body: some View {
    VStack(spacing: 8) {
      Button("Previous Variations", systemImage: "chevron.up", action: onPrevious)
        .disabled(!canCycle)

      Button("Next Variations", systemImage: "chevron.down", action: onNext)
        .disabled(!canCycle)

      Button("Close Preview All", systemImage: "xmark", action: onCancel)
    }
    .labelStyle(.iconOnly)
    .font(.title3.weight(.semibold))
    .buttonStyle(.glass)
    .buttonBorderShape(.circle)
    .controlSize(.large)
    .environment(\.colorScheme, .dark)
  }
}
