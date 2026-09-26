#if canImport(UIKit) && canImport(RealityKit)
import Combine
import Foundation
import MakeupCore
import RealityKit
import UIKit

public enum FacePreviewStatus: Equatable {
    case loading
    case ready
    case failed(String)
}

public enum FacePreviewError: LocalizedError {
    case asset(String)
    case notReady
    case busy

    public var errorDescription: String? {
        switch self {
        case .asset(let message): return message
        case .notReady: return "The face is not ready. Wait for loading or retry the failed load."
        case .busy: return "A makeup change is still being applied. Try again when it finishes."
        }
    }
}

/// Keep one controller above the app's folding/orientation layout.
@MainActor
public final class MakeupFaceController: ObservableObject {
    @Published public private(set) var look = MakeupLook()
    @Published public var selectedTreatment: Treatment = .lipstick
    @Published public private(set) var status: FacePreviewStatus = .loading
    @Published public private(set) var isUpdating = false
    @Published public private(set) var showsOriginal = false
    @Published public private(set) var yaw: Float = 0
    @Published public private(set) var pitch: Float = 0
    @Published public private(set) var persistenceWarning: String?
    @Published public private(set) var commandError: String?

    public let supportedTreatments = Treatment.allCases
    let view: FaceRenderView
    private let store: LookStore
    private let composer: MakeupTextureComposer?
    private let resources: URL?
    private let pivot = Entity()
    private var model: Entity?
    private var originalTexture: TextureResource?
    private var editedTexture: TextureResource?
    private var startedLoading = false

    /// Use a distinct URL when embedding multiple independent saved looks or running tests.
    public init(savedLookURL: URL? = nil) {
        let url = savedLookURL ?? FileManager.default.urls(for: .applicationSupportDirectory,
                                                         in: .userDomainMask)[0]
            .appendingPathComponent("MakeupFace/latest-look.json")
        store = LookStore(url: url)
        // A stripped or mis-copied resource bundle must surface as a load failure, not a crash
        // and not a silently blank face (PRD section 7).
        // Folder is named "FaceAssets" (not "Resources"): a bundle subfolder
        // literally named "Resources" is a reserved bundle-layout name that
        // makes codesign reject the resource bundle on iOS.
        let bundled = Bundle.module.resourceURL?.appendingPathComponent("FaceAssets")
        resources = bundled
        composer = bundled.map(MakeupTextureComposer.init(resources:))
        view = FaceRenderView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.environment.background = .color(UIColor(red: 0.10, green: 0.085, blue: 0.10, alpha: 1))
        do { look = try store.load() }
        catch {
            persistenceWarning = "The saved look could not be restored: \(error.localizedDescription) "
                + "The original face is shown. Your saved file remains untouched until you edit or reset."
        }
    }

    /// Reported through `status` instead of trapping, so the app shell can show a retry.
    private static let missingResources = FacePreviewError.asset(
        "The face resources are missing from the app bundle. Check that the package resources were copied.")

    /// Called automatically by MakeupFacePreview. A failed load may be retried explicitly.
    public func load() async {
        guard !startedLoading else { return }
        startedLoading = true
        status = .loading
        guard let resources, let composer else {
            status = .failed(Self.missingResources.localizedDescription)
            startedLoading = false
            return
        }
        do {
            let entity = try await loadModel(resources.appendingPathComponent("Face.usdz"))
            let original = try await composer.compose(MakeupLook())
            let originalTexture = try TextureResource.generate(from: original, withName: nil,
                                                                options: .init(semantic: .color))
            let edited: TextureResource
            if look.treatments.isEmpty { edited = originalTexture }
            else {
                let image = try await composer.compose(look)
                edited = try TextureResource.generate(from: image, withName: nil,
                                                       options: .init(semantic: .color))
            }
            let bounds = entity.visualBounds(relativeTo: nil)
            let largest = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
            guard largest.isFinite, largest > 0 else {
                throw FacePreviewError.asset("The bundled model has no visible geometry.")
            }
            // Normalize once. The prepared USDZ is Y-up and faces +Z.
            let scale: Float = 2 / largest
            entity.scale *= SIMD3<Float>(repeating: scale)
            entity.position -= bounds.center * scale
            pivot.children.removeAll()
            pivot.addChild(entity)
            model = entity
            self.originalTexture = originalTexture
            editedTexture = edited
            applyTexture(showsOriginal ? originalTexture : edited)
            view.install(pivot: pivot, extents: bounds.extents * scale)
            applyOrientation()
            status = .ready
        } catch {
            status = .failed("Unable to load the face: \(error.localizedDescription)")
            startedLoading = false
        }
    }

