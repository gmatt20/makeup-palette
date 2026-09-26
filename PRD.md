# iPhone Duo Makeup Palette — Product Requirements

Status: Ready for implementation planning; no application code has been built.

This document records the agreed product behavior and component ownership. No delivery deadline is specified. Items identified as implementation defaults are recommendations, not additional decisions attributed to the user.

## 1. Objective

Create a native Swift iPhone makeup experience that works in Xcode/Bitrig without a live camera. A bundled 3D portrait stands in for the camera feed. Users select a makeup treatment and color from a palette, see the effect on the face, and rotate the model to inspect the result.

The first version should resemble a full makeup station, with recognizable makeup across the face. Realistic cosmetic finishes and freehand painting are stretch features.

The project has two collaborating owners:

- **Face-preview owner: you; assigned to Peyton in the original brief.** Own the model, makeup effects, rotation, saved look, receiving Swift API, and minimal integration controls.
- **App/palette owner: teammate, name unspecified.** Own the finished palette, app shell, fold/orientation handling, and integration of the face component.

The face-preview owner is **not** responsible for building the entire finished app.

## 2. Agreed scope

| Decision | Requirement |
|---|---|
| Final application | Native Swift iPhone app, built and run using Xcode/Bitrig on a Mac |
| Development | Windows proof of concept and asset work; Mac available for early native validation |
| Face input | Bundled `Sasha_Grey_Portrait.usdz` supplied by the user |
| Camera | No live camera or camera permission required for this feature |
| Application method | Select treatment, then tap a color to apply it |
| Coverage | Full station: complexion, cheeks, contour, highlight, eyes, brows, lips, and lashes |
| Paired features | Both sides update together initially |
| Movement | Drag to rotate; useful front and three-quarter views; Front reset |
| Initial visual quality | Recognizable makeup that preserves the model's visible skin detail |
| Before/Clear baseline | The supplied model's original appearance, including existing makeup |
| Persistence | Automatically save the latest look and restore it after app relaunch |
| Integration | Direct Swift calls inside the app; no network receiver |
| Deadline | None specified |

## 3. Experience and layout

“Closed” means the simulated phone is folded shut while the app remains running. It does not mean quitting the app.

| Device state | Face preview | Makeup palette |
|---|---|---|
| Fully closed | Fills the available app display; remains rotatable | Hidden |
| Open or partially open, portrait | Top | Bottom |
| Open or partially open, landscape | Left | Right |

Partially folded poses should function like an open makeup compact. Align the division with the hinge where the simulator's supported layout behavior permits it. Left/right swapping is outside the first version.

Folding, unfolding, and orientation changes must preserve applied makeup, viewing angle, selected treatment, and intensity settings. They must not recreate the face session or reload the original look. Opening the phone restores the palette to its previous editing state.

The app owner must validate the simulator's fold and orientation signals on the target Xcode/Bitrig version. Do not infer open/closed state solely from screen aspect ratio. Exact panel proportions and transition animation are implementation choices.

### Main interaction

1. Launch into the restored look, or the supplied model's original appearance if no look has been saved.
2. Open the device to reveal the palette.
3. Select a category and treatment, such as Eyes → Eyeshadow.
4. Tap a color and adjust intensity. The corresponding region updates without changing unrelated treatments.
5. Drag the face to inspect the result. Front returns to the reference angle without removing makeup.
6. Clear one treatment, reset the complete look, or compare with the original appearance.
7. Fold or rotate the device; continue from the same look and viewing angle.

Implementation defaults: organize controls as category → treatment → color; provide intensity, Clear treatment, Reset all, Front, and an accessible Before/After toggle. The comparison temporarily hides added makeup and must not erase or save over the edited look.

## 4. Makeup treatments

These are the proposed treatment breakdown for the requested full station. The implementation should share rendering behavior where appropriate while retaining separate settings for treatments that users need to combine.

