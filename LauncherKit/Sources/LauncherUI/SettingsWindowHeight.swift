import CoreGraphics

/// How tall the settings window may be: at most `maxShare` of the display's visible area, title bar included.
enum SettingsWindowHeight {
    nonisolated static let maxShare: CGFloat = 0.9

    /// The content height to set: the content's fitting height, or what is left of the cap under the title bar,
    /// whichever is smaller.
    nonisolated static func contentHeight(fitting: CGFloat, titleBar: CGFloat, visible: CGFloat) -> CGFloat {
        min(fitting, visible * maxShare - titleBar)
    }
}
