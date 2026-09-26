# Face component integration — for the palette / app owner

**Owner: you (palette + app shell). The face component is a child of your app.**

You own `MakeupPaletteView`, `MakeupCatalog`, `DuoStudioLayout`, `MakeupLook`,
`MakeupCategory`, `MakeupOption`, and the finished shell. The face component owns the 3D
portrait, the UV makeup masks, compositing, the receiving API, and latest-look persistence. It
never renders palette chrome and never owns a second copy of palette state.

The component ships in this same pull request at `Packages/MakeupFace/`, already wired into
`MakeupPalette.xcodeproj`, so merging is the whole job. The face work originally lived on a
`feat/camera` branch with an unrelated git history (no common ancestor with `main`), which is why
it arrives as files rather than as a merge.

Supporting documents in this PR: [`docs/API.md`](API.md) for the full controller surface, and
[`docs/native-validation.md`](native-validation.md) for what is proven and what is not.

---

## 1. The seam you already defined

Your `MakeupEffectBridge` is exactly the right seam, and the comment on your `MakeupLook` is
already the design we need:

> A real 3D face renderer can replace the mock by consuming this value alone — no palette or
> bridge changes required.

That is what this does. Implement your protocol against the real renderer instead of the mock,
and `MakeupPaletteView` is unchanged.

## 2. What the component is

A local Swift package with two products, added to `MakeupPalette.xcodeproj`:

| Product | Contents |
|---|---|
| `MakeupCore` | `Treatment`, `MakeupColor`, `MakeupStyle`, `MakeupLook`, `LookStore`, `MakeupBlend` |
| `MakeupFace` | `MakeupFaceController`, `MakeupFacePreview`, `MakeupTextureComposer`, bundled `Face.usdz`, base colour, 17 UV masks, baked brow stamps |

Rendering is RealityKit via
`ARView(cameraMode: .nonAR, automaticallyConfigureSession: false)`.

**There is no camera.** No `NSCameraUsageDescription`, no ARKit session, no capture permission
prompt. If a camera prompt ever appears, that is a bug. Your `MockCameraFeedView` is the
placeholder it replaces; `MockCameraEffectsView` becomes unnecessary because the real renderer
already shows the effects.

## 3. Receiving API surface

```swift
@MainActor
public final class MakeupFaceController: ObservableObject {
    @Published public private(set) var look: MakeupCore.MakeupLook   // [Treatment: MakeupStyle]
    @Published public var selectedTreatment: Treatment
    @Published public private(set) var status: FacePreviewStatus     // .loading/.ready/.failed(String)
    @Published public private(set) var isUpdating: Bool
    @Published public private(set) var showsOriginal: Bool
    @Published public private(set) var yaw: Float
    @Published public private(set) var pitch: Float
    @Published public private(set) var persistenceWarning: String?
    @Published public private(set) var commandError: String?

    public let supportedTreatments: [Treatment]                      // all 17
    public init(savedLookURL: URL? = nil)                            // override for tests

    public func load() async                                        // called by the preview on appear
    public func setMakeup(_ treatment: Treatment, color: MakeupColor,
                          intensity: Double) async throws           // replaces that treatment only
    public func clear(_ treatment: Treatment) async throws
    public func resetAll() async throws
    public func setComparison(_ showOriginal: Bool)                 // never mutates or saves
    public func resetView()                                         // Front, keeps makeup
    public func rotate(yaw: Float, pitch: Float)                    // clamped, finite-checked
    public func setEyebrowStyle(_ id: String?) async throws          // baked brow stamp
}

public struct MakeupColor { public init(red: Double, green: Double, blue: Double) throws }
public struct MakeupStyle { public init(color: MakeupColor, intensity: Double) throws }
public enum Treatment: String, Codable, CaseIterable   // foundation ... mascara
```

`MakeupColor` and `MakeupStyle` validate on construction **and** on decode, so out-of-range or
non-finite values cannot enter through JSON. `setMakeup` assigns to `look` only after a texture
has been built and persisted, so a failed command leaves the previous look visible and saved.

## 4. The adapter

One new file in your app, e.g. `MakeupPalette/Face/FaceMakeupEffectBridge.swift`.

