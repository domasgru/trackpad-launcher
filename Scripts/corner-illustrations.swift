#!/usr/bin/env swift
// Draws the derived copies of the small illustrations. assets/<name>.png is drawn by hand with the thumb top-left;
// the script never writes it. It becomes assets/<name>-inverse.png with the thumb top-right (marks mirrored left to
// right), assets/<name>-bottom.png with the thumb bottom-left (marks mirrored top to bottom) and
// assets/<name>-bottom-inverse.png with the thumb bottom-right (mirrored both ways). The 2- to 5-finger gestures also
// get assets/<name>-no-thumb.png: the top-left file with its thumb, the mark nearest the top-left corner, replaced by
// the card behind it, so the fingers stay where they are drawn.
// Only the marks are mirrored. The paper card is lit from one side, so a mirrored card would light the copies
// from another. The marks are dark grey with a translucent ring, so each pixel is card × (1 − coverage): the card
// behind a mark is filled in smoothly from the card around it, the coverage is 1 − pixel ÷ card, and each copy is the
// card × (1 − mirrored coverage). Lengths are measured in points and scaled by the file's pixels per point.
//
// Usage: swift Scripts/corner-illustrations.swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let names = ["gesture-2", "gesture-3", "gesture-4", "gesture-5", "swipe", "window-swipe", "thumb-tap"]
/// The pictures that also get a copy without the thumb.
let thumblessNames: Set<String> = ["gesture-2", "gesture-3", "gesture-4", "gesture-5"]
/// The file suffix of each derived copy, and the directions its marks are mirrored in.
let copies: [(suffix: String, mirrorX: Bool, mirrorY: Bool)] = [
    ("-inverse", true, false), ("-bottom", false, true), ("-bottom-inverse", true, true),
]
let assets = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("assets")

/// The card's shaded rim is 1.25 pt wide and its rounded corners leave pixels as dark as 203 inside 1.25 pt; from 1.5 pt
/// none is left, and the nearest mark is 2.5 pt from the card's edge.
let rimPoints = 2.0
/// Darker than the card's face (never below 213 of 255) and lighter than the inside of a ring (170 to 200): the
/// solid part of a mark.
let markLuminance = 205.0
/// How far a mark's antialiased edge reaches past its solid part, in points.
let markEdgePoints = 1.0
/// The largest change of a card pixel in one pass under which the fill has settled.
let settled = 0.005

struct Bitmap {
    let width: Int, height: Int
    var pixels: [UInt8]  // RGBA, premultiplied; every pixel the marks touch is opaque.
    let colorSpace: CGColorSpace
    let dpi: Double
    var pixelsPerPoint: Double { dpi / 72 }
    var rim: Int { Int((rimPoints * pixelsPerPoint).rounded()) }
    var markEdge: Int { Int((markEdgePoints * pixelsPerPoint).rounded()) }

