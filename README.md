# Makeup Face Preview

Face-preview component for the iPhone Duo makeup station (see [PRD.md](PRD.md)). This repository owns the 3D portrait, UV makeup masks, look state, persistence, and the receiving Swift API. The app teammate owns the finished palette shell and Duo fold/orientation layout.

## What is included

| Path | Role |
|---|---|
| `Sources/MakeupCore` | Treatment IDs, look JSON, validation, blend math, `LookStore` |
| `Sources/MakeupFace` | RealityKit preview, texture composer, drag rotation, Front reset |
| `Examples/MakeupDemo` | Integration harness: Duo posture picker (Closed / Open / Tabletop) + temporary palette |
| `Sources/MakeupFace/Resources` | Prepared `Face.usdz`, `face.glb`, base color, UV masks |
| `preview/` | Windows browser proof of concept (Three.js; not RealityKit) |
| `scripts/prepare_assets.py` | Regenerates working assets from the supplied source USDZ |
| `docs/API.md` | Receiving Swift API for the app teammate |
| `docs/handoff.md` | App/palette integration handoff (Duo / Bitrig) |
| `docs/windows-acceptance.md` | Windows PoC acceptance record |

## Windows preview (no Mac required)

```bash
npm install
npm test
npm run dev
```

Open `http://127.0.0.1:4173`. Layout open/closed is a compact stand-in for Duo fold; makeup, angle, and selection survive toggle and refresh (`localStorage`).

Prototype-only code lives under `preview/`. Shared contracts with native are treatment IDs, look JSON `version: 1`, masks, and blend behavior—not the renderer.

## Native Swift integration

1. Add the local Swift package (`MakeupCore` + `MakeupFace`) to the Xcode/Bitrig app.
2. Keep **one** `MakeupFaceController` above fold/orientation layout so resize does not recreate the session.
3. Embed `MakeupFacePreview(controller:)` and call the API in [docs/API.md](docs/API.md).
4. Do not keep a second copy of makeup state in the palette; read `controller.look` after restore and after each command.
5. Copy `Examples/MakeupDemo/MakeupDemoApp.swift` patterns for controls; replace with the finished palette UI.

Native RealityKit validation still requires a Mac/simulator checkpoint (PRD §8). Windows green does not prove materials or Duo hinge behavior.

## Regenerate assets

```bash
uv run --no-project --with usd-core --with pillow --with numpy --with numba --with trimesh \
  python scripts/prepare_assets.py /path/to/Sasha_Grey_Portrait.usdz
```

Writes into `Sources/MakeupFace/Resources/` and `docs/mask-regions.png`. Never overwrite the original USDZ.

## Tests

- Swift: `swift test` (MakeupCore validation and persistence) on a machine with Swift tooling.
- Browser: `npm test` (look replace/clear, invalid input, blend order).
