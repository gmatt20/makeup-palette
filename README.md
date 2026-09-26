# makeup-palette

Native iPhone Duo face preview (see [PRD.md](PRD.md)) plus a **Windows local MVP** (see [PRD-WINDOWS.md](PRD-WINDOWS.md)).

## Windows MVP (this machine)

```bash
npm install
npm test
npm run dev
```

Open http://127.0.0.1:4173 — 3D face, full treatment palette, compact open/closed, look persistence in `localStorage`.

Prepared assets live under `Sources/MakeupFace/Resources/` (`face.glb`, `base-color.jpg`, `masks/`). Regenerate from the source USDZ:

```bash
uv run --no-project --with usd-core --with pillow --with numpy --with numba --with trimesh python scripts/prepare_assets.py PATH/TO/SOURCE.usdz
```
