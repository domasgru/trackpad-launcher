import Foundation
import Testing
import LauncherCore

@Suite struct SwipeAccelerationTests {
    private let h = HandFrames()

    @Test func theGainHoldsBelowSlowEasesInBetweenAndHoldsAboveFast() {
        let a = SwipeAcceleration(slowGain: 1, fastGain: 3, slowSpeed: 40, fastSpeed: 200)
        #expect(a.gain(atSpeed: 0) == 1)
        #expect(a.gain(atSpeed: 40) == 1)
        #expect(a.gain(atSpeed: 120) == 2)
        #expect(a.gain(atSpeed: 200) == 3)
        #expect(a.gain(atSpeed: 900) == 3)
        #expect(a.gain(atSpeed: 60) < a.gain(atSpeed: 100))
        #expect(SwipeAcceleration.none.gain(atSpeed: 500) == 1)
    }

    /// Thumb anchored, a pair landed, then `frames` frames 10 ms apart each sliding the pair `mmPerFrame` to the right.
    /// Returns the last travel the recognizer reported and the finger movement since the swipe began.
    private func swipe(mmPerFrame: Double, frames: Int, acceleration: SwipeAcceleration) -> (travel: Double, moved: Double) {
        var recognizer = GestureRecognizer(handMode: .right, surface: .macBook14, swipes: true, acceleration: acceleration)
        var travel = 0.0
        var beganAt: Double?
        var x = 0.0
        _ = recognizer.step(h.frame(atMS: 0, [h.contact(9, .landing, atMM: 10, 10)]))
        _ = recognizer.step(h.frame(atMS: 10, [
            h.contact(9, atMM: 10, 10), h.contact(1, .landing, atMM: 40, 45), h.contact(2, .landing, atMM: 48, 45),
        ]))
        for i in 1...frames {
            x += mmPerFrame
            let swipe = recognizer.step(h.frame(atMS: 10 + 10 * i, [
                h.contact(9, atMM: 10, 10), h.contact(1, atMM: 40 + x, 45), h.contact(2, atMM: 48 + x, 45),
            ])).swipe
            if swipe == .began { beganAt = x }
            if case .moved(let t)? = swipe { travel = t }
        }
        return (travel, x - (beganAt ?? x))
    }

    @Test func aSlowSwipeTravelsExactlyAsFarAsTheFingers() {
        let slow = swipe(mmPerFrame: 0.2, frames: 80, acceleration: .shipped)
        #expect(slow.moved > 12)
        #expect(abs(slow.travel - slow.moved) < 1e-9)
    }

    @Test func aFastSwipeTravelsFartherThanTheFingersAndNoFartherThanTheFastGainAllows() {
        let fast = swipe(mmPerFrame: 4, frames: 10, acceleration: .shipped)
        #expect(fast.travel > 2 * fast.moved)
        #expect(fast.travel <= 3 * fast.moved)
    }

    @Test func withoutAccelerationAFastSwipeTravelsAsFarAsTheFingers() {
        let fast = swipe(mmPerFrame: 4, frames: 10, acceleration: .none)
        #expect(abs(fast.travel - fast.moved) < 1e-9)
    }
}
