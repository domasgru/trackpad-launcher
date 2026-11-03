import Foundation

/// A rectangle in panel points, y up from the panel's bottom.
public struct LiquidRect: Equatable, Sendable {
    public var minX, minY, width, height: Double

    public init(minX: Double, minY: Double, width: Double, height: Double) {
        self.minX = minX
        self.minY = minY
        self.width = width
        self.height = height
    }

    public var maxX: Double { minX + width }
    public var maxY: Double { minY + height }
    public var midX: Double { minX + width / 2 }
    public var midY: Double { minY + height / 2 }

    public static func centred(x: Double, y: Double, width: Double, height: Double) -> LiquidRect {
        LiquidRect(minX: x - width / 2, minY: y - height / 2, width: width, height: height)
    }

    /// `self` grown by `amount` on every side, same centre.
    public func grown(by amount: Double) -> LiquidRect {
        LiquidRect(minX: minX - amount, minY: minY - amount, width: width + 2 * amount, height: height + 2 * amount)
    }
}

/// The one geometry source: icons, band, beads and swell all hang off `centreX(at:)` and `scale`, so they cannot drift.
/// Every length scales by one factor when the row at full size would not fit the display.
public struct SwitcherRowLayout: Equatable, Sendable {
    public static let fullIconSide = 80.0, fullPitch = 100.0, selectedIconScale = 1.12

    public let iconCount: Int
    /// One snapshot per swipe.
    public let look: LiquidLook
    /// 1 when the row fits at full size; below 1 otherwise. A display width that is not positive means no constraint.
    public let scale: Double

    public init(iconCount: Int, displayWidth: Double, look: LiquidLook = .shipped) {
        self.iconCount = iconCount
        self.look = look
        let full = Self.fullWidth(iconCount: iconCount, look: look)
        scale = displayWidth > 0 ? min(1, displayWidth / full) : 1
    }

    private static func fullWidth(iconCount: Int, look: LiquidLook) -> Double {
        Double(max(iconCount, 1) - 1) * fullPitch + look.beadSide + 2 * look.room
    }

    public var iconSide: Double { Self.fullIconSide * scale }
    public var selectedIconBody: Double { look.iconBody * Self.selectedIconScale * scale }
    public var pitch: Double { Self.fullPitch * scale }

    /// The rise actually drawn: the look's, clamped to fit the room with the end pull.
    public var swellRise: Double {
        let ceiling = max(look.room - min(look.endPull, 0.2 * Self.fullPitch), 0)
        return min(max(look.swellRise, 0), ceiling) * scale
    }

    public var panelSize: (width: Double, height: Double) {
        (Self.fullWidth(iconCount: iconCount, look: look) * scale, (look.beadSide + 2 * look.room) * scale)
    }

    /// The horizontal centre, from the panel's left edge, of a position counted in icons from the first.
    public func centreX(at position: Double) -> Double {
        (look.room + look.beadSide / 2) * scale + position * pitch
    }

    /// The vertical centre of icons and band: half the panel's height.
    public var centreY: Double { panelSize.height / 2 }

    private var beadSide: Double { look.beadSide * scale }

    private func square(at index: Int) -> LiquidRect {
        .centred(x: centreX(at: Double(index)), y: centreY, width: beadSide, height: beadSide)
    }

    /// First icon centre to last, a capsule; with one icon, exactly its bead.
    public var band: LiquidRect {
        guard iconCount >= 2 else { return square(at: 0) }
        let first = centreX(at: 0), last = centreX(at: Double(iconCount - 1))
        return .centred(
            x: (first + last) / 2, y: centreY, width: last - first, height: look.bandThickness * scale)
    }

    /// An index past the icons is a spare, laid exactly over the band.
    public func bead(at index: Int) -> LiquidRect {
        index < iconCount ? square(at: index) : band
    }

    /// The bead grown by `swellRise` on every side.
    public func swell(at index: Int) -> LiquidRect {
        bead(at: index).grown(by: swellRise)
    }

    public var radii: (band: Double, bead: Double, swell: Double) {
        let bead = look.beadCorner * beadSide
        return (
            band: iconCount >= 2 ? look.bandThickness * scale / 2 : bead, bead: bead,
            swell: look.swellCorner * (beadSide + 2 * swellRise)
        )
    }

    public var spacing: Double { look.spacing * scale }

    /// How tall a wave may make a bead. It never leaves the bead within 4 pt of the icon at its largest, which is the
    /// selected icon's grown body: an icon may be growing or shrinking while a wave passes its bead.
    public var beadLimits: ClosedRange<Double> {
        let body = look.iconBody * Self.selectedIconScale
        return max(body + 4, look.bandThickness) * scale...(look.beadSide + 2 * min(look.waveMax, look.room)) * scale
    }
}
