import UIKit
import Vision

enum OCR {
    /// Finds each line of Chinese text, its exact position and its colours.
    static func recognize(_ image: UIImage) async -> [TextBlock] {
        guard let cg = image.cgImage else { return [] }
        return await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
                request.usesLanguageCorrection = true
                let handler = VNImageRequestHandler(cgImage: cg, options: [:])
                try? handler.perform([request])

                let sampler = ColorSampler(cg)
                let blocks: [TextBlock] = (request.results ?? []).compactMap { obs in
                    guard let text = obs.topCandidates(1).first?.string,
                          text.unicodeScalars.contains(where: isCJK) else { return nil }
                    let b = obs.boundingBox
                    let rect = CGRect(x: b.minX, y: 1 - b.maxY, width: b.width, height: b.height)
                    let colors = sampler?.colors(in: rect) ?? (UIColor.white, UIColor.black)
                    return TextBlock(original: text, rect: rect,
                                     background: colors.0, foreground: colors.1)
                }
                cont.resume(returning: blocks)
            }
        }
    }

    static func isCJK(_ s: Unicode.Scalar) -> Bool {
        (0x4E00...0x9FFF).contains(s.value) || (0x3400...0x4DBF).contains(s.value)
    }
}

/// Reads pixel colours so each translated box matches the screen underneath.
struct ColorSampler {
    let width: Int
    let height: Int
    let pixels: [UInt8]

    init?(_ cg: CGImage) {
        width = cg.width
        height = cg.height
        var buf = [UInt8](repeating: 0, count: width * height * 4)
        let w = width, h = height
        let ok: Bool = buf.withUnsafeMutableBytes { ptr in
            guard let ctx = CGContext(data: ptr.baseAddress, width: w, height: h,
                                      bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard ok else { return nil }
        pixels = buf
    }

    private func px(_ x: CGFloat, _ y: CGFloat) -> (Int, Int, Int) {
        let xi = min(max(Int(x), 0), width - 1)
        let yi = min(max(Int(y), 0), height - 1)
        let i = (yi * width + xi) * 4
        return (Int(pixels[i]), Int(pixels[i + 1]), Int(pixels[i + 2]))
    }

    /// Background = most common colour on the box edge; text = the inside colour most unlike it.
    func colors(in r: CGRect) -> (UIColor, UIColor) {
        let x = r.minX * CGFloat(width) - 3, y = r.minY * CGFloat(height) - 2
        let w = r.width * CGFloat(width) + 6, h = r.height * CGFloat(height) + 4
        var edge: [(Int, Int, Int)] = []
        for k in 0...12 {
            let t = CGFloat(k) / 12
            edge += [px(x + w * t, y + 1), px(x + w * t, y + h - 1), px(x + 1, y + h * t), px(x + w - 1, y + h * t)]
        }
        var buckets: [Int: (n: Int, r: Int, g: Int, b: Int)] = [:]
        for c in edge {
            let key = (c.0 >> 4) << 8 | (c.1 >> 4) << 4 | (c.2 >> 4)
            let cur = buckets[key] ?? (0, 0, 0, 0)
            buckets[key] = (cur.n + 1, cur.r + c.0, cur.g + c.1, cur.b + c.2)
        }
        let best = buckets.values.max { $0.n < $1.n }!
        let bg = (best.r / best.n, best.g / best.n, best.b / best.n)

        var fg = bg, far = 0
        for i in 1..<10 {
            for j in 1..<6 {
                let c = px(x + w * CGFloat(i) / 10, y + h * CGFloat(j) / 6)
                let d = abs(c.0 - bg.0) + abs(c.1 - bg.1) + abs(c.2 - bg.2)
                if d > far { far = d; fg = c }
            }
        }
        if far < 90 {
            let lum = (bg.0 * 2126 + bg.1 * 7152 + bg.2 * 722) / 10000
            fg = lum > 140 ? (20, 20, 20) : (250, 250, 250)
        }
        func ui(_ c: (Int, Int, Int)) -> UIColor {
            UIColor(red: CGFloat(c.0) / 255, green: CGFloat(c.1) / 255, blue: CGFloat(c.2) / 255, alpha: 1)
        }
        return (ui(bg), ui(fg))
    }
}
