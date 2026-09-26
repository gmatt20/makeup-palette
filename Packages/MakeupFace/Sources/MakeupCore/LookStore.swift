import Foundation

/// Call from the single face-session owner. Failed restores never modify the file.
public struct LookStore: Sendable {
    public let url: URL

    public init(url: URL) { self.url = url }

    public func load() throws -> MakeupLook {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return MakeupLook()
        }
        return try JSONDecoder().decode(MakeupLook.self, from: data)
    }

    public func save(_ look: MakeupLook) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(look)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}
