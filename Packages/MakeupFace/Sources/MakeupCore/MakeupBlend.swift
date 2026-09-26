/// Shared texture-compositing math for normalized sRGB channels and grayscale masks.
public enum MakeupBlend {
    /// Inputs must be in 0...1. Luminance always comes from the original skin texture.
    /// Artistic tint preserves detail; physically accurate finishes need a material shader.
    public static func channel(accumulated: Double, color: Double,
                               originalLuminance: Double, mask: Double, intensity: Double) -> Double {
        let alpha = intensity * mask * 0.8
        let shade = 0.45 + 0.55 * originalLuminance
        return accumulated * (1 - alpha) + color * shade * alpha
    }
}
