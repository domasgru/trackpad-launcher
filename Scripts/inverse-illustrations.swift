#!/usr/bin/env swift
// Draws the left hand's copy of each gesture illustration: assets/<name>.png, exported from Figma with the thumb
// top-left (right hand), becomes assets/<name>-inverse.png with the thumb top-right.
// Only the marks are mirrored. The paper card is lit from one side, so a mirrored card would light the left-hand
// copies from the other. The marks are pure black on the card, so each pixel is card × (1 − coverage): the card behind
// a mark is filled in smoothly from the card around it, the coverage is 1 − pixel ÷ card, and the copy is the
// card × (1 − mirrored coverage).
//
// Usage: swift Scripts/inverse-illustrations.swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let names = ["gesture-1", "gesture-2", "gesture-3", "gesture-4", "gesture-5", "swipe", "window-swipe", "thumb-tap"]
let assets = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("assets")

/// The card's rim is darker than its face; the marks sit well inside it.
let rim = 5
/// Darker than any of the card's face: the solid part of a mark.
let markLuminance = 180.0
/// How far a mark's antialiased edge reaches past its solid part, in pixels.
let markEdge = 2

struct Bitmap {
    let width: Int, height: Int
    var pixels: [UInt8]  // RGBA, premultiplied; every pixel the marks touch is opaque.
    let colorSpace: CGColorSpace
    let dpi: Double

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

/// The pixels a mark covers, solid or antialiased.
func markMask(_ image: Bitmap) -> [Bool] {
    var solid = [Bool](repeating: false, count: image.width * image.height)
    for y in rim..<(image.height - rim) {
        for x in rim..<(image.width - rim) where image.luminance(x, y) < markLuminance {
            solid[y * image.width + x] = true
        }
    }
    var mask = solid
    for y in 0..<image.height {
        for x in 0..<image.width where solid[y * image.width + x] {
            for dy in -markEdge...markEdge {
                for dx in -markEdge...markEdge {
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

/// The card alone: each masked pixel settles to the average of its neighbours, the card's own gradient carried in
/// from the pixels around the mark.
func card(behind image: Bitmap, mask: [Bool]) -> Bitmap {
    var card = image
    let masked = mask.indices.filter { mask[$0] }
    for _ in 0..<4000 {
        for index in masked {
            let (x, y) = (index % image.width, index / image.width)
            for channel in 0..<3 {
                card[x, y, channel] =
                    (card[x - 1, y, channel] + card[x + 1, y, channel] + card[x, y - 1, channel]
                        + card[x, y + 1, channel]) / 4
            }
        }
    }
    return card
}

for name in names {
    let image = Bitmap(assets.appendingPathComponent("\(name).png"))
    let mask = markMask(image)
    let card = card(behind: image, mask: mask)
    var inverse = card
    for y in 0..<image.height {
        for x in 0..<image.width {
            let mirrored = image.width - 1 - x
            guard mask[y * image.width + mirrored] else { continue }
            let coverage = max(0, min(1, 1 - image.luminance(mirrored, y) / card.luminance(mirrored, y)))
            precondition(inverse[x, y, 3] == 255, "\(name): a mirrored mark falls off the card at \(x), \(y)")
            for channel in 0..<3 { inverse[x, y, channel] = card[x, y, channel] * (1 - coverage) }
        }
    }
    inverse.write(assets.appendingPathComponent("\(name)-inverse.png"))
    print("assets/\(name)-inverse.png")
}
