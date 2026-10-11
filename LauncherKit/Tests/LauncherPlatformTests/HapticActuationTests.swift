import Testing
import LauncherCore

@testable import LauncherPlatform

@MainActor @Suite struct HapticActuationTests {
    @Test func theLightTickIsLighterThanTheGestureHaptic() {
        #expect(MultitouchTrackpads.actuation(for: .gesture) == 6)
        #expect(MultitouchTrackpads.actuation(for: .lightTick) == 3)
        #expect(MultitouchTrackpads.actuation(for: .lightTick) < MultitouchTrackpads.actuation(for: .gesture))
    }
}