    init(_ url: URL) {
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as! [CFString: Any]
        width = image.width
        height = image.height
        let space = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        colorSpace = space
        dpi = properties[kCGImagePropertyDPIWidth] as? Double ?? 72
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        pixels.withUnsafeMutableBytes { bytes in
            Self.context(bytes.baseAddress!, image.width, image.height, space)
                .draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        self.pixels = pixels
    }

    static func context(_ data: UnsafeMutableRawPointer, _ width: Int, _ height: Int, _ space: CGColorSpace)
        -> CGContext
    {
        CGContext(
            data: data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    }

    subscript(x: Int, y: Int, channel: Int) -> Double {
        get { Double(pixels[(y * width + x) * 4 + channel]) }
        set { pixels[(y * width + x) * 4 + channel] = UInt8(max(0, min(255, newValue.rounded()))) }
    }

    func luminance(_ x: Int, _ y: Int) -> Double { (self[x, y, 0] + self[x, y, 1] + self[x, y, 2]) / 3 }

    func write(_ url: URL) {
        var pixels = pixels
        let image = pixels.withUnsafeMutableBytes { Self.context($0.baseAddress!, width, height, colorSpace).makeImage()! }
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(
            destination, image, [kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi] as CFDictionary)
        precondition(CGImageDestinationFinalize(destination), "could not write \(url.path)")
    }
}

/// The marks of a picture: the pixels they cover, solid or antialiased, and which of them are the thumb's.
struct Marks {
    var mask: [Bool]
    var thumb: [Bool]
}

func marks(_ image: Bitmap) -> Marks {
    let (width, height, rim, edge) = (image.width, image.height, image.rim, image.markEdge)
    var solid = [Bool](repeating: false, count: width * height)
    for y in rim..<(height - rim) {
        for x in rim..<(width - rim) where image.luminance(x, y) < markLuminance { solid[y * width + x] = true }
    }
    // The solid parts, grouped into the connected marks; the thumb is the one with a pixel nearest the top-left corner.
    var label = [Int](repeating: -1, count: width * height)
    var count = 0
    var nearest: (label: Int, distance: Int) = (-1, Int.max)
    for start in solid.indices where solid[start] && label[start] < 0 {
        label[start] = count
        var stack = [start]
        while let index = stack.popLast() {
            let (x, y) = (index % width, index / width)
            if x * x + y * y < nearest.distance { nearest = (count, x * x + y * y) }
            for dy in -1...1 {
                for dx in -1...1 {
                    let (nx, ny) = (x + dx, y + dy)
                    guard nx >= 0, ny >= 0, nx < width, ny < height, solid[ny * width + nx], label[ny * width + nx] < 0
                    else { continue }
                    label[ny * width + nx] = count
                    stack.append(ny * width + nx)
                }
            }
        }
        count += 1
    }
    // Each antialiased pixel belongs to the nearest solid pixel's mark.
    var mask = solid
    var thumb = [Bool](repeating: false, count: width * height)
    var closest = [Int](repeating: Int.max, count: width * height)
    for y in 0..<height {
        for x in 0..<width where solid[y * width + x] {
            for dy in -edge...edge {
                for dx in -edge...edge {
                    let (nx, ny) = (x + dx, y + dy)
                    guard nx >= rim, ny >= rim, nx < width - rim, ny < height - rim else { continue }
                    let distance = max(abs(dx), abs(dy))
                    if distance < closest[ny * width + nx] {
                        closest[ny * width + nx] = distance
                        mask[ny * width + nx] = true
                        thumb[ny * width + nx] = label[y * width + x] == nearest.label
                    }
                }
            }
        }
    }
    return Marks(mask: mask, thumb: thumb)
}

/// The card alone: each masked pixel settles to the average of its neighbours, the card's own gradient carried in
/// from the pixels around the mark, until a pass changes none by more than `settled`.
func card(behind image: Bitmap, mask: [Bool]) -> Bitmap {
    var values = image.pixels.map(Double.init)
    let masked = mask.indices.filter { mask[$0] }
    var change = Double.infinity
    while change > settled {
        change = 0
        for index in masked {
            for channel in 0..<3 {
                let at = index * 4 + channel
                let average =
                    (values[at - 4] + values[at + 4] + values[at - image.width * 4] + values[at + image.width * 4]) / 4
                change = max(change, abs(average - values[at]))
                values[at] = average
            }
        }
    }
    var card = image
    for index in masked {
        for channel in 0..<3 { card.pixels[index * 4 + channel] = UInt8(max(0, min(255, values[index * 4 + channel].rounded()))) }
    }
    return card
}

for name in names {
    let image = Bitmap(assets.appendingPathComponent("\(name).png"))
    let found = marks(image)
    let mask = found.mask
    let card = card(behind: image, mask: mask)
    for (suffix, mirrorX, mirrorY) in copies {
        var copy = card
        for y in 0..<image.height {
            for x in 0..<image.width {
                let (sx, sy) = (mirrorX ? image.width - 1 - x : x, mirrorY ? image.height - 1 - y : y)
                guard mask[sy * image.width + sx] else { continue }
                let coverage = max(0, min(1, 1 - image.luminance(sx, sy) / card.luminance(sx, sy)))
                precondition(copy[x, y, 3] == 255, "\(name)\(suffix): a mirrored mark falls off the card at \(x), \(y)")
                for channel in 0..<3 { copy[x, y, channel] = card[x, y, channel] * (1 - coverage) }
            }
        }
        copy.write(assets.appendingPathComponent("\(name)\(suffix).png"))
        print("assets/\(name)\(suffix).png")
    }
    if thumblessNames.contains(name) {
        var thumbless = image
        for index in found.thumb.indices where found.thumb[index] {
            for channel in 0..<3 { thumbless.pixels[index * 4 + channel] = card.pixels[index * 4 + channel] }
        }
        thumbless.write(assets.appendingPathComponent("\(name)-no-thumb.png"))
        print("assets/\(name)-no-thumb.png")
    }
}
