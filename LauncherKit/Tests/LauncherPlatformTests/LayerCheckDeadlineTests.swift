import Testing

@testable import LauncherCore
@testable import LauncherPlatform

@MainActor @Suite(.serialized) struct LayerCheckDeadlineTests {
    private final class Passes {
        var times: [ContinuousClock.Instant] = []
    }

    private func deadline(_ passes: Passes, then done: (@Sendable (Bool) -> Void)? = nil) -> LayerCheckDeadline {
        let deadline = LayerCheckDeadline()
        deadline.onPassed = {
            passes.times.append(.now)
            done?(true)
        }
        return deadline
    }

    private func hostClosed() async -> Bool? {
        await awaiting("the host to close") { (done: @escaping @Sendable (Bool) -> Void) in
            Task { @MainActor in
                while LaunchClock.hostPanel != nil { try? await Task.sleep(for: .milliseconds(20)) }
                done(true)
            }
        }
    }

    @Test func anArmedWaitPassesOnceNotBeforeItsTimeAndACancelAfterwardsChangesNothing() async throws {
        let passes = Passes()
        let began = ContinuousClock.now
        var kept: LayerCheckDeadline?
        let passed: Bool? = await awaiting("the wait") { done in
            let armed = deadline(passes, then: done)
            armed.arm(for: .milliseconds(200))
            kept = armed
        }
        #expect(passed == true)
        #expect(passes.times.count == 1)
        let at = try #require(passes.times.first)
        #expect(at - began >= .milliseconds(200), "not before the wait")
        kept?.cancel()
        try await Task.sleep(for: .seconds(1))
        #expect(passes.times.count == 1, "nothing follows")
        #expect(await hostClosed() == true, "the host closes once the clock is gone")
    }

    @Test func aWaitCancelledAtOncePassesNever() async throws {
        let passes = Passes()
        let cancelled = deadline(passes)
        cancelled.arm(for: .milliseconds(200))
        cancelled.cancel()

        try await Task.sleep(for: .seconds(1))

        #expect(passes.times.isEmpty)
        #expect(await hostClosed() == true, "the host closes with the last clock")
    }

    @Test func aWaitArmedAgainReplacesTheFirstAndPassesOnceFromTheSecondArm() async throws {
        let passes = Passes()
        var rearmed = ContinuousClock.now
        var kept: LayerCheckDeadline?
        let passed: Bool? = await awaiting("the second wait") { done in
            let armed = deadline(passes, then: done)
            armed.arm(for: .seconds(2))
            rearmed = .now
            armed.arm(for: .milliseconds(200))
            kept = armed
        }
        #expect(passed == true)
        let at = try #require(passes.times.first)
        #expect(at - rearmed >= .milliseconds(200))
        try await Task.sleep(for: .seconds(2.5))
        #expect(passes.times.count == 1, "none after")
        _ = kept
        #expect(await hostClosed() == true)
    }
}