```swift
import MakeupCore
import MakeupFace
import Observation
import SwiftUI

/// Your MakeupEffectBridge, implemented against the real face component.
///
/// Your protocol is synchronous; the renderer is async and throwing. So the palette's
/// intent is recorded synchronously (that is what `look` reads back), and the render
/// update is dispatched. Failures never silently change the look: they surface through
/// `face.commandError` and `face.status`.
@MainActor
@Observable
final class FaceMakeupEffectBridge: MakeupEffectBridge {
  let face = MakeupFaceController()

  private(set) var browEffect: MakeupOption?
  private(set) var blushEffect: MakeupOption?
  private(set) var lipsEffect: MakeupOption?
  private(set) var eyebrowMask: EyebrowMask?
  private(set) var opacity: Float = 1

  func applyBrowEffect(_ option: MakeupOption) {
    guard option.category == .brow else { return }
    browEffect = option
    send(.browFill, option)
  }

  func disableBrowEffect() {
    browEffect = nil
    Task { try? await face.clear(.browFill) }
  }

  func applyBlushEffect(_ option: MakeupOption) {
    guard option.category == .blush else { return }
    blushEffect = option
    send(.blush, option)
  }

  func disableBlushEffect() {
    blushEffect = nil
    Task { try? await face.clear(.blush) }
  }

  func applyLipsEffect(_ option: MakeupOption) {
    guard option.category == .lips else { return }
    lipsEffect = option
    send(.lipstick, option)
  }

  func disableLipsEffect() {
    lipsEffect = nil
    Task { try? await face.clear(.lipstick) }
  }

  func applyEyebrowMask(_ mask: EyebrowMask) {
    eyebrowMask = mask
    // Your EyebrowMask.assetName maps onto a baked brow stamp: shape and tint stay
    // independent, which is how you already model them.
    Task { try? await face.setEyebrowStyle(mask.assetName) }
  }

  func disableEyebrowMask() {
    eyebrowMask = nil
    Task { try? await face.setEyebrowStyle(nil) }
  }

  func applyOpacity(_ value: Float) {
    guard value.isFinite else { return }
    opacity = min(max(value, 0), 1)
    // Your global opacity becomes per-region intensity on every applied region.
    for treatment in [Treatment.browFill, .blush, .lipstick] {
      guard let style = face.look.treatments[treatment] else { continue }
      Task { try? await face.setMakeup(treatment, color: style.color, intensity: Double(opacity)) }
    }
  }

  private func send(_ treatment: Treatment, _ option: MakeupOption) {
    Task {
      do {
        try await face.setMakeup(treatment,
                                color: try option.tint.coreColor(),
                                intensity: Double(opacity))
      } catch {
        // Previous rendered look stays; `face.commandError` carries the reason for your UI.
      }
    }
  }
}

private extension MakeupColor {
  /// Your MakeupColor is Float and unvalidated; MakeupCore validates and stores Double.
  func coreColor() throws -> MakeupCore.MakeupColor {
    try MakeupCore.MakeupColor(red: Double(red), green: Double(green), blue: Double(blue))
  }
}
```

## 5. The swap in `ContentView`

```swift
 import SwiftUI

 struct ContentView: View {
-  @State private var bridge = MockMakeupEffectBridge()
+  @State private var bridge = FaceMakeupEffectBridge()

   var body: some View {
     DuoStudioLayout {
       CameraPreviewView {
-        MockCameraFeedView()
+        MakeupFacePreview(controller: bridge.face)
       } effects: {
-        MockCameraEffectsView(look: bridge.look)
+        EmptyView()
       }
     } palette: {
       MakeupPaletteView(bridge: bridge)
     }
   }
 }
```

The change is already applied on this branch. The snippet above shows the essential delta only —
the real `ContentView` also carries the Preview All grid and the crease opacity slider, which are
untouched. `MakeupPaletteView` is untouched. `@State` keeps the bridge, and therefore the face
session and its persistence restore, alive across posture changes. **Never recreate the bridge on
fold.** See section 12 for what happens to the mock camera types.

## 6. Category mapping

| Your side | Face component | Notes |
|---|---|---|
| `.lips` | `Treatment.lipstick` | 17 treatments exist; only these three are wired |
| `.blush` | `Treatment.blush` | `bronzer` also available if you add a swatch |
| `.brow` tint | `Treatment.browFill` | UV mask; colour applied within the existing brow shape |
| `eyebrowMask` | `setEyebrowStyle(_:)` | Brow *shape*, independent of brow tint, as you already model it |
| `opacity` | per-treatment `intensity` | Yours is global; the component also supports per-treatment intensity |
| `disable*` | `clear(_:)` | Removes one treatment only |

`MakeupCategory.allCases` is `[.lips, .blush, .brow]`, so `MakeupEffectBridge.look` builds your
`MakeupLook` from just those three. That is fine — the component renders exactly what you send.

**If you want the rest of the station** — eyeshadow, eyeliner, contour, highlight, concealer,
foundation, lip liner, mascara, bronzer, lashes — add cases to `MakeupCategory` and swatches to
`MakeupCatalog`. The masks and the API already exist for all 17. Your catalog stays authoritative
for what the user can pick.

## 7. Two type-name collisions to be deliberate about

Both sides define `MakeupColor` and `MakeupLook`, with different shapes:

