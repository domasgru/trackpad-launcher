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
    /// First finger down to last finger up, for a tap with no thumb (Hold thumb off). Much shorter than
    /// `maxTapDuration`: with no thumb to say the touch is meant, only a brisk tap can be told from ordinary use. The
    /// deliberate taps recorded on a real trackpad ran at most 64 ms, while a still tap to click ran 104 ms. Inclusive.
    static let maxThumblessTapDuration = Duration.milliseconds(70)
    /// The same window for a tap of three, four or five fingers, which take longer to land and lift together. The
    /// recorded deliberate taps ran at most 72 ms (3 fingers), 80 ms (4) and 80 ms (5, one 128 ms outlier aside).
    /// Inclusive.
    static let maxThumblessMultiTapDuration = Duration.milliseconds(90)
    /// The drag limit for a thumbless tap of three, four or five fingers: the recorded deliberate 4-finger taps rolled
    /// up to 4.3 mm, past the 3 mm that holds for one or two fingers.
    static let thumblessMultiDragThresholdMM = 5.0
    /// A thumbless tap starts only after the trackpad held no contact (edge contacts aside) for this long, counted
    /// from the frame the last contact was gone. The recorded deliberate taps had at least 856 ms of quiet before
    /// them, while an accidental still touch landed 88 ms after the previous one lifted. Inclusive.
    static let thumblessQuietBefore = Duration.milliseconds(100)
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
    /// A slide's travel on each frame comes from the fingers' movement averaged over this many frames, the frame's own
    /// and those before it. The driver splits a steady slide unevenly from frame to frame and sends one catch-up
    /// frame of 3 to 5 times its neighbours just before the fingers stop, and the pointer acceleration turns that
    /// into a leap: over the 18 recorded swipes, averaging over 4 frames cut single-frame leaps from 99 to 2.
    static let travelAveragingFrames = 4
    /// While only one swipe finger is down, its movement on a frame is a snap, not movement, when it is longer than
    /// this many millimetres, longer than `snapRatio` times its last counted movement plus `snapSlackMM`. In the
    /// recordings, when one of the two fingers lost contact, the other was reported about 7 mm away (6.9) on a frame
    /// while it was moving 0.2 mm a frame, and back again soon after.
    static let snapMinMM = 2.0
    static let snapRatio = 3.0
    static let snapSlackMM = 1.0
    /// A discarded snap is remembered for this many frames after its own: the recorded one came back two frames later.
    static let snapMemoryFrames = 4
    /// A movement undoes a remembered snap when the two sum to at most this share of the snap's length: in the
    /// recording the back summed with the away to 1.0 mm against the snap's 6.9.
    static let snapUndoShare = 0.5
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
