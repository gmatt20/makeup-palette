# Windows proof-of-concept acceptance

Recorded against [docs/PRD-WINDOWS.md](PRD-WINDOWS.md) / parent [PRD.md](../PRD.md) FC-10.

**Environment:** Windows desktop browser · `npm run dev` · `http://127.0.0.1:4173`  
**Date:** 2026-09-26  
**Assets:** `Sources/MakeupFace/Resources` (17 UV masks, `face.glb`, `base-color.jpg`)

| ID | Result | Notes |
|---|---|---|
| WIN-01 | Pass | Local static server; no camera permission requested. |
| WIN-02 | Pass | Prepared GLB loads with recognizable source appearance. |
| WIN-03 | Pass | Drag / arrow-key rotation; Front resets yaw/pitch without clearing makeup. |
| WIN-04 | Pass | All 17 treatment masks present and selectable; lipstick Rose (#BC395B) verified visually on the rotating model. Other treatments use the same composer path + baked masks (see `docs/mask-regions.png`). |
| WIN-05 | Pass | Texture map is UV-bound; makeup turns with the mesh. Masks exclude eyes/mouth interior per bake. |
| WIN-06 | Pass | `npm test` covers replace/idempotent commands and layer order. |
| WIN-07 | Pass | Clear treatment / Reset all / Show original exercised in the preview harness. |
| WIN-08 | Pass | Look persists in `localStorage` (`makeup-face-latest-look`); survives refresh. |
| WIN-09 | Pass | `npm test` rejects invalid intensity/color/unknown treatment without mutating prior look. |
| WIN-10 | Pass | Layout control Closed hides palette (`main.closed`); Open/Partial keep palette. Toggle does not recreate the Three.js session. |
| WIN-11 | Pass | Look JSON `version: 1` and treatment IDs match `MakeupCore.Treatment` raw values (`preview/look.mjs` ↔ `Sources/MakeupCore/MakeupLook.swift`). |
| WIN-12 | Pass | This file is the Windows record. Native RealityKit / Duo fold validation remains **pending on Mac** (parent PRD §8 checkpoint). |

## Automated checks run

```text
npm test
# ✔ replacement, isolated clear, JSON restoration, and trust-boundary validation
# ✔ masked blend preserves excluded pixels, source detail, deterministic layer order, and original
```

## Native follow-ups (not claimed here)

- Load `Face.usdz` in iPhone simulator / Bitrig; confirm UnlitMaterial texture replacement and lighting.
- One lipstick command through `MakeupFaceController` while rotating.
- Resize through app-shell fold/orientation without recreating the controller.
