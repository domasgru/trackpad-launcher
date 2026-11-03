@testable import LauncherCore
import Testing
@testable import LauncherUI

@Suite struct PickAnimationRuleTests {
    private let custom = PickAnimation(startScale: 0.2, peakScale: 1.3, growTime: 0.5, settleTime: 0.3)

    @Test func theShippedAnimationPlaysUnlessAnythingTurnsMotionOff() {
        #expect(SettingsShell.pickAnimation(reduceMotion: false, tuned: nil) == .shipped)
        #expect(SettingsShell.pickAnimation(reduceMotion: true, tuned: nil) == nil)
    }

    @Test func theTunersValuesPlayUnlessItsSwitchSimulatesReduceMotion() {
        #expect(SettingsShell.pickAnimation(reduceMotion: false, tuned: (custom, simulateReduceMotion: false)) == custom)
        #expect(SettingsShell.pickAnimation(reduceMotion: false, tuned: (custom, simulateReduceMotion: true)) == nil)
        #expect(SettingsShell.pickAnimation(reduceMotion: true, tuned: (custom, simulateReduceMotion: false)) == nil)
    }
}
