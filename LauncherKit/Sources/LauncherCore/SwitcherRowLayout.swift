import Foundation

/// Where the switcher's panel, icons and highlight sit for a row of `iconCount` icons on a display `displayWidth`
/// points wide. `padding` is the gap between the panel's edge and the highlight's edge on all four sides. Icons and
/// gaps shrink by one factor when the row at full size would not fit the display, so every app shows in one row. The
/// panel positions icons and highlight through `centreX(at:)` and `centreY` alone, so they cannot drift apart.
public struct SwitcherRowLayout: Equatable, Sendable {
    public static let fullIconSide = 80.0
    public static let fullIconGap = 20.0
    public static let fullHighlightSide = 92.0
    public static let padding = 22.0
    /// How much larger the selected icon is drawn than the others; it stays inside the highlight.
    public static let selectedIconScale = 1.12

    public let iconCount: Int
    /// 1 when the row fits at full size; below 1 otherwise. A display width that is not positive means no constraint.
    public let scale: Double

    public init(iconCount: Int, displayWidth: Double) {
        self.iconCount = iconCount
        if displayWidth > 0 {
            scale = min(1, (displayWidth - 2 * Self.padding) / Self.fullSpan(iconCount: iconCount))
        } else {
            scale = 1
        }
    }

    /// First highlight's left edge to the last one's right edge, at full size.
    private static func fullSpan(iconCount: Int) -> Double {
        Double(max(iconCount - 1, 0)) * (fullIconSide + fullIconGap) + fullHighlightSide
    }

    public var iconSide: Double { Self.fullIconSide * scale }
    public var iconGap: Double { Self.fullIconGap * scale }
    /// Distance between icon centres, and so the highlight's travel per icon.
    public var pitch: Double { iconSide + iconGap }
    public var highlightSide: Double { Self.fullHighlightSide * scale }

    public var panelSize: (width: Double, height: Double) {
        (2 * Self.padding + Self.fullSpan(iconCount: iconCount) * scale, 2 * Self.padding + highlightSide)
    }

    /// The horizontal centre, from the panel's left edge, of a position counted in icons from the first.
    public func centreX(at position: Double) -> Double {
        Self.padding + highlightSide / 2 + position * pitch
    }

    /// The vertical centre of icons and highlight: half the panel's height.
    public var centreY: Double { panelSize.height / 2 }
}

/// Where a window stack's copies sit behind an icon of `row`'s size, from the icon's centre, y up. The front icon is the
/// lone icon unchanged, so the row's spacing, the highlight and the panel stay as they are; copies grow with the
/// selected icon because they live in its slot, whose transform the panel scales.
public struct WindowStackLayout: Equatable, Sendable {
    /// Each copy's side as a share of the icon's, nearest first. `copyScales.count == WindowStack.maxIcons - 1`.
    public static let copyScales = [0.92, 0.84, 0.76]
    /// How far each copy's top edge peeks above the top edge of the one in front of it, at full size.
    public static let fullPeek = 6.0
    /// The rise: seconds, the delay between neighbouring copies, and a soft ease-out as cubic Bézier control points.
    public static let riseDuration = 0.3
    public static let riseStagger = 0.04
    public static let riseCurve: (Double, Double, Double, Double) = (0.25, 1.0, 0.5, 1.0)

    public let row: SwitcherRowLayout

    public init(row: SwitcherRowLayout) { self.row = row }

    public struct Copy: Equatable, Sendable {
        /// Side, in points: `row.iconSide × copyScales[k]`.
        public let side: Double
        /// Centre at rest above the icon's centre: `fullPeek × (k + 1) × row.scale + (row.iconSide − side) / 2`.
        public let rise: Double
        /// Seconds after the stack appears that this copy starts rising: `riseStagger × k`, the nearest first.
        public let delay: Double
    }

    /// Nearest first: one per copy of `stack`.
    public func copies(of stack: WindowStack) -> [Copy] {
        Self.copyScales.prefix(stack.copies).enumerated().map { index, share in
            let side = row.iconSide * share
            return Copy(
                side: side, rise: Self.fullPeek * Double(index + 1) * row.scale + (row.iconSide - side) / 2,
                delay: Self.riseStagger * Double(index))
        }
    }
}
