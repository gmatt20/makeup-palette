import SwiftUI
import MakeupFace

/// Full-screen 2×2 grid of real 3D faces, each wearing a different option from
/// one category, with vertical up / down / cancel controls at the bottom right.
///
/// Each cell owns its own `MakeupFaceController` (isolated saved-look file so it
/// never clobbers the main session) and renders one `MakeupLook`.
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
        // Keyed by grid slot (not option) so paging re-applies the look to the
        // existing controller instead of reloading four 3D models each time.
        ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
          PreviewFaceCell(look: cell.look)
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

/// One grid cell: a real 3D face wearing `look`, with its own controller and an
/// isolated saved-look file so it never touches the main session's saved look.
private struct PreviewFaceCell: View {
  var look: MakeupLook

  @State private var controller = MakeupFaceController(
    savedLookURL: FileManager.default.temporaryDirectory
      .appendingPathComponent("preview-all-\(UUID().uuidString).json")
  )

  var body: some View {
    MakeupFacePreview(controller: controller, showsChrome: false)
      .task(id: look) {
        await controller.load()
        // load() can return early if a load was already in flight; wait for
        // readiness before applying so the look isn't dropped.
        while controller.status != .ready {
          if case .failed = controller.status { return }
          try? await Task.sleep(for: .milliseconds(60))
        }
        controller.apply(look)
      }
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
