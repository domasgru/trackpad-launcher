import Foundation

/// Crests travelling from the swell in the slide's direction. A bead's height offset is the saturated sum of the
/// crests' ripples, every one of them a closed form of time, so the staged samples and `Liquid.shape(at:)` agree.
struct WaveTrain: Sendable {
    struct Crest: Sendable {
        let emitted: LiquidTime
        /// The position, in items, the crest left from.
        let origin: Double
        /// The sign of the slide.
        let direction: Double
        /// Points at the origin, before falloff.
        let strength: Double
    }

    private(set) var crests: [Crest] = []
    private let layout: SwitcherRowLayout
    /// Where and when the finger speed is measured from: the opening, then each crest.
    private var reference: (position: Double, time: LiquidTime)?
    private var moved = false

    init(layout: SwitcherRowLayout) {
        self.layout = layout
    }

    mutating func open(at position: Double, time: LiquidTime) {
        crests = []
        reference = (position, time)
        moved = false
    }

    /// Whether a crest was emitted for the fingers having reached `position` at `time`: on the first move after the
    /// opening, then whenever the position has moved `waveEvery` items since the last crest. Never more than one.
    mutating func emit(at position: Double, time: LiquidTime) -> Bool {
        guard let reference else { return false }
        let look = layout.look
        let travelled = position - reference.position
        guard travelled != 0, !moved || abs(travelled) >= look.waveEvery else { return false }
        let speed = abs(travelled) / max(time.seconds - reference.time.seconds, Liquid.speedFloor)
        let strength = look.waveHeight * layout.scale * tanh(speed / max(look.waveFullSpeed, 1e-9))
        crests.removeAll { time.seconds >= $0.emitted.seconds + Liquid.settleBound }
        crests.append(Crest(emitted: time, origin: position, direction: travelled > 0 ? 1 : -1, strength: strength))
        self.reference = (position, time)
        moved = true
        return true
    }

    /// Bead `bead`'s height beyond its rest at `t`, within the layout's limits.
    func offset(bead: Int, at t: LiquidTime) -> Double {
        let look = layout.look
        let omega = 2 * Double.pi * max(look.waveHz, 0), damping = Liquid.clampedDamping(look.waveDamping)
        let speed = max(look.waveSpeed, 1e-6), reach = max(look.waveReach, 1e-6)
        var sum = 0.0
        for crest in crests {
            let age = t.seconds - crest.emitted.seconds
            let x = age / Liquid.settleBound
            let distance = abs(Double(bead) - crest.origin)
            let tau = age - distance / speed
            guard x < 1, tau > 0 else { continue }
            let behind = (Double(bead) - crest.origin) * crest.direction < 0 ? look.waveBehind : 1
            let window = Liquid.window(x)
            let ripple = exp(-damping * omega * tau) * sin(omega * tau) * window
            sum += crest.strength * exp(-distance / reach) * behind * ripple
        }
        return saturate(sum)
    }

    /// Soft-saturates `x` into how far a bead may grow and shrink from its rest height.
    private func saturate(_ x: Double) -> Double {
        let rest = layout.bead(at: 0).height, limits = layout.beadLimits
        let room = x >= 0 ? limits.upperBound - rest : rest - limits.lowerBound
        guard room > 0 else { return 0 }
        return room * tanh(x / room)
    }

    /// One height track per real bead from `time` until the newest crest has ended, ending at 0.
    func tracks(from time: LiquidTime) -> [LiquidTrack] {
        guard let newest = crests.last else { return [] }
        let step = 1 / Liquid.sampleRate
        let span = max(newest.emitted.seconds + Liquid.settleBound - time.seconds, 0)
        let count = max(Int((span * Liquid.sampleRate - 1e-6).rounded(.up)) + 1, 2)
        return (0..<layout.iconCount).map { bead in
            let offsets = (0..<count).map { sample in
                sample == count - 1 ? 0 : offset(bead: bead, at: time + Double(sample) * step)
            }
            return LiquidTrack(
                channel: LiquidChannel(element: .bead(bead), property: .height), begin: time, step: step,
                offsets: offsets)
        }
    }
}
