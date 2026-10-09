import Foundation

/// Every fixed number in gesture recognition, in one place. Not user-tunable.
package enum GestureRules {
    /// Fraction of the surface width, measured from the anchor-side edge.
    static let cornerWidth = 0.20
    /// Fraction of the surface height, measured from the top edge.
    static let cornerHeight = 0.25
    /// An anchored thumb may roll this far past the zone edge before it stops being the anchor.
    static let anchorReleaseMarginMM = 2.0
    /// First finger down to last finger up.
    static let maxTapDuration = Duration.milliseconds(300)
    /// A finger farther than this from its landing point is dragging, not tapping.
    static let dragThresholdMM = 3.0
}