    public func setMakeup(_ treatment: Treatment, color: MakeupColor, intensity: Double) async throws {
        let style = try MakeupStyle(color: color, intensity: intensity)
        var candidate = look
        candidate.set(treatment, style: style)
        try await commit(candidate)
    }

    public func clear(_ treatment: Treatment) async throws {
        var candidate = look
        candidate.clear(treatment)
        try await commit(candidate)
    }

    public func resetAll() async throws { try await commit(MakeupLook()) }

    /// Comparison never changes or saves makeup settings.
    public func setComparison(_ showOriginal: Bool) {
        showsOriginal = showOriginal
        if let texture = showOriginal ? originalTexture : editedTexture { applyTexture(texture) }
    }

    /// Radians relative to the front pose; invalid values are ignored.
    public func rotate(yaw: Float, pitch: Float) {
        guard yaw.isFinite, pitch.isFinite else { return }
        self.yaw = min(.pi / 3, max(-.pi / 3, yaw))
        self.pitch = min(.pi / 12, max(-.pi / 12, pitch))
        applyOrientation()
    }

    public func resetView() { rotate(yaw: 0, pitch: 0) }

    private func commit(_ candidate: MakeupLook) async throws {
        guard let composer else { throw Self.missingResources }
        guard status == .ready else { throw FacePreviewError.notReady }
        guard !isUpdating else { throw FacePreviewError.busy }
        isUpdating = true
        defer { isUpdating = false }
        do {
            let image = try await composer.compose(candidate)
            let texture = try TextureResource.generate(from: image, withName: nil,
                                                       options: .init(semantic: .color))
            // Save only after a complete texture exists. Failed commands keep the previous look visible.
            try store.save(candidate)
            editedTexture = texture
            look = candidate
            if !showsOriginal { applyTexture(texture) }
            persistenceWarning = nil
            commandError = nil
        } catch {
            commandError = error.localizedDescription
            throw error
        }
    }

    private func applyOrientation() {
        pivot.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
            * simd_quatf(angle: pitch, axis: [1, 0, 0])
    }

    private func applyTexture(_ texture: TextureResource) {
        guard let model else { return }
        // UnlitMaterial.init(texture:) is the documented base-color entry point. Building the
        // color parameter by hand is not equivalent: MaterialColorParameter is an enum whose
        // texture case already takes a TextureResource.
        let material = UnlitMaterial(texture: texture)
        func apply(to entity: Entity) {
            if var component = entity.components[ModelComponent.self] {
                component.materials = component.materials.map { _ in material }
                entity.components.set(component)
            }
            for child in entity.children { apply(to: child) }
        }
        // Replace both diffuse and emissive source behavior consistently, including comparison.
        apply(to: model)
    }

    private func loadModel(_ url: URL) async throws -> Entity {
        // Prefer the async initializer over a Combine publisher bridged through a continuation:
        // a cancelled continuation would never resume, leaving status == .loading and blocking retry.
        try await Entity(contentsOf: url)
    }
}

/// Resize changes camera framing without reloading the model or resetting the pivot.
@MainActor
final class FaceRenderView: ARView {
    private let faceCamera = PerspectiveCamera()
    private var modelExtents = SIMD3<Float>(repeating: 2)

    func install(pivot: Entity, extents: SIMD3<Float>) {
        scene.anchors.removeAll()
        let anchor = AnchorEntity(world: .zero)
        anchor.addChild(pivot)
        anchor.addChild(faceCamera)
        scene.addAnchor(anchor)
        modelExtents = extents
        faceCamera.camera.fieldOfViewInDegrees = 35
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0 else { return }
        let aspect = Float(bounds.width / bounds.height)
        let halfHeight = max(modelExtents.y / 2, modelExtents.x / (2 * aspect))
        let distance = halfHeight / tan(Float.pi * 35 / 360) * 1.12 + modelExtents.z / 2
        faceCamera.look(at: .zero, from: [0, 0, distance], relativeTo: nil)
    }
}
#endif
