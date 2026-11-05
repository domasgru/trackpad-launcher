import AppKit
import QuartzCore

/// A connected display as the launch animation sees it: its frame in global screen coordinates (y up) and its
/// backing scale.
struct LaunchDisplay: Equatable {
    let frame: CGRect
    let scale: CGFloat
}

extension LaunchDisplay {
    /// AppKit's own rule for which display holds the point; the nearest display when none does.
    static func containing(_ point: CGPoint, among displays: [LaunchDisplay]) -> LaunchDisplay? {
        displays.first { NSMouseInRect(point, $0.frame, false) }
            ?? displays.min { distance(from: point, to: $0.frame) < distance(from: point, to: $1.frame) }
    }

    private static func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return (dx * dx + dy * dy).squareRoot()
    }
}

/// Where the pointer is and which displays exist, read now: what a bounce reads when it starts and on every move.
struct ScreenRead {
    let pointer: CGPoint
    let displays: [LaunchDisplay]

    /// `NSEvent.mouseLocation` and `NSScreen.screens`.
    @MainActor static func now() -> ScreenRead {
        ScreenRead(
            pointer: NSEvent.mouseLocation,
            displays: NSScreen.screens.map { LaunchDisplay(frame: $0.frame, scale: $0.backingScaleFactor) })
    }
}

/// Draws launch flights, and remembers the sides of the last two moving ones so the same side never comes up three
/// times in a row.
struct LaunchFlights {
    private var lastSides: [Side] = []

    fileprivate enum Side {
        case left, right

        var opposite: Side {
            switch self {
            case .left: .right
            case .right: .left
            }
        }

        var sign: CGFloat {
            switch self {
            case .left: -1
            case .right: 1
            }
        }
    }

    /// `draw` is a uniform random number in -1...1. Its sign picks the side (zero veers right) and its magnitude the
    /// size of the sway. A side that would be the third in a row is swapped for the other, with the same size.
    /// Reduce-motion flights neither sway nor count towards a streak.
    ///
    /// Reduce motion is the system setting or `tuning.forceReduceMotion`. The flight keeps `tuning`, so a later change
    /// never reaches a flight already drawn.
    mutating func next(draw: Double, reduceMotion: Bool, tuning: LaunchTuning) -> LaunchFlight {
        guard !reduceMotion, !tuning.forceReduceMotion else {
            return LaunchFlight(motion: .fadeInPlace, tuning: tuning)
        }
        var side: Side = draw < 0 ? .left : .right
        if lastSides.count == 2, lastSides.allSatisfy({ $0 == side }) { side = side.opposite }
        lastSides = Array((lastSides + [side]).suffix(2))
        let share = tuning.minimumSway + (1 - tuning.minimumSway) * min(abs(draw), 1)
        return LaunchFlight(motion: .moving(side: side, share: share), tuning: tuning)
    }
}

/// One launch animation's path, before it is placed on a display.
struct LaunchFlight {
    fileprivate enum Motion {
        /// Under Reduce motion: the icon neither moves, shrinks nor tilts.
        case fadeInPlace
        /// The icon rises, shrinks, slants, veers and tilts toward `side`. `share` is the sway's drawn size, between
        /// Min sway and 1; the slant, the veer and the tilt all scale with it.
        case moving(side: LaunchFlights.Side, share: CGFloat)
    }

    private let motion: Motion
    private let tuning: LaunchTuning
    /// Every side of the flight, as a share of the icon's side: 1 from the pointer; a bounce's ending passes its icon's
    /// side then, so an inflated icon swells on from where it is instead of snapping back first.
    private var size: CGFloat = 1

    fileprivate init(motion: Motion, tuning: LaunchTuning) {
        self.motion = motion
        self.tuning = tuning
    }

    /// This flight with every side scaled by `size`.
    func sized(_ size: CGFloat) -> LaunchFlight {
        var flight = self
        flight.size = size
        return flight
    }

    /// 240 samples a second, so a pop of a few tens of milliseconds still gets several keyframes.
    private var steps: Int { max(10, Int((tuning.duration * 240).rounded())) }

    fileprivate struct Pose {
        var offset: CGPoint
        var side: CGFloat
        var rotation: CGFloat
        var opacity: Float
    }

    /// `u` is elapsed time over the duration, 0...1.
    fileprivate func pose(at u: CGFloat) -> Pose {
        var pose = unsizedPose(at: u)
        pose.side *= size
        return pose
    }

