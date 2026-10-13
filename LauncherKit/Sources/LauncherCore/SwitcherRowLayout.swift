import Foundation

/// Where the switcher's icons and highlight sit for a row of `iconCount` icons on a display `displayWidth` points
/// wide. Icons and gaps shrink by one factor when the row at full size would not fit the display, so every app shows
/// in one row. The panel positions icons and highlight through `centreX(at:)` alone, so they cannot drift apart.
public struct SwitcherRowLayout: Equatable, Sendable {
    public static let fullIconSide = 80.0
    public static let fullIconGap = 20.0
    public static let fullHighlightSide = 92.0
    public static let padding = 28.0

    public let iconCount: Int
    /// 1 when the row fits at full size; below 1 otherwise. A display width that is not positive means no constraint.
    public let scale: Double

    public init(iconCount: Int, displayWidth: Double) {
        self.iconCount = iconCount
        let full = Double(iconCount) * Self.fullIconSide + Double(max(iconCount - 1, 0)) * Self.fullIconGap
        if displayWidth > 0, full > 0 {
            scale = min(1, (displayWidth - 2 * Self.padding) / full)
        } else {
            scale = 1
        }
    }

    public var iconSide: Double { Self.fullIconSide * scale }
    public var iconGap: Double { Self.fullIconGap * scale }
    /// Distance between icon centres, and so the highlight's travel per icon.
    public var pitch: Double { iconSide + iconGap }
    public var highlightSide: Double { Self.fullHighlightSide * scale }
    public var rowWidth: Double { Double(iconCount) * iconSide + Double(max(iconCount - 1, 0)) * iconGap }
    public var panelWidth: Double { rowWidth + 2 * Self.padding }

    /// The horizontal centre, from the panel's left edge, of a position counted in icons from the first.
    public func centreX(at position: Double) -> Double {
        Self.padding + iconSide / 2 + position * pitch
    }
}
