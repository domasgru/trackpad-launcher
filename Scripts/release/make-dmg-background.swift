#!/usr/bin/env swift
// Draws the disk image's drag cue: a 600x400 pt window background rendered at
// 2x (1200x800 px, 144 dpi) so Finder shows it at window size and sharp on Retina.
// Usage: swift Scripts/release/make-dmg-background.swift [output.png]
import AppKit

let pointSize = NSSize(width: 600, height: 400)
let scale = 2
let output = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Scripts/release/dmg-background.png"

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(pointSize.width) * scale,
    pixelsHigh: Int(pointSize.height) * scale,
    bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
), let context = NSGraphicsContext(bitmapImageRep: rep) else {
    FileHandle.standardError.write(Data("cannot create bitmap\n".utf8))
    exit(1)
}
rep.size = pointSize

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.cgContext.scaleBy(x: CGFloat(scale), y: CGFloat(scale))

NSColor(calibratedWhite: 0.97, alpha: 1).setFill()
NSRect(origin: .zero, size: pointSize).fill()

// Icons sit 190 pt from the top (Finder coordinates), i.e. 210 pt from the bottom here.
let arrowY: CGFloat = 210
let startX: CGFloat = 235
let endX: CGFloat = 365
let color = NSColor(calibratedWhite: 0.55, alpha: 1)
color.setStroke()
color.setFill()

let shaft = NSBezierPath()
shaft.lineWidth = 6
shaft.lineCapStyle = .round
shaft.move(to: NSPoint(x: startX, y: arrowY))
shaft.line(to: NSPoint(x: endX - 10, y: arrowY))
shaft.stroke()

let head = NSBezierPath()
head.move(to: NSPoint(x: endX, y: arrowY))
head.line(to: NSPoint(x: endX - 22, y: arrowY + 15))
head.line(to: NSPoint(x: endX - 22, y: arrowY - 15))
head.close()
head.fill()

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let text = NSAttributedString(
    string: "Drag to Applications",
    attributes: [
        .font: NSFont.systemFont(ofSize: 15, weight: .medium),
        .foregroundColor: color,
        .paragraphStyle: paragraph,
    ]
)
text.draw(in: NSRect(x: 0, y: 60, width: pointSize.width, height: 24))

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("cannot encode png\n".utf8))
    exit(1)
}
try png.write(to: URL(fileURLWithPath: output))
