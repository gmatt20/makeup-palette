#if canImport(UIKit) && canImport(RealityKit)
import CoreGraphics
import Foundation
import ImageIO
import MakeupCore

/// CPU work stays off the main actor. The supplied atlas and masks use identical pixel coordinates.
actor MakeupTextureComposer {
    /// One lit texel of a mask. Masks are static, so only their nonzero texels are kept: a compose
    /// pass then costs the painted area rather than 4.2M texels per treatment.
    private struct Coverage {
        let offset: Int
        let mask: Double
    }

    private let resources: URL
    private var source: [UInt8] = []
    private var coverages: [Treatment: [Coverage]] = [:]
    private var width = 0
    private var height = 0

    init(resources: URL) { self.resources = resources }

    func compose(_ look: MakeupLook) throws -> CGImage {
        if source.isEmpty {
            let image = try readImage(resources.appendingPathComponent("base-color.jpg"))
            width = image.width
            height = image.height
            source = try rgba(image)
        }
        var pixels = source
        for treatment in Treatment.allCases {
            guard let style = look.treatments[treatment], style.intensity > 0 else { continue }
            if coverages[treatment] == nil {
                let image = try readImage(resources.appendingPathComponent("masks/\(treatment.rawValue).png"))
                guard image.width == width, image.height == height else {
                    throw FacePreviewError.asset("The \(treatment.rawValue) mask does not match the face texture.")
                }
                // Masks are authored as grayscale, so the red channel carries the coverage value.
                // This full scan happens once per mask and is then cached; do not preallocate, the
                // painted area is a small fraction of the atlas and the list is kept for the session.
                let bytes = try rgba(image)
                var lit: [Coverage] = []
                for offset in stride(from: 0, to: bytes.count, by: 4) where bytes[offset] > 0 {
                    lit.append(Coverage(offset: offset, mask: Double(bytes[offset]) / 255))
                }
                coverages[treatment] = lit
            }
            guard let lit = coverages[treatment] else { continue }
            let color = [style.color.red, style.color.green, style.color.blue]
            for entry in lit {
                let offset = entry.offset
                let luminance = (0.2126 * Double(source[offset])
                    + 0.7152 * Double(source[offset + 1])
                    + 0.0722 * Double(source[offset + 2])) / 255
                for channel in 0..<3 {
                    let value = 255 * MakeupBlend.channel(
                        accumulated: Double(pixels[offset + channel]) / 255, color: color[channel],
                        originalLuminance: luminance, mask: entry.mask,
                        intensity: style.intensity)
                    pixels[offset + channel] = UInt8(min(255, max(0, value.rounded())))
                }
            }
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8,
                                  bitsPerPixel: 32, bytesPerRow: width * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: true,
                                  intent: .defaultIntent) else {
            throw FacePreviewError.asset("Could not create the makeup texture.")
        }
        return image
    }

    private func readImage(_ url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw FacePreviewError.asset("Missing or unreadable face asset: \(url.lastPathComponent).")
        }
        return image
    }

    private func rgba(_ image: CGImage) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let success = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: image.width,
                                          height: image.height, bitsPerComponent: 8,
                                          bytesPerRow: image.width * 4,
                                          space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        guard success else { throw FacePreviewError.asset("Could not read the face texture pixels.") }
        return bytes
    }
}
#endif