| | Your app | `MakeupCore` |
|---|---|---|
| `MakeupColor` | `Float`, mutable, unvalidated | `Double`, immutable, validated, throws |
| `MakeupLook` | effects + eyebrowMask + opacity | `[Treatment: MakeupStyle]` |

Your in-module declarations win unqualified resolution, so nothing breaks — but inside the
adapter file, qualify the component's types as `MakeupCore.MakeupColor` / `MakeupCore.MakeupLook`
as shown above. Do not try to unify the two `MakeupLook` types: yours is the palette's model and
the component's is the renderer's model. The adapter is the only place they should meet.

## 8. Persistence: the component owns it

The component persists the latest valid look to
`Application Support/MakeupFace/latest-look.json` (override with `init(savedLookURL:)`), saving
only after a texture is built. `clear` and `resetAll` persist immediately, so cleared makeup does
not return after relaunch. Comparison never writes.

Your mock persists `opacity` in `UserDefaults`. Once `FaceMakeupEffectBridge` is in place, folder
state belongs to the component — do not add a second store for the same values, or restore will
disagree with `face.look`. Read `face.look` after launch and after every command.

## 9. Posture

The component is resize-safe and never reloads on layout change. Put it wherever your layout
assigns the face pane.

| Posture | Face | Palette |
|---|---|---|
| Closed (outer display) | Fills the outer display; still rotatable | Hidden |
| Open / partial, portrait | Top | Bottom |
| Open / partial, landscape | Left | Right |

Folding, unfolding, and orientation changes must preserve the applied look, yaw/pitch, and the
selected treatment without recreating the session. Your `DuoStudioLayout` owns the real hinge
signals; validate them on the target Bitrig/Xcode version and do not infer closed from aspect
ratio alone.

## 10. Verification status — read before relying on this

**The component's Swift has never been compiled on an Apple toolchain.** It was written and
audited on Windows. Every acceptance criterion in the PRD is currently Unverified, Logic-only, or
Partial; the honest breakdown and a Mac checklist are in
[`docs/native-validation.md`](native-validation.md).

One defect was already found this way and fixed: the base-colour material was constructed with an
invalid `MaterialColorParameter` initializer, which meant the target could not type-check at all.

Known open items:

- `noseContour` masks the whole nose rather than the sides
- six feathered masks have compressed dynamic range (peak 129–194 of 255), so low intensity
  settings do very little for `cupidBowHighlight`, `jawContour`, `cheekContour`,
  `cheekHighlight`, `bronzer`, and `templeContour`
- `Entity.visualBounds(relativeTo:)` and `Entity.look(at:from:relativeTo:)` were not confirmed
  against Apple's documentation and need a compile to settle

Expect to build and iterate. Run `swift build` and `swift test` first, then work the checklist,
and report rotation smoothness, texture appearance, and compose latency on the real simulator —
none of that is measurable on Windows.

## 11. Suggested order of work

1. Merge, then build. The package is wired and `ContentView` is already swapped.
2. Confirm the portrait loads and the original appearance looks right.
3. Exercise lips, blush, and brows with your existing palette; check rotation and Front.
4. Work the [native checklist](native-validation.md); report what fails.
5. Then, if useful, widen `MakeupCategory` to expose the other treatments.

## 12. What changed in the project, and how to undo it

`MakeupPalette.xcodeproj/project.pbxproj` gained 41 lines and changed nothing that already
existed:

- one `XCLocalSwiftPackageReference` pointing at `Packages/MakeupFace`
- `MakeupCore` and `MakeupFace` product dependencies on the `MakeupPalette` target
- both linked in the Frameworks build phase
- `MakeupPalette/Face/FaceMakeupEffectBridge.swift` added to the target and to a new `Face` group

If the project file misbehaves, revert that single file and add the package by hand instead:
File > Add Package Dependencies > Add Local, then choose `Packages/MakeupFace`. The pbxproj change
is isolated in its own commit for exactly that reason.

`Face.usdz`, `base-color.jpg`, the 17 masks, and the manifest are bundled — about 11.9 MB. The
Windows-only `face.glb` derivative is deliberately excluded, keeping 17.7 MB out of the app.

The mock camera still compiles and none of it was deleted. `MockCameraFeedView` and
`MockMakeupEffectBridge` are no longer referenced from `ContentView`, but `MockCameraEffectsView`
still is: **the Preview All 2×2 grid renders `MockCameraEffectsView(look:)` per cell**, so those
cells show text capsules rather than four rendered faces. Wiring Preview All to the real renderer
would need one `MakeupFaceController` per cell and each composite is CPU work, so that is a
deliberate decision rather than something to switch on quietly.

`MockMakeupEffectBridge` stays useful as the 2D fallback and for palette design iteration without
starting RealityKit.
