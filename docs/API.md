# MakeupFace receiving API

In-process Swift interface for the app/palette owner. No network. Keep a single `MakeupFaceController` for the face session.

## Types

```swift
public enum Treatment: String, Codable, CaseIterable  // foundation … mascara
public struct MakeupColor  // init(red:green:blue:) throws; each 0...1 finite
public struct MakeupStyle  // init(color:intensity:) throws; intensity 0...1
public struct MakeupLook   // treatments map; orderedTreatments follows Treatment.allCases
```

Invalid color/intensity throws `MakeupError` and must not be applied.

## Controller surface

```swift
@MainActor
public final class MakeupFaceController: ObservableObject {
    @Published public private(set) var look: MakeupLook
    @Published public var selectedTreatment: Treatment
    @Published public private(set) var status: FacePreviewStatus  // .loading | .ready | .failed(String)
    @Published public private(set) var isUpdating: Bool
    @Published public private(set) var showsOriginal: Bool
    @Published public private(set) var yaw: Float
    @Published public private(set) var pitch: Float
    @Published public private(set) var persistenceWarning: String?
    @Published public private(set) var commandError: String?

    public let supportedTreatments: [Treatment]
    public init(savedLookURL: URL? = nil)

    public func load() async
    public func setMakeup(_ treatment: Treatment, color: MakeupColor, intensity: Double) async throws
    public func clear(_ treatment: Treatment) async throws
    public func resetAll() async throws
    public func setComparison(_ showOriginal: Bool)   // does not mutate or save look
    public func rotate(yaw: Float, pitch: Float)
    public func resetView()
}
```

Embed with:

```swift
MakeupFacePreview(controller: face)
```

`MakeupFacePreview` calls `load()` on appear. Failed loads can be retried via the on-screen Retry control or `await controller.load()`.

## Command examples

```swift
let color = try MakeupColor(red: 0.72, green: 0.18, blue: 0.28)
try await face.setMakeup(.lipstick, color: color, intensity: 0.85)

try await face.clear(.lipstick)
try await face.resetAll()

face.setComparison(true)   // Before
face.setComparison(false)  // After — edited look unchanged on disk
face.resetView()
```

## Persistence

- Latest valid look is saved under Application Support (`MakeupFace/latest-look.json`) unless you pass `savedLookURL`.
- Clear and Reset all persist immediately after a successful texture compose.
- Comparison never writes persistence.
- Corrupt or unsupported saved data surfaces `persistenceWarning`, shows the original face, and leaves the file untouched until a successful edit or reset.

## Look JSON (shared with Windows preview)

```json
{
  "version": 1,
  "treatments": {
    "lipstick": {
      "color": { "red": 0.72, "green": 0.18, "blue": 0.28 },
      "intensity": 0.85
    }
  }
}
```

Keys are `Treatment.rawValue`. Unknown keys or out-of-range values fail decode/validation.

## Layout contract

Folding, unfolding, and orientation changes must **not** recreate `MakeupFaceController`. Resize `MakeupFacePreview` freely; orientation (yaw/pitch) is transient across layout changes and only makeup settings are required to survive app relaunch.

## Failure behavior

| Situation | Behavior |
|---|---|
| Unsupported / non-finite inputs | Throw; previous look stays visible and saved |
| Compose/texture failure after ready | Throw; previous look stays; `commandError` set |
| Asset load failure | `status == .failed`; retry allowed |
| Missing saved look | Empty look (original appearance) |
