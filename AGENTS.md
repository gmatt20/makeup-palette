# AGENTS.md — MakeupPalette

Guidance for AI agents (and humans) working on this repo. Read this first.

## What this is

A SwiftUI iPhone **Duo (foldable)** makeup try-on app, built at a hackathon.
There is **no real camera** — a fake camera (FC) shell stands in for a live
feed. A makeup palette (MP) writes selections to the FC through a single,
decoupled seam so a real 3D-face renderer can drop in later without touching
the palette.

The current focus is the **foundation**: keep everything modular and
decoupled so other features stack on top cleanly.

- Target: iOS **26.0** deployment, but the fold-aware layout uses **iOS 27.1**
  hinge APIs behind `#available` (see below).
- `TARGETED_DEVICE_FAMILY = 1` (iPhone).
- Fonts: Helvetica Neue, centralized and swappable (`PaletteTypography`).

## Build & run

```sh
xcodebuild build \
  -project MakeupPalette.xcodeproj \
  -scheme MakeupPalette \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -configuration Debug
```

**Always build after changes.** SourceKit shows "Cannot find type ... in
scope" per-file diagnostics while editing — that is single-file analysis
noise (types live in sibling files) and clears on a full build. Trust the
`xcodebuild` result, not the inline diagnostics.

The fold-specific behavior (hinge angle, split, reflection, opacity
placement) only manifests on a **foldable simulator / device**; a normal
iPhone sim exercises the pre-27.1 fallback path.

## Xcode project gotcha (IMPORTANT)

The project uses **explicit file references** — it does NOT use synchronized
file groups. **A new `.swift` file will not compile until it is registered in
`MakeupPalette.xcodeproj/project.pbxproj`** in four places:

1. `PBXBuildFile` section
2. `PBXFileReference` section
3. the correct `PBXGroup` (Models / Palette / Layout / Camera)
4. the `PBXSourcesBuildPhase` `files` list

IDs follow the pattern `A10000000000000000000XX`. Pick the next free pair
(one for the fileRef, one for the buildFile). Copy an existing entry as a
template. Forgetting this yields "Cannot find ... in scope" that a build
does NOT resolve.

## Architecture (data flow)

```
MP (MakeupPaletteView)
  --press--> bridge.select / apply*        writes intent
  --hold---> SwatchColorEditor -> bridge   custom color, streamed live
  --opacity-> bridge.applyOpacity
        |
        v
  MakeupEffectBridge (protocol)  <-- MockMakeupEffectBridge (@Observable)
        |
        v
  bridge.look : MakeupLook       single read-only snapshot (the FC seam)
        |
        v
  FC (CameraPreviewView: MockCameraFeedView + MockCameraEffectsView)
```

**Golden rule:** the MP and FC communicate ONLY through
`MakeupEffectBridge` (writes) and `MakeupLook` (reads). Do not let the
camera reach into palette internals, or vice versa.

### Directory map

- `Models/`
  - `MakeupColor` — RGB floats; `init(rgb:)`, `init(hue:saturation:brightness:)`,
    and `.hsb` (used by the color wheel).
  - `MakeupSwatch` — `enum { .color(MakeupColor), .png(assetName:) }`.
    **Extensible on purpose** — add cases here for new swatch kinds.
  - `MakeupOption` — one selectable swatch (`id, category, name, swatch, tint`);
    `.editableColor`, `.recolored(to:)`.
  - `MakeupCategory` — `enum { lips, blush, brow }` (declaration order = UI order).
  - `MakeupCatalog` — the color data; `swatch(...)` helper keeps tile/tint in sync.
  - `EyebrowMask` — `{ id, name, assetName }`, a PNG brow-shape stencil,
    separate from brow tint.
  - `MakeupEffectBridge` — the write protocol + `look` derivation (extension).
  - `MockMakeupEffectBridge` — `@Observable` mock; persists opacity in
    `UserDefaults`. Swap this out for a real engine later.
  - `MakeupLook` — immutable snapshot the FC reads (`effects`, `eyebrowMask`,
    `opacity`).