    private func unsizedPose(at u: CGFloat) -> Pose {
        switch motion {
        case .fadeInPlace:
            return Pose(offset: .zero, side: tuning.iconSide, rotation: 0, opacity: Float(1 - pow(u, tuning.fadeCurve)))
        case .moving(let side, let share):
            // The pop: the icon swells in place to its peak, easing out, like a balloon's last breath in. The
            // deflating flight then starts from the peak and plays in the rest of the duration.
            let popShare = tuning.popSize > 0 ? min(max(tuning.popTime / tuning.duration, 0), 0.9) : 0
            if u < popShare {
                let p = u / popShare
                let swell = 1 + tuning.popSize * (1 - (1 - p) * (1 - p))
                return Pose(offset: .zero, side: tuning.iconSide * swell, rotation: 0, opacity: 1)
            }
            let peak = tuning.peakSide
            let u = popShare > 0 ? (u - popShare) / (1 - popShare) : u
            let fade = Float(1 - pow(u, tuning.fadeCurve))
            let rise = tuning.rise * pow(u, tuning.riseCurve)
            // The share scales the slant's angle, not its tangent.
            let slant = tan(share * tuning.maximumSlant * .pi / 180)
            let veer = share * tuning.maximumSway * pow(u, tuning.swayCurve)
            // With no sway there is no tilt, as before the slant.
            let tiltShare = tuning.maximumSway > 0 ? share : 0
            return Pose(
                offset: CGPoint(x: side.sign * rise * (slant + veer), y: rise),
                side: peak * (1 - tuning.shrink * pow(u, tuning.shrinkCurve)),
                // Counter-clockwise is positive, so tilting toward a rightward (positive) sway is a negative rotation.
                rotation: -side.sign * tiltShare * tuning.maximumTilt * .pi / 180 * pow(u, tuning.tiltCurve), opacity: fade)
        }
    }

    fileprivate var poses: [Pose] {
        (0...steps).map { pose(at: CGFloat($0) / CGFloat(steps)) }
    }

    /// Where and how the icon moves for a pointer at `pointer`, in global screen coordinates (y up).
    /// Nil when there is no display, or nothing of the flight's reach is left on the pointer's display.
    func staged(at pointer: CGPoint, among displays: [LaunchDisplay]) -> LaunchStage? {
        guard let display = LaunchDisplay.containing(pointer, among: displays) else { return nil }
        let start = CGPoint(
            x: (pointer.x * display.scale).rounded() / display.scale,
            y: (pointer.y * display.scale).rounded() / display.scale)
        let poses = poses
        let reach = poses.map { Self.bounds(of: $0, from: start) }.reduce(CGRect.null) { $0.union($1) }.integral
        let frame = reach.intersection(display.frame)
        guard !frame.isEmpty else { return nil }
        let centre = CGPoint(x: start.x - frame.minX, y: start.y - frame.minY)
        return LaunchStage(
            frame: frame, scale: display.scale, iconSide: tuning.iconSide, iconCentre: centre,
            animations: animations(poses, from: centre))
    }

    /// The box holding a pose's square, rotated.
    private static func bounds(of pose: Pose, from start: CGPoint) -> CGRect {
        let half = pose.side / 2 * (abs(cos(pose.rotation)) + abs(sin(pose.rotation)))
        return CGRect(
            x: start.x + pose.offset.x - half, y: start.y + pose.offset.y - half, width: 2 * half, height: 2 * half)
    }

    private func animations(_ poses: [Pose], from centre: CGPoint) -> [CAKeyframeAnimation] {
        let keyTimes = poses.indices.map { NSNumber(value: Double($0) / Double(steps)) }
        let iconSide = tuning.iconSide
        func animation(_ keyPath: String, _ values: [Any]) -> CAKeyframeAnimation {
            let animation = CAKeyframeAnimation(keyPath: keyPath)
            animation.values = values
            animation.keyTimes = keyTimes
            animation.duration = tuning.duration
            animation.calculationMode = .linear
            return animation
        }
        return [
            animation(
                "position",
                poses.map { NSValue(point: CGPoint(x: centre.x + $0.offset.x, y: centre.y + $0.offset.y)) }),
            animation(
                "transform",
                poses.map { pose in
                    let scale = pose.side / iconSide
                    let rotation = CATransform3DMakeRotation(pose.rotation, 0, 0, 1)
                    return NSValue(caTransform3D: CATransform3DScale(rotation, scale, scale, 1))
                }),
            animation("opacity", poses.map { NSNumber(value: $0.opacity) }),
        ]
    }
}

/// What `LaunchFlight.staged(at:among:)` decided: the overlay window's frame and scale, and the icon layer's size,
/// start point and keyframes. Everything is y up; `iconCentre` and the position keyframes are in the window's
/// coordinates.
struct LaunchStage {
    let frame: CGRect
    let scale: CGFloat
    let iconSide: CGFloat
    let iconCentre: CGPoint
    /// Position, transform and opacity, to be added unchanged to the icon layer.
    let animations: [CAKeyframeAnimation]
}
