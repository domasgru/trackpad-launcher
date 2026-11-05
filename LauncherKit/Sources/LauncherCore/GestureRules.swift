import Foundation

/// Every fixed number in gesture recognition and click blocking, in one place. Not user-tunable.
package enum GestureRules {
    /// Fraction of the surface width, measured from the anchor-side edge.
    static let cornerWidth = 0.20
    /// Fraction of the surface height, measured from the corner's top or bottom edge.
    static let cornerHeight = 0.25
    /// An anchored thumb may roll this far past the zone edge before it stops being the anchor.
    static let anchorReleaseMarginMM = 2.0
    /// A contact landing closer than this to the bottom edge, or with a top corner to the hand-side edge below the
    /// `edgeBandTop` line, is an edge contact (a resting palm), not a finger. Strictly less is inside the band.
    static let edgeBandMM = 3.0
    /// Fraction of the surface height, measured from the top edge, below which the hand-side edge is in the band, for
    /// top corners. A share of the height, not millimetres: the palm rests at the same share of the pad on every
    /// trackpad size. Strictly more is inside the band.
    static let edgeBandTop = 0.40
    /// First finger down to last finger up.
    static let maxTapDuration = Duration.milliseconds(400)
    /// A finger farther than this from its landing point is dragging, not tapping.
    static let dragThresholdMM = 3.0
    /// Clicks are blocked for this long after a thumb anchors. Strictly less blocks.
    static let clickBlockingWindow = Duration.seconds(3)
    /// The lift window: after a contact other than the thumb lifts inside a thumb touch as macOS could read a tap, every
    /// tap action is blocked for this long. Strictly less is inside.
    static let liftWindow = Duration.milliseconds(500)
    /// The longest a contact is down and still makes a tap action in macOS (measured: taps under a thumb held up to
    /// 169 ms acted, every touch held 297 ms or more did not). Strictly less qualifies. Deliberately not
    /// `maxTapDuration`, though the number is the same: that says what fires a gesture, this says what macOS clicks.
    static let tapActionHoldLimit = Duration.milliseconds(400)
    /// The most icons a switcher row holds: the frontmost app and the most recently used others.
    static let switcherMaxApps = 10
    /// The most rows a window switcher holds: the front window, the other visible ones, then the minimised ones.
    package static let windowSwitcherMaxRows = 10
    /// Items are this many step millimetres apart in travel; the selection is the nearest item.
    static let switcherStepMM = 12.0
    /// The most the highlight's rubber band shows past an end, in items.
    static let switcherMaxStretch = 0.2
    /// Travel a switcher keeps past either end of its list, in items (a quarter of the 12 step millimetres per item);
    /// any more is dropped, so turning back moves the selection at once however far the fingers went past the end.
    static let switcherMaxOvershoot = 0.25
}
