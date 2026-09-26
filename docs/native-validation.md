# Native validation record

Face-preview component, PRD sections 8 and 10. This is the record PRD section 6 requires and
the one PRD section 10 asks to be kept separate from the Windows proof of concept.

## Bottom line

**The native component had never been compiled.** It contained at least one type error that
made `MakeupFace` unbuildable, so no acceptance criterion could have been verified. That is
fixed. Everything below still requires a Mac: this machine has no Swift toolchain, and
RealityKit/SwiftUI do not exist off Apple platforms.

Nothing in this document should be read as "FC-xx passes". A criterion passes only when a
person has seen it render in the simulator and recorded the result in section 4 below.

## 1. What was checked mechanically

Apple's documentation JSON was queried directly (`developer.apple.com/tutorials/data/...`).
These declarations are confirmed as written, not recalled:

| Symbol | Confirmed declaration |
|---|---|
| `ARView.init(frame:cameraMode:automaticallyConfigureSession:)` | `@MainActor @preconcurrency init(frame frameRect: CGRect, cameraMode: ARView.CameraMode, automaticallyConfigureSession: Bool)` |
| `AnchorEntity.init(world:)` | `@MainActor @preconcurrency convenience init(world position: SIMD3<Float>)` |
| `Entity.init(contentsOf:withName:)` | `@MainActor @preconcurrency convenience init(contentsOf url: URL, withName resourceName: String? = nil) async throws` |
| `TextureResource.generate(from:withName:options:)` | `@MainActor @preconcurrency static func generate(from cgImage: CGImage, withName resourceName: String? = nil, options: TextureResource.CreateOptions) throws -> TextureResource` |
| `TextureResource.CreateOptions` | `init(semantic: TextureResource.Semantic?, mipmapsMode: TextureResource.MipmapsMode = .allocateAndGenerateAll)`, so `.init(semantic: .color)` is valid |
| `MaterialColorParameter` | `enum` with `case color(UIColor)` and `case texture(TextureResource)` |
| `UnlitMaterial` / `init(texture:)` | `struct UnlitMaterial`, `init(texture: TextureResource)` |
| `UnlitMaterial.color` | `var color: UnlitMaterial.BaseColor`, where `BaseColor = PhysicallyBasedMaterial.BaseColor` |
| `ModelComponent.materials` | `var materials: [any Material]` |
| `PerspectiveCameraComponent.fieldOfViewInDegrees` | `var fieldOfViewInDegrees: Float` |
| `ARView.environment` | `@MainActor @preconcurrency var environment: ARView.Environment`, with `Background.color(_:)` |

**Not confirmed.** Apple's docs JSON returns 404 for these slugs, so they are unverified and
rest on API knowledge alone. A compile will settle them:

- `Entity.visualBounds(relativeTo:)` — `MakeupFaceController.swift`, used for framing
- `Entity.look(at:from:relativeTo:)` — `FaceRenderView.layoutSubviews`, used for camera placement
- `entity.components[ModelComponent.self]` subscript and `Entity.components.set(_:)`

## 2. Defects found and fixed

| # | Defect | Why it mattered | Fix |
|---|---|---|---|
| 1 | `applyTexture` built the base color as `.init(texture: .init(texture))` | `MaterialColorParameter` is an **enum**; Swift does not synthesize `init(label:)` from a case. The target could not type-check, so the package could not build. This blocked every other check. | Use the documented `UnlitMaterial(texture:)` initializer. |
| 2 | `init` force-unwrapped `Bundle.module.resourceURL!` | A stripped or mis-copied resource bundle would crash at startup instead of reporting a failure, contradicting PRD section 7. | Resources and composer became optional; `load()` reports `status = .failed` and `commit` throws. Retry still works. |
| 3 | `Entity.loadAsync` bridged through `withCheckedThrowingContinuation` | If the surrounding task was cancelled while suspended, the continuation never resumed. `status` stayed `.loading` forever and `startedLoading` stayed `true`, so the on-screen Retry button did nothing. A permanent, silent hang. | Replaced with `try await Entity(contentsOf:)`, which is cancellation-safe. Also removes the `AnyCancellable` plumbing. |
| 4 | `compose` scanned all 4,194,304 texels per treatment and recomputed luminance each time | About 71M wasted iterations per color change, single-threaded, on device, on every intensity adjustment. | Masks now cache only their nonzero texels (roughly 507k across all 17). A compose pass costs the painted area. Output is unchanged: same `Double` math, same order. |
| 5 | No runnable app target | `Package.swift` declares only libraries, so `Examples/MakeupDemo/MakeupDemoApp.swift` was not part of any build. The PRD section 8 first integration checkpoint had nothing to launch. | Added `Examples/MakeupDemo/Project.yml` (XcodeGen). Deliberately **not** an SPM executable target: `MakeupFace` compiles to an empty module on macOS because of its `#if canImport(UIKit)` guard, which would break `swift build`. |

Also noted, not fixed, because they belong to other owners or need a Mac:

- `noseContour.png` masks the whole nose bridge and tip. PRD section 4 asks for the **nose
  sides**. Needs a re-trace in `scripts/prepare_assets.py` and a re-bake.
- `README.md` links `docs/windows-acceptance.md`, which does not exist. README is being
  edited on the `feat/windows-camera-test` worktree; left alone to avoid a conflicting write.