- `Palette/`
  - `MakeupPaletteView` — the white MP panel; category rows, press/hold
    swatches, and the opacity control. Reads `\.opacityPlacement` +
    `\.swatchReflection` from the environment.
  - `SwatchColorEditor` — long-press modal; **circular hue/saturation color
    wheel** + brightness slider; streams changes back to the bridge.
  - `PaletteTypography` — swap fonts here (Helvetica Neue today).
  - `MakeupColor+SwiftUI` — `Color(makeupColor:)`.
- `Layout/`
  - `DuoStudioLayout` — the fold-aware container. Reads hinge via
    `onHingeChange` / `DeviceHinge` (iOS 27.1) with a size-class fallback.
    Owns the split, the reflection state, and opacity placement.
  - `SwatchReflection` — `SwatchReflection` env value + `OpacityPlacement`
    enum + env plumbing.
- `Premium/`
  - `PremiumStore` — protocol gating premium shades (`isSubscribed`,
    `monthlyPriceText`, `subscribe()`, `restore()`). **This is the RevenueCat
    integration seam** — its doc comment maps each member to the SDK call.
  - `MockPremiumStore` — `@Observable` demo store; grants entitlement on
    `subscribe()` and persists it in `UserDefaults`. Swap for a
    `RevenueCatPremiumStore` later.
  - `PaywallView` — the $4.99/mo subscription sheet; presentation-only, calls
    back to run the purchase so it works over mock or RevenueCat unchanged.
  - `RevenueCatPremiumStore` — live store (`#if canImport(RevenueCat)`):
    `Purchases.configure`, entitlement `premium`, `customerInfoStream`,
    purchase/restore, real localized price.
  - `PremiumStoreFactory` — the one place that picks the store: RevenueCat when
    the SDK + API key are present, else `MockPremiumStore`. `ContentView` uses
    it and passes `any PremiumStore` to the palette.
  - `AppSecrets` — reads `REVENUECAT_APPLE_API_KEY` from `Info.plist`.
- `Camera/`
  - `CameraPreviewView` — layers a non-interactive effects overlay over a
    replaceable feed.
  - `MockCameraFeedView` — placeholder gradient/viewfinder (**replace with the
    real 3D face**).
  - `MockCameraEffectsView` — consumes a `MakeupLook`, draws effect + mask
    badges and an opacity chip. Stand-in for the real renderer.

## Key behaviors & their rules

- **Swatch interaction:** tap = apply immediately (`bridge.select`); long-press
  (0.35s) = open the circular color editor. Only `.color` swatches are
  editable.
- **Opacity:** `0.0...1.0 Float`, default `1.0`, clamped, applies to ALL
  effects, persisted. Placement is fold/orientation-aware
  (`OpacityPlacement`): **top** (portrait, at the crease), **leading**
  (landscape ~90°, at the hinge), **bottom** (fully open). Opacity must
  never dim the palette UI — only the rendered makeup.
- **Hinge reflection:** each swatch box mirrors across the phone's longer axis
  while the hinge angle is strictly **> 3° and < 87°** (3° padding). See
  `swatchReflectionEffect`.
- **Layout:** closed = camera full-screen; open = split (camera top / palette
  bottom in portrait, camera left / palette right in landscape). Camera gets
  the larger share via `splitArrangementLayoutRatio(0.64)`.
- **Premium gating:** `MakeupOption.isPremium` marks ~1/3 of each group.
  A locked premium swatch (premium && `!isSubscribed`) shows a gold border +
  lock icon; tapping or holding it opens the `PaywallView` instead of
  applying. Subscribing unlocks all premium swatches live. The palette is
  generic over `Store: PremiumStore` (mirrors the `Bridge` generic) so
  Observation tracks `isSubscribed`.

## Discovering the iOS 27.1 hinge/fold API

These symbols are NOT in public docs training data. Read the SDK interface:

```
/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator27.1.sdk/System/Library/Frameworks/SwiftUICore.framework/Modules/SwiftUICore.swiftmodule/arm64-apple-ios-simulator.swiftinterface
```

