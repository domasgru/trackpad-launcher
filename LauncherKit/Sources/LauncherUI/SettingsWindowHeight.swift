import CoreGraphics

/// How tall the settings window may be: at most `maxShare` of the display's visible area, title bar included.
enum SettingsWindowHeight {
    nonisolated static let maxShare: CGFloat = 0.9

    /// The content height to set: the content's fitting height, or what is left of the cap under the title bar,
    /// whichever is smaller.
    nonisolated static func contentHeight(fitting: CGFloat, titleBar: CGFloat, visible: CGFloat) -> CGFloat {
        min(fitting, visible * maxShare - titleBar)
    }

    /// The content width to set: the content's own width, plus the room of a legacy scroller beside it while the window
    /// is capped, so the scroller never takes from the content. `scrollerWidth` is the legacy scroller's width, and 0
    /// for the overlay style, which takes none.
    nonisolated static func contentWidth(fitting: CGFloat, isCapped: Bool, scrollerWidth: CGFloat) -> CGFloat {
        isCapped ? fitting + scrollerWidth : fitting
    }
}