| Category | Treatments | Target area and first-version behavior |
|---|---|---|
| Complexion | Foundation; concealer | Tint facial skin while retaining detail; separate under-eye concealer mask. Exclude hair, eyes, and mouth interior. |
| Cheeks | Blush; bronzer | Soft color on cheek apples and warmer shading over the cheeks; separate layers. |
| Contour | Cheek; nose; jaw; temple contour | Independent soft masks for cheek hollows, nose sides, jawline, and temples. |
| Highlight | Cheek; nose; cupid's bow highlight | Controlled lightening/tint on upper cheekbones, nose bridge/tip, and above the upper lip. Reflective shimmer is a stretch. |
| Eyes | Eyeshadow; eyeliner | Soft lid color and a separate precise lash-line treatment. Do not tint eyeballs. |
| Brows | Brow fill/tint | Apply color within the existing brow shapes. |
| Lips | Lipstick; lip liner | Separate lip-surface and border treatments; exclude teeth and mouth interior. |
| Lashes | Mascara effect | A prepared lash overlay or equivalent model-specific treatment. It must resemble lashes, not a solid fill over the eyes. |

Each treatment has independent color and intensity. Selecting a new color replaces that treatment's setting; repeatedly tapping the same swatch must not progressively accumulate pigment. The rendering order should be deterministic so switching palette categories does not change the finished look.

Masks must follow the face surface through rotation. A screen-space sticker that stays in place while the model turns does not meet acceptance criteria.

The initial standard is a convincing demonstration of placement and color, not physically accurate cosmetic simulation or product shade matching. Skin detail should remain visible where coverage allows. Soft treatments need feathered edges; eyeliner and lip liner need defined boundaries.

## 5. Supplied asset findings

The supplied USDZ was inspected read-only using OpenUSD, and its color texture was visually inspected. These are asset observations, not proof that the model has been rendered successfully in the target app.

| Property | Observed value |
|---|---|
| File size | 16,585,646 bytes |
| Root scene | Binary USD scene, `scene.usdc` |
| Meshes | Seven mesh pieces |
| Geometry | 558,206 triangular faces in total |
| Materials | One shared material across the mesh pieces |
| Texture mapping | `st0` UV coordinates present on every mesh |
| Textures | Five JPEG textures, each 2048 × 2048 |
| Animation | No skeletal rig, blend shapes, or time-sampled animation found during traversal |
| Makeup regions | No dedicated lip, eye, cheek, or other makeup-region masks found |
| Existing appearance | Makeup and shading already visible in the supplied color texture |

The UV texture is an atlas containing multiple pieces of the model, not a simple front-facing portrait. Region masks therefore require model-aware preparation and inspection across seams. The seven mesh pieces must not be assumed to correspond to facial features.

The source material uses both diffuse and emissive texture connections, and OpenUSD reported material-binding schema warnings. Check appearance in the Apple renderer before deciding whether material cleanup is necessary. Preserve the original file; any conversion, material adjustment, or geometry reduction should produce a separate working asset.

Whole-model rotation does not depend on a facial rig. Blinking, smiling, and other facial deformation would require additional asset work and are outside the first version.

## 6. Ownership and handoff

| Component or task | Face-preview owner: you / Peyton | App/palette teammate |
|---|---|---|
| Model inspection and prepared assets | Own | Validate inclusion in app bundle |
| Facial treatment masks | Own | Review treatment names and controls |
| Model loading and rendering | Own | Embed the component |
| Makeup composition | Own | Send treatment selections |
| Drag rotation and Front reset | Own | Place any external controls |
| Receiving Swift API and state validation | Own | Call the documented interface |
| Latest-look persistence | Own authoritative look state | Avoid a competing copy of makeup state |
| Minimal test controls | Own, for development/integration only | May reuse while integrating |
| Finished palette UI | Provide supported treatments/state | Own |
| Selected palette category/treatment | Expose any needed capabilities | Own and preserve during layout changes |
| Fold/orientation layout and app shell | Keep component resize-safe | Own |
| Native integration check | Provide model, effect, and API; participate | Run/embed in Xcode/Bitrig; participate |
| End-to-end acceptance | Verify face behavior | Verify whole-app behavior |

The face component handoff includes Swift source, prepared model/textures/masks, treatment identifiers, API documentation, example calls or command fixtures, minimal test controls, and a record of native validation results.

## 7. Receiving API contract

The API is an in-process Swift interface. No HTTP server, WebSocket connection, cloud service, or remote-command authentication flow is required for the agreed scope.

The following names describe the intended contract; exact Swift signatures should be settled at the first integration checkpoint.

