# MakeupPalette — brag plan

## What it is (one line)
A SwiftUI makeup try-on app built for the iPhone Duo — the palette folds with the phone.

## Angle
Not "another makeup app." A **foldable-first** makeup studio: swatches mirror across the crease, the opacity slider lives in the fold, and Preview All lets four looks share the screen. The whole story is *the hinge is part of the design*.

## Audience
iOS designers/devs who saw the foldable Duo announcement and are asking "what would you even *do* with the fold?"

## Hook (first 2 seconds)
A single Classic Red swatch (#C41E3A) blooms out of black — the video's only bright color until the palette arrives.

## Highlights (2–3)
1. **The palette panel** — real Helvetica Neue type, real catalog colors (Lips / Blush / Brows), the same swatch tiles that ship in the app.
2. **The fold is a first-class layout region** — camera left, palette right, the opacity slider sits **in the crease**. Swatches mirror across the hinge.
3. **Preview All 2×2** — try four shades side by side without committing.

## Punchline / outro
Wordmark returns. Tagline: **Foldable-first.**

## Tone
`polished`: serious, elegant, restrained. Long holds, soft fades, generous whitespace. No FOMO, no exclamation marks. The product's own quiet confidence.

## Visual identity (pulled from source)
- **Palette background:** `#FFFFFF`
- **Text:** `#000000`
- **Muted:** `#F2F2F2` swatch tile, `#CCCCCC` swatch border
- **Accent (opacity slider fill):** `rgb(0.71, 0.32, 0.43)` — a rose/berry
- **Premium gold:** `rgb(0.83, 0.62, 0.16)`
- **Type:** Helvetica Neue — Medium 26pt title, Bold 19pt section, Regular 14pt label
- **Radius:** 14pt on every swatch tile, 66×66 tile, 90×104 cell

## Real copy used
- Wordmark: **MakeupPalette**
- Section headings: **Lips**, **Blush**, **Brows**
- Swatch names: Classic Red, Nude Beige, Rosy Pink, Berry, Coral, Mauve, Wine, Peach, Hot Pink, Brick Brown (lips); Soft Pink, Peach, Coral, Rose (blush); Taupe, Soft Brown, Chestnut, Espresso (brows)
- Micro-copy: **Opacity 100%**, **Preview All**, **None**

## Format
Vertical 1080×1920, 30 fps, ~20 s.

## Storyboard (5 scenes, 20 s total, all soft cross-dissolves)

| # | 0-time | Dur | Beat | On screen |
|---|--------|-----|------|-----------|
| 1 | 0.0s | 3.0s | Hook | Deep charcoal background. A single Classic Red circle blooms up from center. Wordmark **MakeupPalette** rises under it in Helvetica Neue Medium. Subline `for the foldable iPhone Duo` fades in beneath. Hold. |
| 2 | 3.0s | 5.0s | Reveal — the palette | Palette panel slides up from bottom on the light background. Header `Makeup`. Three rows appear one after another: **Lips** (Classic Red selected), **Blush**, **Brows**. Real tiles, real colors, real order. Hold at "settled" for ~2 s. Caption bottom: **The whole palette. On one panel.** |
| 3 | 8.0s | 4.5s | Fold as layout | Two rounded panels part along a vertical seam: left panel is the camera preview (a soft gradient viewfinder with a stroked oval face), right is the palette. Between them, in the crease, a vertical opacity capsule fills to 100%. Caption top: **The hinge is a region.** |
| 4 | 12.5s | 4.5s | Preview All 2×2 | The 2×2 grid takes over. Four camera cells, each tinted with a different lip color (Classic Red, Rosy Pink, Coral, Berry). Names labeled small under each. Caption top: **Try four at once.** |
| 5 | 17.0s | 3.0s | Outro | Cross-dissolve back to charcoal. Wordmark **MakeupPalette** settles center. Tagline underneath: **Foldable-first.** Hold. Fade to black. |

Transitions are 0.4 s soft opacity cross-dissolves (not blur, not motion — polished). Every caption settles for ≥ 0.3 s per word before the next transition begins.

## Sound bed (one piece, mixed together)
- Ambient pad in A minor: two layered sine drones (A2, E3) with a slow sub octave, plus a whisper of pink noise sitting -18 dB under the drone.
- One bell tone on each scene entry (A5, C6, E5, A5, A4 across scenes 1-5), soft attack, long decay, all in the pad's key.
- A single low, filtered whoosh on the S1→S2 transition and again on S3→S4 (the two "reveal" moments), −24 dB.
- Master: soft fade in over 0.5 s, fade out over 0.8 s. Peak −6 dBFS, LUFS around −18. No harsh transients.

## Deliverables (this directory)
- `brag.mp4` — final vertical video
- `brag.jpg` — poster (a settled frame from S2, palette in full view)
- `share-copy.txt`
- `work/` — intermediates (frames, audio stems, scripts)