- `face.glb` carries `baseColorFactor [0.4, 0.4, 0.4, 1]` from trimesh, so any glTF viewer
  renders the portrait at 40% brightness. The USDZ the native app loads is unaffected.

## 3. Criterion status

Legend: **Logic** = readable in code and covered by written tests. **Design** = the approach
guarantees it structurally. **Unverified** = needs a human to see it render.

| ID | Status | Basis and remaining gap |
|---|---|---|
| FC-01 | Unverified | No camera path exists: `cameraMode: .nonAR`, no ARKit import, and the generated `Info.plist` deliberately omits `NSCameraUsageDescription`. That is evidence, not proof. Confirm the model loads with recognizable source appearance. |
| FC-02 | Logic + Unverified | Drag maps to `rotate(yaw:pitch:)`, clamped to ±60° yaw and ±15° pitch; `resetView()` returns (0, 0). Rotation lives on a separate pivot entity, so it survives resize. Must watch front and three-quarter views. |
| FC-03 | Partial | 17 treatments, 17 masks, all present at 2048x2048 and all non-empty. `noseContour` is wrong (see above). Visual confirmation outstanding. |
| FC-04 | Partial | Exclusions are enforced in `prepare_assets.py`: foundation drops eyes, brows and lips; eyeshadow and concealer drop the eyeballs; lipstick drops the mouth interior. Visible in `docs/mask-regions.png`. Paired regions are baked as one symmetric polygon, so they update together by construction. Needs eyes-on confirmation that no sclera or teeth are tinted. |
| FC-05 | Design + Unverified | Makeup is composited into the model's own base-color texture rather than overlaid in screen space, so it cannot detach from the surface under rotation. Masks were baked through mesh UVs with a z-buffer visibility test plus one texel of dilation to cover seams. The seam behaviour itself is only observable while rotating. |
| FC-06 | Logic | `set` replaces the whole style; `commit` always recomposes from the immutable original `source`, never from the previous output, so repeated identical commands cannot accumulate. Order is `Treatment.allCases`, independent of edit order. **The tests exist but have never been run** - there is no Swift toolchain here. Run `swift test` on the Mac. |
| FC-07 | Logic | `clear` removes one key. `resetAll` commits an empty look. `setComparison` swaps the displayed texture and never touches `look` or the store. |
| FC-08 | Logic | `commit` saves only after a complete texture exists, then updates `look`; `LookStore.save` writes atomically. Cleared and reset states therefore persist. |
| FC-09 | Logic | `MakeupColor` and `MakeupStyle` are throwing initializers that re-validate on decode, so out-of-range and non-finite values cannot enter through JSON. `commit` mutates `look` only after compose and save both succeed; failures set `commandError` and rethrow. |
| FC-10 | This document | The Windows proof of concept is out of scope for this branch and lives in the `feat/windows-camera-test` worktree. |
| APP-01 | Unverified | App owner's layout; needs the face component to fill a closed device. |
| APP-02 | Unverified | App owner's layout. |
| APP-03 | Logic + Unverified | The controller is documented as living above fold/orientation layout, and `layoutSubviews` reframes the camera without reloading the model or resetting the pivot. Folding must not recreate the controller. |
| APP-04 | Design | One authoritative `look` on the controller. The palette reads it; it does not own a copy. |
| APP-05 | Logic | Drag is paired with an `accessibilityAdjustableAction` and four labelled rotation buttons plus Front. Swatches carry labels and a selected trait, never colour alone. |

## 4. Mac checkpoint, to be filled in

Run on the Mac, then replace this section with real results.

- [ ] `swift build` succeeds
- [ ] `swift test` passes (5 tests in `MakeupCoreTests`)
- [ ] `cd Examples/MakeupDemo && xcodegen generate`, then build for a simulator destination
- [ ] FC-01 model loads, source appearance recognizable, **no camera prompt**
- [ ] FC-02 drag to three-quarter both ways; Front restores exactly
- [ ] FC-03 every one of the 17 treatments visibly changes its own region
- [ ] FC-04 no tint on eyeballs, teeth, or mouth interior
- [ ] FC-05 rotate to ±60° yaw; look for untextured holes at UV seams
- [ ] FC-06 tap the same swatch five times; the result must be identical
- [ ] FC-07 Clear one treatment, Reset all, toggle Before/After, confirm the look survives
- [ ] FC-08 relaunch; confirm the look and any cleared treatments
- [ ] FC-09 send an out-of-range intensity; confirm the previous look stays and a failure surfaces
- [ ] Resize and reposition the component; confirm no look or angle is lost
- [ ] Measure compose duration for a full 17-treatment look and for a single-colour change
- [ ] Record the Xcode and simulator versions used

## 5. Handoff contents

| Deliverable | Location |
|---|---|
| Swift source | `Sources/MakeupCore`, `Sources/MakeupFace` |
| Prepared assets | `Sources/MakeupFace/Resources` (`Face.usdz`, base colour, 17 masks, `asset-manifest.json`) |
| Mask review sheet | `docs/mask-regions.png` |
| Treatment identifiers, categories, display names | `Treatment` in `Sources/MakeupCore/MakeupLook.swift` |
| Receiving API | `docs/API.md` |
| Example app | `Examples/MakeupDemo/MakeupDemoApp.swift` + `Project.yml` |
| Data-level asset check | `scripts/verify_assets.py` (Windows) |
| This record | `docs/native-validation.md` |
