#if canImport(UIKit) && canImport(RealityKit)
import SwiftUI
import RealityKit

/// Embed one instance per controller. Its model and camera survive view resizing/reparenting.
public struct MakeupFacePreview: View {
    @ObservedObject private var controller: MakeupFaceController
    @State private var dragOrigin: (yaw: Float, pitch: Float)?
    /// When false, hides the "Your look" label and rotation controls — e.g. for
    /// small side-by-side preview cells. Loading/failed states still show.
    private let showsChrome: Bool

    public init(controller: MakeupFaceController, showsChrome: Bool = true) {
        self.controller = controller
        self.showsChrome = showsChrome
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            FaceCanvas(controller: controller)
                .gesture(DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        if dragOrigin == nil { dragOrigin = (controller.yaw, controller.pitch) }
                        guard let origin = dragOrigin else { return }
                        controller.rotate(yaw: origin.yaw + Float(value.translation.width) * 0.006,
                                          pitch: origin.pitch + Float(value.translation.height) * 0.004)
                    }
                    .onEnded { _ in dragOrigin = nil })
                .accessibilityLabel("3D makeup portrait")
                .accessibilityValue(controller.showsOriginal ? "Original appearance" : "Edited appearance")
                .accessibilityAdjustableAction { direction in
                    controller.rotate(yaw: controller.yaw + (direction == .increment ? 0.15 : -0.15),
                                      pitch: controller.pitch)
                }

            if showsChrome && controller.status == .ready {
                VStack {
                    HStack {
                        Text(controller.showsOriginal ? "Original" : "Your look")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        if controller.isUpdating { ProgressView().accessibilityLabel("Applying makeup") }
                    }
                    Spacer()
                    HStack {
                        rotationButton("Rotate left", icon: "arrow.left", yaw: -0.15, pitch: 0)
                        rotationButton("Tilt up", icon: "arrow.up", yaw: 0, pitch: -0.08)
                        Button("Front") { controller.resetView() }
                        rotationButton("Tilt down", icon: "arrow.down", yaw: 0, pitch: 0.08)
                        rotationButton("Rotate right", icon: "arrow.right", yaw: 0.15, pitch: 0)
                    }
                    .buttonStyle(.bordered)
                    .padding(6)
                    .background(.ultraThinMaterial, in: Capsule())
                }
                .foregroundStyle(.white)
                .padding()
            }

            switch controller.status {
            case .loading:
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading portrait…")
                }
                .padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                VStack(spacing: 12) {
                    Text(message).multilineTextAlignment(.center)
                    Button("Retry loading") { Task { await controller.load() } }
                        .buttonStyle(.borderedProminent)
                }
                .padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .ready: EmptyView()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .task { await controller.load() }
    }

    private func rotationButton(_ label: String, icon: String, yaw: Float, pitch: Float) -> some View {
        Button {
            controller.rotate(yaw: controller.yaw + yaw, pitch: controller.pitch + pitch)
        } label: {
            Image(systemName: icon).frame(minWidth: 24, minHeight: 30)
        }
        .accessibilityLabel(label)
    }
}

private struct FaceCanvas: UIViewRepresentable {
    let controller: MakeupFaceController
    func makeUIView(context: Context) -> ARView { controller.view }
    func updateUIView(_ uiView: ARView, context: Context) {}
}
#endif