Relevant: `DeviceHinge { status, angle }`, `DeviceHingeContext.hinge`,
`View.onHingeChange`, `GeometryProxy.reservedRegions(kind:.division)`,
`ArrangementView` + `.arrangementViewStyle(.split)`,
`View.splitArrangementLayoutRatio(_:)`.

## Secrets / config

The RevenueCat public Apple SDK key (`appl_...`) lives in **`.env`** as
`REVENUECAT_APPLE_API_KEY` (git-ignored). A SwiftUI binary can't read `.env`,
so it flows in as a build setting:

```
.env ──scripts/gen-secrets.sh──▶ Config/Secrets.xcconfig  (git-ignored)
                                   #include? by Config/Base.xcconfig (committed)
                                   ──▶ target baseConfigurationReference
                                   ──▶ Info.plist $(REVENUECAT_APPLE_API_KEY)
                                   ──▶ AppSecrets.revenueCatAPIKey
```

On a fresh clone: `cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig`
and paste the key, **or** put it in `.env` and run `scripts/gen-secrets.sh`.
No key → `AppSecrets` returns nil → `MockPremiumStore` (paywall still demoable).
Only the **public** key (`appl_...`) belongs here — never the secret (`sk_...`).

## Conventions

- Match the surrounding style: two-space indent, `@ViewBuilder` helpers,
  small private structs per component, doc-comment the "why".
- Keep new cross-cutting state in the environment (see `SwatchReflection`,
  `OpacityPlacement`) rather than threading params deep.
- Commits are **authored by the human** — do not run `git commit` unless
  explicitly asked. When asked, end messages with:
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- PR descriptions end with:
  `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

## Open items / next steps

- [ ] **Verify the camera split ratio on a real foldable.** On a true
  dual-display hinge the split may be physically locked to 50/50 and
  `splitArrangementLayoutRatio(0.64)` ignored. If so, the fallback is a
  manual `GeometryReader` + ratio layout that crosses the crease — confirm
  the trade-off with the human before doing it.
- [ ] **PNG swatch path is coded but unexercised.** `MakeupSwatch.png` and its
  `Image(assetName)` rendering exist, but no catalog entry uses it and there
  are no texture assets. `EyebrowMask` also needs real PNG stencils
  (`assetName`) in `Assets.xcassets` before it renders.
- [ ] **No palette UI for eyebrow masks yet.** `applyEyebrowMask` /
  `disableEyebrowMask` exist on the bridge and surface in `MakeupLook`, but
  there is no Brow Shape row in the MP.
- [x] **RevenueCat SDK integrated.** SPM package linked, `RevenueCatPremiumStore`
  written, key plumbing + `PremiumStoreFactory` swap done, builds clean.
- [ ] **Finish RevenueCat go-live (dashboard + verify).** Create the `premium`
  entitlement and a $4.99/mo product (linked to an App Store Connect product)
  in the RevenueCat dashboard, then verify a real purchase via a StoreKit
  config file or sandbox account on a device/Xcode run — cannot be verified
  from headless `xcodebuild`. Confirm the key in `.env` is the RevenueCat
  **Apple public SDK key** (`appl_...`).
- [ ] **Real face renderer.** Replace `MockCameraFeedView` /
  `MockCameraEffectsView` with a 3D face that consumes `MakeupLook`
  (teammates are sourcing the model). Nothing else should need to change.
- [ ] **Only opacity persists.** Effect/mask selections are in-memory
  (kept across folds/rotations by SwiftUI state, but not across relaunch).

## Handoff checklist

Before handing off, confirm:

1. `xcodebuild ... build` succeeds (no errors).
2. Any new `.swift` file is registered in all four `project.pbxproj` places.
3. New cross-MP/FC data flows go through `MakeupEffectBridge` + `MakeupLook`
   only.
4. This file (`AGENTS.md`) is updated: move done items out of "next steps",
   add new open items, and note any new API on the bridge.
5. Working tree is left building and uncommitted unless the human asked for a
   commit; if summarizing, restate the suggested commit message.
