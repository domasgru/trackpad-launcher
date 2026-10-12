import Foundation

/// Every fixed number in gesture recognition and click blocking, in one place. Not user-tunable.
package enum GestureRules {
    /// Fraction of the surface width, measured from the anchor-side edge.
    static let cornerWidth = 0.20
    /// Fraction of the surface height, measured from the top edge.
    static let cornerHeight = 0.25
    /// An anchored thumb may roll this far past the zone edge before it stops being the anchor.
    static let anchorReleaseMarginMM = 2.0
    /// First finger down to last finger up.
    static let maxTapDuration = Duration.milliseconds(400)
    /// A finger farther than this from its landing point is dragging, not tapping.
    static let dragThresholdMM = 3.0
    /// Clicks are blocked for this long after a thumb anchors. Strictly less blocks.
    static let clickBlockingWindow = Duration.seconds(3)
    /// Icons are this far apart in finger travel; the selection is the nearest icon.
    static let switcherStepMM = 12.0
    /// The most the highlight's rubber band shows past an end, in icons.
    static let switcherMaxStretch = 0.2
    /// Travel the switcher keeps past either end of its row, in icons; any more is dropped, so turning back moves the
    /// selection at once however far the fingers went past the end.
    static let switcherMaxOvershoot = 0.25
}
