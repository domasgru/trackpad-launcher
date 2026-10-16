import Foundation

/// Where the window switcher's rows and highlight sit: one column of `rowCount` rows on a display whose visible frame
/// is `displayHeight` points tall. The column fits when the panel's height plus `margin` above and below it is at most
/// `displayHeight`; when it would not, rows, gaps, padding and fonts shrink by the one factor that makes it fit. The
/// panel positions rows and highlight through `rowTop(at:)` alone, so they cannot drift apart.
public struct WindowColumnLayout: Equatable, Sendable {
    public static let margin = 12.0, panelPadding = 8.0, rowGap = 2.0, rowInset = 6.0
    public static let previewWidth = 120.0, previewHeight = 60.0, iconSide = 44.0, titleGap = 12.0
    public static let minTitleWidth = 180.0, maxTitleWidth = 320.0, titleSize = 13.0
    /// A row at full size: the preview slot with its inset above and below.
    public static let fullRowHeight = previewHeight + 2 * rowInset

    public let rowCount: Int
    /// 1 when the column fits at full size, otherwise below 1. A display height that is not positive means no
    /// constraint.
    public let scale: Double
    /// The title column's width at full size: the widest title, within its bounds.
    private let fullTitleWidth: Double

    /// `widestTitle`: the widest title measured at full size.
    public init(rowCount: Int, widestTitle: Double, displayHeight: Double) {
        self.rowCount = rowCount
        fullTitleWidth = min(max(widestTitle, Self.minTitleWidth), Self.maxTitleWidth)
        let full = Self.fullPanelHeight(rowCount: rowCount)
        scale = displayHeight > 0 && full > 0 ? min(1, (displayHeight - 2 * Self.margin) / full) : 1
    }

    private static func fullPanelHeight(rowCount: Int) -> Double {
        2 * panelPadding + Double(rowCount) * fullRowHeight + Double(max(rowCount - 1, 0)) * rowGap
    }

    public var rowHeight: Double { Self.fullRowHeight * scale }
    /// Row height plus gap: the highlight's travel per row.
    public var pitch: Double { (Self.fullRowHeight + Self.rowGap) * scale }
    public var padding: Double { Self.panelPadding * scale }
    public var inset: Double { Self.rowInset * scale }
    /// The preview slot, which holds a picture or the app icon centred.
    public var slot: (width: Double, height: Double) { (Self.previewWidth * scale, Self.previewHeight * scale) }
    public var icon: Double { Self.iconSide * scale }
    public var titleLeading: Double { inset + slot.width + Self.titleGap * scale }
    public var titleWidth: Double { fullTitleWidth * scale }
    public var fontSize: Double { Self.titleSize * scale }

    public var panelSize: (width: Double, height: Double) {
        let width = 2 * Self.panelPadding + 2 * Self.rowInset + Self.previewWidth + Self.titleGap + fullTitleWidth
        return (width * scale, Self.fullPanelHeight(rowCount: rowCount) * scale)
    }

    /// The top of a row, measured down from the panel's top edge, for a position counted in rows.
    public func rowTop(at position: Double) -> Double {
        padding + position * pitch
    }

    /// A picture of a window `aspect` (width ÷ height) wide, in the slot: 60 pt tall, or less when 120 pt wide would
    /// not hold it, times `scale`. The slot stays 120 pt wide, so titles never move when a picture lands.
    public func previewSize(aspect: Double) -> (width: Double, height: Double) {
        guard aspect > 0 else { return slot }
        let full = aspect * Self.previewHeight <= Self.previewWidth
            ? (Self.previewHeight * aspect, Self.previewHeight)
            : (Self.previewWidth, Self.previewWidth / aspect)
        return (full.0 * scale, full.1 * scale)
    }

    /// The largest picture worth capturing, in pixels at a display's backing `scale`.
    public func previewPixels(scale backing: Double) -> (width: Int, height: Int) {
        (Int((slot.width * backing).rounded(.up)), Int((slot.height * backing).rounded(.up)))
    }
}
