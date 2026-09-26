import Foundation

/// Declaration order is the compositing order, independent of the order of user edits.
public enum Treatment: String, Codable, CaseIterable, Sendable {
    case foundation, concealer, blush, bronzer
    case cheekContour, noseContour, jawContour, templeContour
    case cheekHighlight, noseHighlight, cupidBowHighlight
    case eyeshadow, eyeliner, browFill, lipstick, lipLiner, mascara

    public var category: String {
        switch self {
        case .foundation, .concealer: return "Complexion"
        case .blush, .bronzer: return "Cheeks"
        case .cheekContour, .noseContour, .jawContour, .templeContour: return "Contour"
        case .cheekHighlight, .noseHighlight, .cupidBowHighlight: return "Highlight"
        case .eyeshadow, .eyeliner: return "Eyes"
        case .browFill: return "Brows"
        case .lipstick, .lipLiner: return "Lips"
        case .mascara: return "Lashes"
        }
    }

    public var displayName: String {
        switch self {
        case .cheekContour: return "Cheek contour"
        case .noseContour: return "Nose contour"
        case .jawContour: return "Jaw contour"
        case .templeContour: return "Temple contour"
        case .cheekHighlight: return "Cheek highlight"
        case .noseHighlight: return "Nose highlight"
        case .cupidBowHighlight: return "Cupid's bow highlight"
        case .browFill: return "Brow fill"
        case .lipLiner: return "Lip liner"
        default: return rawValue.capitalized
        }
    }
}

public enum MakeupError: Error, LocalizedError, Equatable {
    case invalidColor, invalidIntensity, unsupportedVersion(Int), unsupportedTreatment(String)

    public var errorDescription: String? {
        switch self {
        case .invalidColor: return "Color components must be finite sRGB values between 0 and 1."
        case .invalidIntensity: return "Intensity must be finite and between 0 and 1."
        case .unsupportedVersion(let version): return "Saved look version \(version) is not supported."
        case .unsupportedTreatment(let name): return "Unknown makeup treatment: \(name)."
        }
    }
}

/// Normalized sRGB components. Immutable so all values pass through validation.
public struct MakeupColor: Codable, Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) throws {
        guard [red, green, blue].allSatisfy({ $0.isFinite && (0...1).contains($0) }) else {
            throw MakeupError.invalidColor
        }
        self.red = red
        self.green = green
        self.blue = blue
    }

    private enum CodingKeys: String, CodingKey { case red, green, blue }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(red: values.decode(Double.self, forKey: .red),
                      green: values.decode(Double.self, forKey: .green),
                      blue: values.decode(Double.self, forKey: .blue))
    }
}

public struct MakeupStyle: Codable, Equatable, Sendable {
    public let color: MakeupColor
    public let intensity: Double

    public init(color: MakeupColor, intensity: Double) throws {
        guard intensity.isFinite && (0...1).contains(intensity) else {
            throw MakeupError.invalidIntensity
        }
        self.color = color
        self.intensity = intensity
    }

    private enum CodingKeys: String, CodingKey { case color, intensity }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(color: values.decode(MakeupColor.self, forKey: .color),
                      intensity: values.decode(Double.self, forKey: .intensity))
    }
}

public struct MakeupLook: Codable, Equatable, Sendable {
    public private(set) var treatments: [Treatment: MakeupStyle] = [:]

    public init() {}

    public var orderedTreatments: [Treatment] {
        Treatment.allCases.filter { treatments[$0] != nil }
    }

    public mutating func set(_ treatment: Treatment, style: MakeupStyle) {
        treatments[treatment] = style
    }

    public mutating func clear(_ treatment: Treatment) {
        treatments.removeValue(forKey: treatment)
    }

    public mutating func reset() {
        treatments.removeAll()
    }

    private enum CodingKeys: String, CodingKey { case version, treatments }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let version = try values.decode(Int.self, forKey: .version)
        guard version == 1 else { throw MakeupError.unsupportedVersion(version) }
        let saved = try values.decode([String: MakeupStyle].self, forKey: .treatments)
        for (name, style) in saved {
            guard let treatment = Treatment(rawValue: name) else {
                throw MakeupError.unsupportedTreatment(name)
            }
            treatments[treatment] = style
        }
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(1, forKey: .version)
        let saved = Dictionary(uniqueKeysWithValues: treatments.map { ($0.key.rawValue, $0.value) })
        try values.encode(saved, forKey: .treatments)
    }
}
