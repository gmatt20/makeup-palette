// swift-tools-version: 5.9
import PackageDescription

/// Face-preview component for the makeup palette app.
///
/// Consumed as a local package by `MakeupPalette.xcodeproj`. `MakeupCore` holds the treatment
/// IDs, look state, validation, blend math, and persistence, and has no Apple UI dependency, so
/// it is unit-testable with `swift test` on a Mac. `MakeupFace` adds the RealityKit renderer and
/// bundles the prepared portrait and masks.
let package = Package(
    name: "MakeupFace",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MakeupCore", targets: ["MakeupCore"]),
        .library(name: "MakeupFace", targets: ["MakeupFace"])
    ],
    targets: [
        .target(name: "MakeupCore"),
        .target(name: "MakeupFace", dependencies: ["MakeupCore"], resources: [.copy("Resources")]),
        .testTarget(name: "MakeupCoreTests", dependencies: ["MakeupCore"])
    ]
)
