import AppKit
import QuartzCore

/// Where the bouncing icons rest for a pointer: one row, newest on the right, `spacing` apart, centred on the pointer's
/// tip plus `offset`, bottoms `gap` above the tip. It slides sideways just enough to stay on the pointer's display and
/// never moves down, so the top edge cuts it. Pixel-snapped to the display.
struct BounceRow: Equatable {
    let display: LaunchDisplay
    /// Each icon's bottom centre, global y-up, in row order.
    let rests: [CGPoint]

    /// Nil with no display. The display is AppKit's rule for the pointer, shared with the flight.
    init?(count: Int, pointer: CGPoint, among displays: [LaunchDisplay], side: CGFloat, tuning: LaunchTuning.Bounce) {
        guard let display = LaunchDisplay.containing(pointer, among: displays) else { return nil }
        let count = max(count, 0)
        let spacing = CGFloat(tuning.spacing)
        let width = CGFloat(count) * side + CGFloat(max(count - 1, 0)) * spacing
        var left = pointer.x + CGFloat(tuning.offset) - width / 2
        left = min(left, display.frame.maxX - width)
        left = max(left, display.frame.minX)
        let scale = display.scale
        func snap(_ value: CGFloat) -> CGFloat { (value * scale).rounded() / scale }
        let y = snap(pointer.y + CGFloat(tuning.gap))
        self.display = display
        rests = (0..<count).map { i in
            CGPoint(x: snap(left + side / 2 + CGFloat(i) * (side + spacing)), y: y)
        }
    }

    /// The re-flow: an additive position animation from `old − new` to zero over `tuning.slide`, easing out; nil when the
    /// rest did not move. Additive, so pointer moves during the slide compose with it.
    static func slide(from old: CGPoint, to new: CGPoint, tuning: LaunchTuning.Bounce) -> CABasicAnimation? {
        guard old != new else { return nil }
        let animation = CABasicAnimation(keyPath: "position")
        animation.isAdditive = true
        animation.fromValue = NSValue(point: CGPoint(x: old.x - new.x, y: old.y - new.y))
        animation.toValue = NSValue(point: .zero)
        animation.duration = tuning.slide
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        return animation
    }
}

/// One launch bounce's motion, which Core Animation repeats forever: a Dock-like jump on `transform` about the icon's
/// bottom centre, or under Reduce motion an opacity pulse in place. 240 samples a second; starts at rest.
struct BounceMotion {
    private let tuning: LaunchTuning.Bounce
    private let reduceMotion: Bool
    /// The icon's side in points, which the inflate style grows to.
    private let iconSide: Double

    init(tuning: LaunchTuning.Bounce, reduceMotion: Bool, iconSide: Double = LaunchTuning.shipped.iconSide) {
        self.tuning = tuning
        self.reduceMotion = reduceMotion
        self.iconSide = iconSide
    }

    /// timeUp + timeDown + rest, or the pulse period.
    var period: CFTimeInterval {
        reduceMotion ? tuning.pulsePeriod : tuning.timeUp + tuning.timeDown + tuning.rest
    }

    private var steps: Int { max(10, Int((period * 240).rounded())) }

    /// How far off the ground the icon is, and how much of its height it has lost, `t` seconds into a cycle.
    private func pose(at t: Double) -> (lift: Double, squash: Double) {
        let epsilon = 1e-9
        if t <= tuning.timeUp + epsilon {
            let u = tuning.timeUp > 0 ? min(t / tuning.timeUp, 1) : 1
            return (tuning.height * (1 - (1 - u) * (1 - u)), 0)
        }
        if t < tuning.timeUp + tuning.timeDown - epsilon {
            let v = (t - tuning.timeUp) / tuning.timeDown
            return (tuning.height * (1 - v * v), 0)
        }
        let r = tuning.rest > 0 ? (t - tuning.timeUp - tuning.timeDown) / tuning.rest : 1
        return (0, tuning.squash * max(1 - r, 0))
    }

    /// `repeatCount = .infinity`, `calculationMode = .linear`, easing baked into the samples, as in `LaunchFlight`.
    func animations() -> [CAKeyframeAnimation] {
        if !reduceMotion && tuning.style == .inflate { return [inflation()] }
        let steps = steps
        let animation = CAKeyframeAnimation(keyPath: reduceMotion ? "opacity" : "transform")
        animation.keyTimes = (0...steps).map { NSNumber(value: Double($0) / Double(steps)) }
        animation.values = (0...steps).map { i in
            let t = Double(i) / Double(steps) * period
            if reduceMotion {
                let low = tuning.pulseLow
                return NSNumber(value: low + (1 - low) * (1 + cos(2 * .pi * t / period)) / 2)
            }
            let pose = pose(at: t)
            let height = 1 - pose.squash
            let move = CATransform3DMakeTranslation(0, pose.lift, 0)
            return NSValue(caTransform3D: CATransform3DScale(move, 1 / height, height, 1))
        }
        animation.duration = period
        animation.repeatCount = .infinity
        animation.calculationMode = .linear
        return [animation]
    }

    /// The inflate style: a scale about the icon's bottom centre from `inflateFrom` up to the icon's side, easing out,
    /// then on by `creep` over `creepTime`, slowing to a stop, where it holds. Plays once.
    private func inflation() -> CAKeyframeAnimation {
        let start = iconSide > 0 ? tuning.inflateFrom / iconSide : 1
        let grow = max(tuning.inflateTime, 0.01)
        let creepTime = max(tuning.creepTime, 0.01)
        let duration = grow + creepTime
        let steps = max(10, Int((duration * 240).rounded()))
        let animation = CAKeyframeAnimation(keyPath: "transform")
        animation.keyTimes = (0...steps).map { NSNumber(value: Double($0) / Double(steps)) }
        animation.values = (0...steps).map { i in
            let t = Double(i) / Double(steps) * duration
            let scale: Double
            if t < grow {
                scale = start + (1 - start) * (1 - pow(1 - t / grow, tuning.inflateCurve))
            } else {
                let v = min((t - grow) / creepTime, 1)
                scale = 1 + tuning.creep * (1 - (1 - v) * (1 - v))
            }
            return NSValue(caTransform3D: CATransform3DMakeScale(scale, scale, 1))
        }
        animation.duration = duration
        animation.calculationMode = .linear
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        return animation
    }

    /// The quiet end: opacity from `opacity` to 0 over `tuning.fadeOut`, easing out.
    func quietFade(from opacity: Float) -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = opacity
        animation.toValue = Float(0)
        animation.duration = tuning.fadeOut
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        return animation
    }
}
