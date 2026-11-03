import Foundation

/// Every number of the switcher's liquid look and motion, at full size (points, seconds, items). The defaults ARE the
/// shipped look. Requirement bounds are not here: `Liquid` enforces them whatever this holds.
public struct LiquidLook: Equatable, Sendable {
    // Shape
    public var beadSide = 80.0, beadCorner = 0.32  // corner as a share of the side
    public var bandThickness = 52.0  // the neck
    public var spacing = 40.0  // the container's merge distance: how soft the necks' fillets are
    /// THE swell setting: how far the swell rises beyond a bead on each side. 3 is subtle. It moves nothing else: the
    /// scale and the panel come from `room`; the rise is clamped to fit it with the pull.
    public var swellRise = 12.0, swellCorner = 0.32
    /// The panel's clear margin beyond the beads on every side: the swell's rise, the end pull and the wave's cap live
    /// in it.
    public var room = 40.0
    /// The visible body of an 80 pt icon. A wave never dips a bead within 4 pt of it at the selected icon's grown size, and the swell never thins below
    /// the grown body plus 4 pt. Checked by hand against real icons.
    public var iconBody = 64.0
    // Stretch, flow, end pull
    public var reach = 0.5  // leading-edge stretch per item of lean
    public var followTime = 1.0 / 60  // glide between input events
    public var flowTime = 0.18, leadShare = 0.6  // Liquid caps flowTime at 0.2 s
    public var endPull = 20.0, endPullMM = 1.0  // capped at 0.2 pitch; e-fold per step-mm, so 95% by 3 mm
    public var pullHold = 0.06  // the pull stays out this long after the last move, then springs back
    public var thinning = 0.25  // swell height lost per point of stretch
    // Wobble
    public var wobble = 4.0, wobbleHz = 4.5, wobbleDamping = 0.35
    // Wave
    public var waveHeight = 6.0, waveFullSpeed = 8.0  // crest in points at full speed; items per second for full speed
    /// THE wave cap: the most a wave raises a bead's edge beyond its rest, on each side. Its own setting: the swell's
    /// size never lowers it. Clamped to fit `room`.
    public var waveMax = 12.0
    public var waveReach = 2.5, waveSpeed = 14.0  // items to 1/e; items per second along the band
    public var waveHz = 5.0, waveDamping = 0.4, waveBehind = 0.3, waveEvery = 0.5

    public static let shipped = LiquidLook()
    public init() {}
}
