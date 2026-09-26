// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MakeupPalette",
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
