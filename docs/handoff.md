# MakeupFace handoff — app / palette owner

Integration guide for embedding **MakeupFace** in the iPhone Duo / Bitrig shell. Face-preview delivery is complete for handoff; native RealityKit / Duo fold validation is still pending on Mac (PRD §8).

Ownership: [PRD.md](../PRD.md) §6. Full API: [docs/API.md](API.md). Windows record: [docs/windows-acceptance.md](windows-acceptance.md).

---

## 1. What is delivered

| Package / path | Role |
|---|---|
| **MakeupCore** | Stable `Treatment` IDs, look JSON (`version: 1`), validation, blend math, `LookStore` |
| **MakeupFace** | RealityKit preview, UV texture composer, drag rotation, Front reset, `MakeupFaceController` |
| **Resources** (bundled with MakeupFace) | `Face.usdz`, `face.glb`, `base-color.jpg`, 17 UV masks, asset manifest |
| **Examples/MakeupDemo** | Integration harness with temporary palette controls — replace with finished UI |
| **preview/** | Windows browser PoC (Three.js). Shared contracts only: treatment IDs, look JSON, masks, blend — not the renderer |

Add the local Swift package (`MakeupCore` + `MakeupFace`) to the Xcode/Bitrig app (`Package.swift` products).

---

## 2. How to embed

Keep **one** `MakeupFaceController` above fold/orientation layout. Embed the preview; drive makeup through the controller.

```swift
@StateObject private var face = MakeupFaceController()

// In layout (resize freely; do not recreate `face`):
MakeupFacePreview(controller: face)
```

`MakeupFacePreview` calls `load()` on appear. Call `setMakeup` / `clear` / `resetAll` / `setComparison` / `resetView` as documented in [API.md](API.md). Copy control patterns from `Examples/MakeupDemo/MakeupDemoApp.swift`; swap in the finished palette.

Read `controller.look` after restore and after each command so palette swatches reflect authoritative state.

---

## 3. Duo layout contract

| Device state | Face | Palette |
|---|---|---|
| Fully closed | Fills available display; remains rotatable | Hidden |
| Open / partial, portrait | Top | Bottom |
| Open / partial, landscape | Left | Right |

**Must preserve across fold and orientation changes:** applied look, yaw/pitch, `selectedTreatment` (and intensity UX you own). **Do not** recreate `MakeupFaceController` or reload the original look on layout change. Resize `MakeupFacePreview` only.

Yaw/pitch are transient (survive layout, not required across app relaunch). Makeup settings persist via Face (below).

**Posture proposals** from `preview/duo.mjs` (`closed` / `open` / `tabletop`, hinge axis, pane sizing) are suggestions for the shell owner. Validate real fold/hinge signals on the target Xcode/Bitrig version — do not infer open/closed from aspect ratio alone.

---

## 4. Assets

Bundled under `Sources/MakeupFace/Resources/`:

- Working model: `Face.usdz` (native) / `face.glb` (Windows preview)
- Base color + 17 UV treatment masks
- Asset manifest (treatment → mask mapping)

Data-level verification checklist and known mask notes: [asset-verification.md](asset-verification.md). Visual region map: [mask-regions.png](mask-regions.png).

App owner: confirm Resources are in the app bundle. Face owner prepared the assets; Apple-renderer visual QA is still part of the Mac checkpoint.

---

## 5. Persistence ownership

**Face owns** latest-look persistence (`Application Support/MakeupFace/latest-look.json` unless `savedLookURL` is passed). Clear / Reset all write after a successful compose. Comparison never writes.

**Palette must not** keep a second copy of makeup state. Use `controller.look` and the documented commands only (APP-04).

---

## 6. Validated vs pending

### Validated on Windows ([windows-acceptance.md](windows-acceptance.md))

- Local preview, no camera; GLB + all 17 masks; UV-bound makeup through rotation
- Look replace / clear / reset / Before-After; invalid inputs leave prior look
- Look JSON + treatment IDs align with MakeupCore; layout toggle does not recreate the session
- `npm test` green for blend/trust-boundary checks
- Asset data check via `scripts/verify_assets.py` (see asset-verification.md)

### Still pending on Mac / simulator (PRD §8 checkpoint)

1. Load `Face.usdz` in the iPhone simulator / Bitrig target — textures, lighting, orientation, framing
2. Drag rotation and Front reset on RealityKit
3. One lipstick command through `MakeupFaceController` on the rotating model
4. Resize/reposition through the app shell without losing look or angle
5. Real Duo fold/orientation signals (app owner validates hinge APIs)

Windows green does **not** prove UnlitMaterial / materials or Duo hinge behavior.

---

## 7. Out of scope for the face owner

- Finished palette UI and category chrome (demo harness is temporary)
- App shell, fold/orientation layout, and real hinge APIs
- Live camera / ARKit face tracking
- Stretch: freehand paint, realistic finishes, named look gallery, left/right independent makeup

Face owner participates in the native integration checkpoint; app owner runs embed + whole-app acceptance (PRD §10 APP-*).
