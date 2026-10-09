import AppKit

/// Template images for light and dark menu bars. Inactive is the same symbol with a diagonal stroke drawn once:
/// SF Symbols has no slashed variant of this hand, so the slash is knocked out around a solid stroke.
enum StatusIcon {
    private static let symbolName = "hand.tap"

    static func image(active: Bool) -> NSImage {
        let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) ?? NSImage()
        symbol.isTemplate = true
        guard !active else { return symbol }

        let size = symbol.size
        let slashed = NSImage(size: size, flipped: false) { rect in
            symbol.draw(in: rect)
            let slash = NSBezierPath()
            slash.move(to: NSPoint(x: rect.minX + 2, y: rect.maxY - 2))
            slash.line(to: NSPoint(x: rect.maxX - 2, y: rect.minY + 2))
            slash.lineCapStyle = .round
            NSGraphicsContext.current?.compositingOperation = .clear
            slash.lineWidth = 4.5
            slash.stroke()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            slash.lineWidth = 1.5
            NSColor.black.setStroke()
            slash.stroke()
            return true
        }
        slashed.isTemplate = true
        return slashed
    }
}