| Operation | Required behavior |
|---|---|
| Read supported treatments | Return stable treatment identifiers and their categories |
| Read current look | Return current color/intensity settings so palette controls reflect restored state |
| Set makeup | Accept treatment identifier, color, and intensity; replace that treatment's settings and update preview |
| Clear treatment | Remove only the specified treatment and save the updated look |
| Reset all | Remove all added treatments, restore the original appearance, and save the reset state |
| Show original / show edited | Temporarily switch comparison view without mutating the saved look |
| Reset view | Return model orientation to Front without changing makeup |
| Observe status | Expose loading, ready, and actionable failure state to the app shell |

Implementation defaults:

- Use stable, typed treatment identifiers and a documented color representation, such as normalized sRGB components. Intensity ranges from 0 to 1.
- Validate unsupported treatments, non-finite numbers, and out-of-range inputs at the receiving boundary. An invalid command must not corrupt the current look.
- Keep a single authoritative look state. Palette changes, rendering, and persistence all use it.
- Keep color/intensity/state logic independent of the Apple UI renderer where practical. Avoid passing renderer-specific material objects through the palette API.
- Keep view orientation transient: preserve it through folding and rotation. Only makeup settings are required to survive app relaunch.
- Retain the previous valid look if a rendering update fails. Surface asset-loading failures rather than showing a silently blank face.

## 8. Windows-to-Mac development path

Windows must support the requested proof of concept: inspect the model, prepare masks, and demonstrate changing treatment colors on the supplied face using minimal preview controls. This is a development preview, not a second finished product UI.

Reuse the model or its documented working derivative, masks, treatment identifiers, color conventions, and test commands in the native iPhone component. Choose the smallest Windows preview mechanism that can exercise those assets. Its exact renderer is an implementation decision.

Swift can run on Windows, but Apple's SwiftUI/RealityKit rendering environment is not available there. A Windows preview is therefore not proof that the same UI or rendering code can be imported unchanged into Xcode. Any prototype-only rendering code must be explicitly identified, with the corresponding native behavior validated on the Mac.

The final face component must render locally without a live camera, a Windows service, or a network connection. It should use non-AR model rendering rather than requiring an ARKit face-tracking session.

### First integration checkpoint

Before completing every treatment mask:

1. Load the supplied model or working derivative in the actual iPhone simulator target.
2. Verify textures, lighting, orientation, and framing.
3. Verify drag rotation and Front reset.
4. Receive one lipstick command through the proposed Swift interface and show its effect correctly on the rotating model.
5. Resize/reposition the component through the app shell without losing the look or angle.

This checkpoint resolves native compatibility and integration risk before the team expands the full station. It is a sequencing recommendation, not a deadline or reduction in target scope.

## 9. Persistence, controls, and failure behavior

- Save the latest valid treatment settings locally and restore them on app launch. Do not modify the original USDZ or bake every user selection permanently into the source texture.
- Clear treatment and Reset all must update persistence, so cleared makeup does not reappear after relaunch.
- A missing saved look starts from the supplied model. Invalid saved data must not crash the app or be silently treated as a successful restore.
- Temporary Before/After comparison must not affect persistence.
- Provide accessible labels for treatment selection and swatches; do not communicate selection by color alone. Expose intensity as an accessible control.
- Pair drag rotation with an accessible way to adjust the view, as well as Front reset.
- Test component loading/error states with the app owner. No camera prompt should appear on this path.

## 10. Acceptance criteria

