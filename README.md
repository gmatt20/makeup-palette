# Makeup Palette

A SwiftUI iPhone app for the iPhone Duo makeup palette project.

The `MakeupPalette` target is the app entry point. Its camera preview currently
shows a neutral placeholder. `CameraPreviewView` accepts independent feed and
effects views so the team's 3D model and makeup rendering can be added later.

`MakeupEffectBridge` defines the v1 brow, blush, and global opacity calls.
`MockMakeupEffectBridge` makes palette selections visible in the placeholder
preview. Opacity is a `Float` in `0...1`, defaults to `1`, and is saved between
launches. The palette uses color swatches today; `MakeupSwatch.png` also accepts
an asset name for future PNG swatches.
Build with the iOS 27.1 SDK in Bitrig. The minimum deployment target is iOS 26.
