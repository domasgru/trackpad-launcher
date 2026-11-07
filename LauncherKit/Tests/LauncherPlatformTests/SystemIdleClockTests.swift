import Foundation
import Testing

@testable import LauncherPlatform

@MainActor @Suite(.serialized) struct SystemIdleClockTests {
    private final class Fires {
        var labels: [String] = []
    }

    private func holdMain(for seconds: TimeInterval) { Thread.sleep(forTimeInterval: seconds) }

    @Test func aWaitFiresOnceWithinItsDurationPlusTheLeeway() async throws {
        let clock = SystemIdleClock()
        let fires = Fires()
        let began = ContinuousClock.now

        let elapsed: Duration? = await awaiting("the wait") { done in
            clock.wait(.milliseconds(100)) {
                fires.labels.append("first")
                done(ContinuousClock.now - began)
            }
        }
        try? await Task.sleep(for: .milliseconds(1500))

        #expect(fires.labels == ["first"])
        #expect(try #require(elapsed) >= .milliseconds(100))
        #expect(try #require(elapsed) <= .milliseconds(100) + .seconds(1) + .milliseconds(500))
    }

    @Test func aSecondWaitReplacesTheFirst() async {
        let clock = SystemIdleClock()
        let fires = Fires()

        let _: Bool? = await awaiting("the second wait") { done in
            clock.wait(.milliseconds(50)) { fires.labels.append("first") }
            clock.wait(.milliseconds(200)) {
                fires.labels.append("second")
                done(true)
            }
        }
        try? await Task.sleep(for: .milliseconds(1500))

        #expect(fires.labels == ["second"])
    }

    @Test func cancelStopsTheWait() async {
        let clock = SystemIdleClock()
        let fires = Fires()
        clock.wait(.milliseconds(50)) { fires.labels.append("fired") }

        clock.cancel()
        try? await Task.sleep(for: .milliseconds(1500))

        #expect(fires.labels.isEmpty)
    }

    @Test func aCancelInTheTurnMainWasHeldPastTheDeadlineStillMeansItNeverFires() async {
        let clock = SystemIdleClock()
        let fires = Fires()
        clock.wait(.milliseconds(50)) { fires.labels.append("fired") }

        holdMain(for: 1.5)
        clock.cancel()
        try? await Task.sleep(for: .milliseconds(500))

        #expect(fires.labels.isEmpty)
    }
}
