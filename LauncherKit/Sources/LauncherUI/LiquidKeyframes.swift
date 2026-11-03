import LauncherCore
import QuartzCore

/// How a `LiquidTrack` becomes a Core Animation animation. Pure staging, so tests read it back: additive, linear
/// calculation, values = offsets, duration from step and count; filled forwards and not removed when the track holds.
/// The key strings and key paths belong to this adapter alone: Core knows only the channel.
enum LiquidKeyframes {
    static let keyPrefix = "liquid."

    /// "liquid.swell.width", "liquid.bead.3.height", …: one per channel, so a new track replaces the running one.
    static func key(_ channel: LiquidChannel) -> String {
        let element =
            switch channel.element {
            case .swell: "swell"
            case .bead(let index): "bead.\(index)"
            }
        let property =
            switch channel.property {
            case .centreX: "centreX"
            case .width: "width"
            case .height: "height"
            }
        return "\(keyPrefix)\(element).\(property)"
    }

    private static func keyPath(_ property: LiquidProperty) -> String {
        switch property {
        case .centreX: "position.x"
        case .width: "bounds.size.width"
        case .height: "bounds.size.height"
        }
    }

    static func animation(_ track: LiquidTrack, beginTime: CFTimeInterval) -> CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: keyPath(track.channel.property))
        animation.isAdditive = true
        animation.calculationMode = .linear
        animation.values = track.offsets.map { NSNumber(value: $0) }
        animation.duration = track.step * Double(track.offsets.count - 1)
        animation.beginTime = beginTime
        if track.holds {
            animation.fillMode = .forwards
            animation.isRemovedOnCompletion = false
        } else {
            animation.isRemovedOnCompletion = true
        }
        return animation
    }
}
