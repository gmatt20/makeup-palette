import SwiftUI
import MakeupCore
import MakeupFace

@main
struct MakeupDemoApp: App {
    /// Owns the face session for the whole shell. Posture changes must never recreate this.
    @StateObject private var face = MakeupFaceController()

    var body: some Scene {
        WindowGroup { DemoView(face: face) }
    }
}

/// Stand-in for the app teammate's real fold signals. Labels match preview/duo.mjs POSTURES.
private enum DuoPosture: String, CaseIterable, Identifiable {
    case closed
    case open
    case tabletop

    var id: String { rawValue }

    var label: String {
        switch self {
        case .closed: return "Closed — outer display"
        case .open: return "Open — inner display"
        case .tabletop: return "Tabletop — inner display, half-folded"
        }
    }

    var detail: String {
        switch self {
        case .closed:
            return "One-handed portrait. Outer display only; the inner panel does not exist in this posture."
        case .open:
            return "Two-handed landscape. The hinge splits the face preview from the palette."
        case .tabletop:
            return "Stands on a surface. The raised half shows the face; the flat half holds the palette."
        }
    }

    var shortLabel: String {
        switch self {
        case .closed: return "Closed"
        case .open: return "Open"
        case .tabletop: return "Tabletop"
        }
    }
}

/// Integration controls only. The app teammate supplies real fold signals and the finished palette.
private struct DemoView: View {
    @ObservedObject var face: MakeupFaceController
    @State private var posture: DuoPosture = .open

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Makeup Lab").font(.headline)
                    Text("Integration harness · manual folding")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(posture.detail)
                        .font(.caption2).foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                Spacer(minLength: 8)
                Picker("Posture", selection: $posture) {
                    ForEach(DuoPosture.allCases) { option in
                        Text(option.shortLabel).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)
                .accessibilityLabel("Duo posture")
                .accessibilityValue(Text(posture.label))
            }
            GeometryReader { geometry in
                postureLayout(size: geometry.size)
            }
        }
        .padding()
    }

    @ViewBuilder
    private func postureLayout(size: CGSize) -> some View {
        switch posture {
        case .closed:
            // Outer display only: face fills; palette does not exist in this posture.
            MakeupFacePreview(controller: face)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .open:
            // Landscape-style vertical hinge split; tall portrait falls back to stacked.
            let landscape = size.width > size.height
            if landscape {
                HStack(spacing: 12) {
                    MakeupFacePreview(controller: face)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    TestPalette(face: face)
                        .frame(width: min(340, size.width * 0.42))
                        .frame(maxHeight: .infinity)
                }
            } else {
                VStack(spacing: 12) {
                    MakeupFacePreview(controller: face)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    TestPalette(face: face)
                        .frame(height: min(330, size.height * 0.46))
                }
            }
        case .tabletop:
            // Horizontal hinge flex: face on the raised half, palette on the flat half.
            VStack(spacing: 12) {
                MakeupFacePreview(controller: face)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                TestPalette(face: face)
                    .frame(height: min(330, size.height * 0.46))
            }
        }
    }
}

private struct TestPalette: View {
    @ObservedObject var face: MakeupFaceController
    @State private var intensity = 0.75
    @State private var errorMessage: String?
    private let swatches: [(name: String, rgb: [Double])] = [
        ("Rose", [0.78, 0.22, 0.35]), ("Berry", [0.43, 0.08, 0.23]),
        ("Coral", [0.95, 0.36, 0.22]), ("Plum", [0.38, 0.16, 0.43]),
        ("Cocoa", [0.34, 0.20, 0.14]), ("Sand", [0.78, 0.58, 0.39]),
        ("Pearl", [1, 0.92, 0.78]), ("Ink", [0.06, 0.04, 0.06])
    ]

