import AppKit
import SwiftUI

/// Picks an accent colour from album art with plain arithmetic: a hue histogram, no AI.
enum AlbumColor {
    struct RGB { var r, g, b: Double } // each 0...1
    struct HSB: Equatable { var hue, saturation, brightness: Double } // each 0...1

    static let white = HSB(hue: 0, saturation: 0, brightness: 1)

    /// 1. Give every pixel a "colourfulness" weight: chroma = brightest channel − darkest channel.
    ///    Black, grey and white pixels weigh about 0.
    /// 2. If the cover is on average barely colourful (black, grey or white cover), return white.
    /// 3. Otherwise sort pixels into 24 hue buckets by weight, take the heaviest bucket,
    ///    and return its average hue at full brightness so it glows on black.
    static func accent(for pixels: [RGB]) -> HSB {
        var weight = [Double](repeating: 0, count: 24)
        var hueSum = weight, saturationSum = weight
        for p in pixels {
            let high = max(p.r, p.g, p.b), chroma = high - min(p.r, p.g, p.b)
            guard chroma > 0.08 else { continue }
            var hue: Double
            switch high {
            case p.r: hue = ((p.g - p.b) / chroma).truncatingRemainder(dividingBy: 6)
            case p.g: hue = (p.b - p.r) / chroma + 2
            default: hue = (p.r - p.g) / chroma + 4
            }
            hue = (hue < 0 ? hue + 6 : hue) / 6
            let bucket = min(23, Int(hue * 24))
            weight[bucket] += chroma
            hueSum[bucket] += hue * chroma
            saturationSum[bucket] += chroma / high * chroma
        }
        let total = weight.reduce(0, +)
        guard !pixels.isEmpty, total / Double(pixels.count) >= 0.06,
              let best = weight.indices.max(by: { weight[$0] < weight[$1] }) else { return white }
        // Saturation is floored so washed-out covers still give a clear colour.
        return HSB(hue: hueSum[best] / weight[best],
                   saturation: max(0.55, saturationSum[best] / weight[best]), brightness: 1)
    }
}

/// Downloads the artwork, shrinks it to 32×32 and runs `AlbumColor.accent` on the pixels.
func albumAccent(from url: URL) async -> Color? {
    let side = 32
    guard let (data, _) = try? await URLSession.shared.data(from: url),
          let image = NSImage(data: data)?.cgImage(forProposedRect: nil, context: nil, hints: nil),
          let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
    guard let bytes = context.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
    let pixels = (0..<side * side).map { i in
        AlbumColor.RGB(r: Double(bytes[i * 4]) / 255, g: Double(bytes[i * 4 + 1]) / 255, b: Double(bytes[i * 4 + 2]) / 255)
    }
    let c = AlbumColor.accent(for: pixels)
    return Color(hue: c.hue, saturation: c.saturation, brightness: c.brightness)
}
