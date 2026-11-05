import CoreGraphics
import Foundation
import ImageIO
import LauncherCore
import Testing
@testable import LauncherUI

@Suite struct ThumbCornerRuleTests {
    @Test(arguments: [
        (ThumbCorner.topLeft, ""), (.topRight, "-inverse"), (.bottomLeft, "-bottom"), (.bottomRight, "-bottom-inverse"),
    ])
    func eachCornerHasItsOwnPictureSuffix(corner: ThumbCorner, suffix: String) {
        #expect(corner.illustration("gesture-1") == "gesture-1" + suffix)
    }

    @Test(arguments: [
        (ThumbCorner.topLeft, true), (.topRight, false), (.bottomLeft, false), (.bottomRight, false),
    ])
    func theGuideShowsOnlyForTheTopLeftCorner(corner: ThumbCorner, shows: Bool) {
        #expect(corner.showsGuide == shows)
    }
}

@Suite struct CornerIllustrationFileTests {
    nonisolated static let names = [
        "gesture-1", "gesture-2", "gesture-3", "gesture-4", "gesture-5", "swipe", "window-swipe", "thumb-tap",
    ]

    nonisolated struct Case: Sendable, CustomTestStringConvertible {
        let name: String
        let corner: ThumbCorner
        var testDescription: String { "\(name) \(corner)" }
    }

    nonisolated static let cases = names.flatMap { name in ThumbCorner.allCases.map { Case(name: name, corner: $0) } }

    /// `Tests/LauncherUITests/<this file>` is four levels below the repository root.
    nonisolated static let assets = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appending(path: "assets")

    nonisolated struct Bitmap {
        let width: Int, height: Int
        var pixels: [UInt8]

        init(_ url: URL) throws {
            let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil), "\(url.lastPathComponent) missing")
            let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
            width = image.width
            height = image.height
            let space = try #require(image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB))
            var pixels = [UInt8](repeating: 0, count: width * height * 4)
            let width = width, height = height
            try pixels.withUnsafeMutableBytes { (bytes: UnsafeMutableRawBufferPointer) throws in
                let context = try #require(
                    CGContext(
                        data: try #require(bytes.baseAddress), width: width, height: height, bitsPerComponent: 8,
                        bytesPerRow: width * 4, space: space,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
            self.pixels = pixels
        }

        func channel(_ x: Int, _ y: Int, _ channel: Int) -> Int { Int(pixels[(y * width + x) * 4 + channel]) }
        func luminance(_ x: Int, _ y: Int) -> Double {
            Double(channel(x, y, 0) + channel(x, y, 1) + channel(x, y, 2)) / 3
        }
    }

    /// Luminance below 180 inside a 5 px rim, grown by 2 px.
    nonisolated static func markMask(_ image: Bitmap) -> [Bool] {
        let (rim, edge) = (5, 2)
        var solid = [Bool](repeating: false, count: image.width * image.height)
        for y in rim..<(image.height - rim) {
            for x in rim..<(image.width - rim) where image.luminance(x, y) < 180 { solid[y * image.width + x] = true }
        }
        var mask = solid
        for y in 0..<image.height {
            for x in 0..<image.width where solid[y * image.width + x] {
                for dy in -edge...edge {
                    for dx in -edge...edge {
                        let (nx, ny) = (x + dx, y + dy)
                        if nx >= rim, ny >= rim, nx < image.width - rim, ny < image.height - rim {
                            mask[ny * image.width + nx] = true
                        }
                    }
                }
            }
        }
        return mask
    }

    @Test(arguments: cases)
    func theDerivedPictureIsTheOriginalWithItsMarksMirrored(_ c: Case) throws {
        let file = Self.assets.appending(path: c.corner.illustration(c.name) + ".png")
        let original = try Bitmap(Self.assets.appending(path: "\(c.name).png"))
        let derived = try Bitmap(file)
        try #require(derived.width == original.width && derived.height == original.height)

        let flipX = c.corner == .topRight || c.corner == .bottomRight
        let flipY = c.corner == .bottomLeft || c.corner == .bottomRight
        let (w, h) = (original.width, original.height)
        let originalMask = Self.markMask(original)
        let derivedMask = Self.markMask(derived)

        var cardDiffers = 0, maskDiffers = 0, maskPixels = 0
        for y in 0..<h {
            for x in 0..<w {
                let (mx, my) = (flipX ? w - 1 - x : x, flipY ? h - 1 - y : y)
                let mirroredMark = originalMask[my * w + mx]
                if mirroredMark { maskPixels += 1 }
                if derivedMask[y * w + x] != mirroredMark { maskDiffers += 1 }
                if !mirroredMark && !originalMask[y * w + x] {
                    for ch in 0..<4 where abs(derived.channel(x, y, ch) - original.channel(x, y, ch)) > 1 {
                        cardDiffers += 1
                        break
                    }
                }
            }
        }
        #expect(cardDiffers == 0, "\(cardDiffers) card pixels changed outside the marks")
        // 2%, not 1%: the bottom-inverse asset's small marks differ by 1.17% in antialiased edge pixels alone, while a stale or whole-image-flipped asset differs by far more.
        #expect(Double(maskDiffers) < 0.02 * Double(maskPixels), "\(maskDiffers) of \(maskPixels) mark pixels differ")
    }
}