    private var categories: [String] {
        Treatment.allCases.reduce(into: []) { if !$0.contains($1.category) { $0.append($1.category) } }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let warning = face.persistenceWarning {
                    Text(warning).font(.caption).foregroundStyle(.orange)
                }
                Picker("Category", selection: Binding(
                    get: { face.selectedTreatment.category },
                    set: { category in
                        if let treatment = Treatment.allCases.first(where: { $0.category == category }) {
                            face.selectedTreatment = treatment
                        }
                    })) {
                    ForEach(categories, id: \.self) { Text($0).tag($0) }
                }
                Picker("Treatment", selection: $face.selectedTreatment) {
                    ForEach(Treatment.allCases.filter { $0.category == face.selectedTreatment.category }, id: \.self) {
                        Text($0.displayName).tag($0)
                    }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                    ForEach(swatches.indices, id: \.self) { index in
                        let swatch = swatches[index]
                        Button {
                            run {
                                let color = try MakeupColor(red: swatch.rgb[0], green: swatch.rgb[1], blue: swatch.rgb[2])
                                try await face.setMakeup(face.selectedTreatment, color: color, intensity: intensity)
                            }
                        } label: {
                            VStack(spacing: 3) {
                                Circle().fill(Color(red: swatch.rgb[0], green: swatch.rgb[1], blue: swatch.rgb[2]))
                                    .frame(width: 38, height: 38)
                                    .overlay { if isSelected(swatch.rgb) { Image(systemName: "checkmark").foregroundStyle(.white).shadow(radius: 2) } }
                                Text(swatch.name).font(.caption2)
                            }.frame(maxWidth: .infinity, minHeight: 54)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Apply \(swatch.name) to \(face.selectedTreatment.displayName)")
                        .accessibilityAddTraits(isSelected(swatch.rgb) ? .isSelected : [])
                    }
                }
                HStack {
                    Text("Intensity")
                    Spacer()
                    Text(intensity, format: .percent.precision(.fractionLength(0))).monospacedDigit()
                }.font(.caption)
                Slider(value: $intensity, in: 0...1, onEditingChanged: { editing in
                    if !editing { applyIntensity() }
                })
                .accessibilityLabel("Makeup intensity")
                .accessibilityValue(Text(intensity, format: .percent.precision(.fractionLength(0))))
                .accessibilityAdjustableAction { direction in
                    intensity = min(1, max(0, intensity + (direction == .increment ? 0.1 : -0.1)))
                    applyIntensity()
                }
                Toggle("Show original", isOn: Binding(get: { face.showsOriginal }, set: { face.setComparison($0) }))
                HStack {
                    Button("Clear treatment") { run { try await face.clear(face.selectedTreatment) } }
                    Spacer()
                    Button("Reset all", role: .destructive) { run { try await face.resetAll() } }
                }.buttonStyle(.bordered)
                if face.isUpdating { Text("Applying and saving…").font(.caption) }
            }
            .padding()
            .disabled(face.status != .ready || face.isUpdating)
        }
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .onAppear { syncIntensity() }
        .onChange(of: face.selectedTreatment) { _, _ in syncIntensity() }
        .onChange(of: face.look) { _, _ in syncIntensity() }
        .alert("Makeup change failed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func isSelected(_ rgb: [Double]) -> Bool {
        guard let color = face.look.treatments[face.selectedTreatment]?.color else { return false }
        return color.red == rgb[0] && color.green == rgb[1] && color.blue == rgb[2]
    }

    private func syncIntensity() {
        intensity = face.look.treatments[face.selectedTreatment]?.intensity ?? 0.75
    }

    private func applyIntensity() {
        guard let style = face.look.treatments[face.selectedTreatment] else { return }
        run { try await face.setMakeup(face.selectedTreatment, color: style.color, intensity: intensity) }
    }

    private func run(_ operation: @escaping @MainActor () async throws -> Void) {
        Task { @MainActor in
            do { try await operation() }
            catch { errorMessage = error.localizedDescription; syncIntensity() }
        }
    }
}
