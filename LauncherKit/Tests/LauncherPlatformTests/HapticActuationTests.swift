import Testing
import LauncherCore

@testable import LauncherPlatform

@MainActor @Suite struct HapticActuationTests {
    @Test func theLightTickIsLighterThanTheGestureHaptic() {
        #expect(MultitouchTrackpads.actuation(for: .lightTick) < MultitouchTrackpads.actuation(for: .gesture))
    }
}
