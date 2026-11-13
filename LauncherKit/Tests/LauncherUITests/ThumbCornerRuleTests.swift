import CoreGraphics
import Foundation
import ImageIO
import LauncherCore
import Testing
@testable import LauncherUI

@Suite struct CornerIllustrationFileTests {
    nonisolated static let smallNames = [
        "gesture-2", "gesture-3", "gesture-4", "gesture-5", "swipe", "window-swipe", "thumb-tap",
    ]
    nonisolated static let gestureNames = ["gesture-2", "gesture-3", "gesture-4", "gesture-5"]
    nonisolated static let otherCorners: [ThumbCorner] = [.topRight, .bottomLeft, .bottomRight]

    nonisolated struct Case: Sendable, CustomTestStringConvertible {
        let name: String
        let corner: ThumbCorner
        var testDescription: String { "\(name) \(corner)" }
    }

    nonisolated static let cases = smallNames.flatMap { name in otherCorners.map { Case(name: name, corner: $0) } }

    /// `Tests/LauncherUITests/<this file>` is four levels below the repository root.
    nonisolated static let assets = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appending(path: "assets")

    nonisolated static func bitmap(_ name: String, thumb: ThumbCorner?) throws -> Bitmap {
        try Bitmap(assets.appending(path: Illustration.file(name, thumb: thumb) + ".png"))
    }

    nonisolated struct Bitmap {
        let width: Int, height: Int
        var pixels: [UInt8]
        /// The small pictures are 45 pt wide.
        var pixelsPerPoint: Double { Double(width) / 45 }

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
        func differs(from other: Bitmap, _ x: Int, _ y: Int) -> Bool {
            (0..<4).contains { abs(channel(x, y, $0) - other.channel(x, y, $0)) > 1 }
        }
    }

    /// Luminance below 205 (the card's face is never darker than 213, a ring's inside never lighter than 200) inside a
    /// 2 pt rim, grown by 1 pt.
    nonisolated static func markMask(_ image: Bitmap) -> [Bool] {
        let rim = Int((2 * image.pixelsPerPoint).rounded())
        let edge = Int(image.pixelsPerPoint.rounded())
        var solid = [Bool](repeating: false, count: image.width * image.height)
        for y in rim..<(image.height - rim) {
            for x in rim..<(image.width - rim) where image.luminance(x, y) < 205 { solid[y * image.width + x] = true }
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

    /// The smallest box holding every pixel where the two pictures differ, nil when they do not.
    nonisolated static func differenceBox(_ a: Bitmap, _ b: Bitmap) -> (x: ClosedRange<Int>, y: ClosedRange<Int>)? {
        var xs: ClosedRange<Int>?, ys: ClosedRange<Int>?
        for y in 0..<a.height {
            for x in 0..<a.width where a.differs(from: b, x, y) {
                xs = min(xs?.lowerBound ?? x, x)...max(xs?.upperBound ?? x, x)
                ys = min(ys?.lowerBound ?? y, y)...max(ys?.upperBound ?? y, y)
            }
        }
        guard let xs, let ys else { return nil }
        return (xs, ys)
    }

    @Test(arguments: cases)
    func theCornerPictureIsTheTopLeftOneWithItsMarksMirrored(_ c: Case) throws {
        let original = try Self.bitmap(c.name, thumb: .topLeft)
        let derived = try Self.bitmap(c.name, thumb: c.corner)
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
                if !mirroredMark && !originalMask[y * w + x] && derived.differs(from: original, x, y) {
                    cardDiffers += 1
                }
            }
        }
        #expect(cardDiffers == 0, "\(cardDiffers) card pixels changed outside the marks")
        #expect(Double(maskDiffers) < 0.02 * Double(maskPixels), "\(maskDiffers) of \(maskPixels) mark pixels differ")
    }

    @Test(arguments: smallNames)
    func aSmallPictureIsAWholeNumberOfPixelsPerPoint(_ name: String) throws {
        let image = try Self.bitmap(name, thumb: .topLeft)
        let scale = image.width / 45
        #expect(scale >= 2)
        #expect(image.width == 45 * scale && image.height == 28 * scale, "\(image.width) x \(image.height) px")
    }

    @Test func theFirstGesturesPicturesShowTheThumbInEachCornerAndNoneWithoutIt() throws {
        let none = try Self.bitmap("gesture-1", thumb: nil)
        // The hand-drawn versions line up to a few pixels, not exactly; this is 2% of the picture's width.
        let tolerance = none.width / 50
        var centres: [ThumbCorner: (x: Int, y: Int)] = [:]
        for corner in ThumbCorner.allCases {
            let image = try Self.bitmap("gesture-1", thumb: corner)
            try #require(image.width == none.width && image.height == none.height, "\(corner) size")
            let box = try #require(Self.differenceBox(image, none), "\(corner) differs from no thumb")
            #expect(box.x.count <= none.width / 10 && box.y.count <= none.width / 10, "\(corner): one patch")
            let centre = ((box.x.lowerBound + box.x.upperBound) / 2, (box.y.lowerBound + box.y.upperBound) / 2)
            #expect(image.luminance(centre.0, centre.1) < 128, "\(corner): dark at the thumb")
            #expect(none.luminance(centre.0, centre.1) > 200, "\(corner): light without the thumb")
            centres[corner] = centre
        }
        let (tl, tr) = (try #require(centres[.topLeft]), try #require(centres[.topRight]))
        let (bl, br) = (try #require(centres[.bottomLeft]), try #require(centres[.bottomRight]))
        #expect(abs(tl.x - bl.x) <= tolerance && abs(tr.x - br.x) <= tolerance, "left and right thumbs share x")
        #expect(tl.x + tolerance < tr.x && bl.x + tolerance < br.x, "the left thumbs are left of the right ones")
        #expect(abs(tl.y - tr.y) <= tolerance && abs(bl.y - br.y) <= tolerance, "top and bottom thumbs share y")
        #expect(tl.y + tolerance < bl.y && tr.y + tolerance < br.y, "the top thumbs are above the bottom ones")
    }

    @Test(arguments: gestureNames)
    func theNoThumbPictureIsTheTopLeftOneWithoutItsThumb(_ name: String) throws {
        let withThumb = try Self.bitmap(name, thumb: .topLeft)
        let without = try Self.bitmap(name, thumb: nil)
        try #require(withThumb.width == without.width && withThumb.height == without.height)
        // The thumb's dot lies 7.6 pt from the card's left and top edges.
        let scale = withThumb.pixelsPerPoint
        let centre = 7.6 * scale, reach = 6 * scale
        func distance(_ x: Int, _ y: Int) -> Double {
            let (dx, dy) = (Double(x) + 0.5 - centre, Double(y) + 0.5 - centre)
            return (dx * dx + dy * dy).squareRoot()
        }
        var outside = 0, darkest = 255.0
        for y in 0..<withThumb.height {
            for x in 0..<withThumb.width {
                if distance(x, y) <= reach { darkest = min(darkest, without.luminance(x, y)) }
                if withThumb.differs(from: without, x, y), distance(x, y) > reach { outside += 1 }
            }
        }
        #expect(outside == 0, "\(outside) pixels differ beyond 6 pt of the thumb")
        #expect(darkest >= 205, "a mark is left at the thumb: \(darkest)")
        let box = try #require(Self.differenceBox(withThumb, without))
        #expect(withThumb.differs(from: without, Int(centre), Int(centre)), "the thumb's centre changed")
        #expect(Double(box.x.count) >= 6 * scale && Double(box.y.count) >= 6 * scale, "the thumb is cleared across")
    }
}
