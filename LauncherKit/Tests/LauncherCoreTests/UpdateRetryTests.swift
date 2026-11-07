import Foundation
import LauncherCore
import Testing

@MainActor @Suite struct UpdateRetryTests {
    private func resident(_ opening: Opening = .atLogin) -> (world: LifecycleWorld, process: OneProcess) {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let process = world.launch(opening, running: .release)
        return (world, process)
    }

    @Test func aFailedRequestRunsAgainOnceAConnectionArrivesAndNotBefore() {
        let (_, process) = resident()
        process.connection.reading = false

        process.engine.push(.cycleEnded(.requestFailed))

        #expect(process.connection.isWatching)
        #expect(process.engine.checks == 1)
        process.connection.set(false)
        #expect(process.engine.checks == 1)
        process.connection.set(true)
        #expect(process.engine.checks == 2)
    }

    @Test func aCycleThatEndsWithNothingNewWatchesNothing() {
        let (_, process) = resident()

        process.engine.push(.cycleEnded(.nothingNew))

        #expect(!process.connection.isWatching)
        #expect(process.connection.watches == 0)
    }

    @Test func aConnectionThatCameUpBeforeTheWatchArmedStillRetriesFromTheReadingItPushes() {
        let (_, process) = resident()
        process.connection.reading = true

        process.engine.push(.cycleEnded(.requestFailed))

        #expect(process.engine.checks == 2)
    }

    @Test func aRetryThatFailsOnASteadyPathIsNotRepeatedUntilTheConnectionDropsAndReturns() {
        let (_, process) = resident()
        process.connection.reading = true
        process.engine.push(.cycleEnded(.requestFailed))
        #expect(process.engine.checks == 2)
        process.engine.push(.cycleEnded(.requestFailed))

        for _ in 0..<1000 { process.connection.set(true) }
        process.engine.push(.cycleEnded(.requestFailed))

        #expect(process.engine.checks == 2)
        process.connection.set(false)
        process.connection.set(true)
        #expect(process.engine.checks == 3)
    }

    @Test func aDropDuringTheRetryEarnsTheNextOneEvenWhenTheRetryThenFails() {
        let (_, process) = resident()
        process.connection.reading = true
        process.engine.push(.cycleEnded(.requestFailed))
        #expect(process.engine.checks == 2)

        process.connection.set(false)
        process.engine.push(.cycleEnded(.requestFailed))
        process.connection.set(true)

        #expect(process.engine.checks == 3)
    }

    @Test func aDropAndReturnWhileTheRetryStillRunsEarnsOneMoreAndItsFailureNoFourth() {
        let (_, process) = resident()
        process.connection.reading = true
        process.engine.push(.cycleEnded(.requestFailed))
        #expect(process.engine.checks == 2)

        process.connection.set(false)
        process.connection.set(true)
        #expect(process.engine.checks == 3)
        process.engine.push(.cycleEnded(.requestFailed))

        #expect(process.engine.checks == 3)
    }

    @Test func aCycleThatEndsAnotherWayStopsTheWatch() {
        let (_, process) = resident()
        process.engine.push(.cycleEnded(.requestFailed))
        #expect(process.connection.isWatching)

        process.engine.push(.cycleEnded(.failed))

        #expect(!process.connection.isWatching)
        process.connection.set(true)
        #expect(process.engine.checks == 1)
    }

    @Test func aFailedCycleAloneStartsNoWatch() {
        let (_, process) = resident()

        process.engine.push(.cycleEnded(.failed))

        #expect(process.connection.watches == 0)
    }

    @Test func aRetryThatFindsAnUpdateEndsTheWatchAndHandsOverLikeAnyOther() {
        let (world, process) = resident()
        process.engine.push(.cycleEnded(.requestFailed))
        process.connection.set(true)

        process.engine.push(.held(.genuine))

        #expect(!process.connection.isWatching)
        #expect(world.log.entries.suffix(2) == ["arm restart", "end"])
    }

    @Test func aRefusedHandOverFollowedByAFailedRequestWatchesLikeAFailedCheck() {
        let (world, process) = resident()
        process.engine.armWorks = false
        process.engine.push(.held(.genuine))

        process.engine.push(.cycleEnded(.requestFailed))

        #expect(process.connection.isWatching)
        #expect(!world.log.entries.contains("end"))
    }

    @Test func aDownloadLostMidWayWatchesLikeAFailedCheckAndRunsAgainWithAConnection() {
        let (_, process) = resident()

        process.engine.push(.cycleEnded(.requestFailed))

        #expect(process.connection.isWatching)
        let checks = process.engine.checks
        process.connection.set(true)
        #expect(process.engine.checks == checks + 1)
    }

    @Test func whileWatchingAQuitEndsAtOnceAndASystemEndIsAllowed() {
        let (world, process) = resident()
        process.engine.push(.cycleEnded(.requestFailed))

        #expect(process.shouldEnd(.system))
        process.quit()

        #expect(world.log.entries.contains("end"))
    }
}