| ID | Pass condition | Owner |
|---|---|---|
| FC-01 | Bundled model loads with recognizable source appearance and no camera permission in the target simulator. | Face |
| FC-02 | Dragging rotates through front/three-quarter views; Front restores reference orientation without changing makeup. | Face |
| FC-03 | Every first-version treatment listed in section 4 visibly affects its intended region. | Face |
| FC-04 | Eyeshadow, liner, lips, complexion, and other masks avoid excluded features; paired regions update together. | Face |
| FC-05 | Makeup remains attached to the face while rotating, including across visible UV seams. | Face |
| FC-06 | Color and intensity changes preserve other treatments; repeated identical commands produce the same appearance. | Face |
| FC-07 | Clear treatment removes only that effect. Reset all restores the source appearance. Before/After preserves the edited look. | Face |
| FC-08 | Latest look survives app relaunch; cleared/reset settings remain cleared/reset. | Face |
| FC-09 | Invalid API inputs leave the previous valid state intact and expose a failure outcome. | Face |
| FC-10 | Windows proof of concept demonstrates the agreed asset/mask behavior; native validation is recorded separately. | Face |
| APP-01 | Fully closed displays only the face component, which remains rotatable. | App |
| APP-02 | Open/partially open portrait displays face above palette; landscape displays face left of palette. | App |
| APP-03 | Repeated fold/unfold and orientation changes preserve makeup, angle, and selected palette treatment. | Shared |
| APP-04 | Palette reflects restored values and uses the documented Swift API without separate makeup-state ownership. | Shared |
| APP-05 | Core application controls are usable with accessible labels and alternatives to drag-only rotation. | Shared |

No frame-rate target was agreed. Validate responsive rotation and color changes on the actual Mac/simulator configuration. Reduce working-asset geometry or adjust rendering only if measured behavior warrants it; report any visual tradeoff.

Use small, runnable checks for command replacement, invalid input, reset behavior, and saved-look restoration. Verify rendering, masks, fold transitions, and accessibility in the native app; data-level checks alone cannot establish visual correctness.

## 11. Stretch features and exclusions

Stretch features, after the complete baseline works:

- Freehand painting attached to the face surface, including brush controls and erasing.
- Realistic finishes: matte/gloss lipstick, shimmer eyeshadow, reflective highlighter, more realistic foundation coverage.
- A cleaned bare-face texture distinct from the supplied model's original appearance.
- Automatic idle movement or facial animation, subject to asset support.
- Named saved looks or a gallery.

Outside the agreed first version:

- Live camera, real-person face tracking, or camera-feed injection into the simulator.
- Arbitrary portrait/model uploads inside the app or automatic adaptation to other faces.
- A separately shipped desktop macOS app.
- Network receiving API, backend, accounts, cloud sync, or sharing/export workflows.
- Independent left/right makeup editing or swapping camera/palette sides.

## 12. Remaining implementation checks

These are engineering checks to resolve during development, not unanswered product questions requiring another interview:

- Native USDZ rendering and any necessary material normalization.
- Correct facial masks on the supplied UV atlas, including lash feasibility and seam coverage.
- Useful rotation bounds and framing for this particular model.
- The minimal Windows preview mechanism and what code/assets are reusable in the native component.
- Exact Swift signatures and state-observation mechanism agreed with the app owner.
- Simulator fold/hinge APIs and target Xcode/Bitrig version, validated by the app owner.
- Performance of the supplied geometry and textures in the actual simulator.

## 13. Research references

- [Bitrig: iPhone Duo app and folding-simulator support](https://bitrig.com/blog/bitrig-builds-iphone-duo-apps) — fold, orientation, and native app integration context.
- [Apple: tracking and visualizing faces](https://developer.apple.com/documentation/arkit/tracking-and-visualizing-faces) — ARKit face effects and documented simulator limitation; ARKit tracking is not the selected implementation.
- [Apple: RealityViewCameraContent](https://developer.apple.com/documentation/realitykit/realityviewcameracontent) — non-AR rendering context.
- [Apple: RealityKit materials](https://developer.apple.com/documentation/realitykit/material) — model appearance and imported USDZ materials.
- [Swift: platform and framework context](https://www.swift.org/about/) — portable Swift versus Apple-specific frameworks.
- [Charlotte Tilbury: makeup categories and application steps](https://www.charlottetilbury.com/uk/secrets/correct-order-of-makeup-steps) — reference for station categories, not a product endorsement or required routine order.
- [Charlotte Tilbury: contour placement](https://www.charlottetilbury.com/us/product/beauty-light-wand-hollywood-contour-kit) — reference for nose, temple, and jaw contour regions.
- [OpenUSD: inspecting scene properties](https://openusd.org/release/tut_inspect_and_author_props.html) and [UV/primvar inspection](https://openusd.org/release/api/class_usd_geom_primvars_a_p_i.html) — read-only inspection method for the supplied model.

Asset findings in section 5 come from the supplied file, not from the reference links.
