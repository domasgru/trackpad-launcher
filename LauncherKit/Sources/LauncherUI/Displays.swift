import AppKit

enum Displays {
    /// AppKit's own rule for which display holds the pointer; the nearest display when none does.
    static func screen(under pointer: NSPoint) -> NSScreen? {
        let screens = NSScreen.screens
        return screens.first { NSMouseInRect(pointer, $0.frame, false) }
            ?? screens.min { distance(from: pointer, to: $0.frame) < distance(from: pointer, to: $1.frame) }
    }

    private static func distance(from point: NSPoint, to rect: NSRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return (dx * dx + dy * dy).squareRoot()
    }
}
