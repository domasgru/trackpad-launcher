import Foundation
import LauncherCore
import Testing

@MainActor @Suite struct UpdateRetryTests {
    private func resident() -> (world: LifecycleWorld, process: OneProcess) {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let process = world.launch(.atLogin, running: .release)
        return (world, process)
    }

    @Test func aFailedRequestRunsAgainOnceAConnectionArrivesAndNotBefore() {
        let (_, process) = resident()
        process.connection.reading = false

        process.engine.push(.cycleEnded(.requestFailed))

        #expect(process.connection.isWatching)
        #expect(process.engine.updates == 1)
        process.connection.set(false)
        #expect(process.engine.updates == 1)
        process.connection.set(true)
        #expect(process.engine.updates == 2)
        #expect(process.engine.probes == 0)
        #expect(process.engine.overlaps == 0)
    }

    @Test func aRetryThatFailsOnASteadyPathIsNotRepeatedUntilTheConnectionDropsAndReturns() {
        let (_, process) = resident()
        process.engine.push(.cycleEnded(.requestFailed))
        process.connection.set(true)
        #expect(process.engine.updates == 2)

        process.engine.push(.cycleEnded(.requestFailed))

        #expect(process.connection.isWatching)
        for _ in 0..<100 { process.connection.set(true) }
        #expect(process.engine.updates == 2)
        process.connection.set(false)
        process.connection.set(true)
        #expect(process.engine.updates == 3)
        #expect(process.engine.overlaps == 0)
    }

    @Test func aCycleThatEndsWithNothingNewOrNotWatchingLeavesTheWatchOff() {
        let (_, process) = resident()
        process.engine.push(.cycleEnded(.nothingNew))
        #expect(!process.connection.isWatching)
        #expect(process.connection.watches == 0)

        let (_, retrying) = resident()
        retrying.engine.push(.cycleEnded(.requestFailed))
        retrying.connection.set(true)
        #expect(retrying.connection.isWatching)

        retrying.engine.push(.cycleEnded(.nothingNew))

        #expect(!retrying.connection.isWatching)
        retrying.connection.set(false)
        retrying.connection.set(true)
        #expect(retrying.engine.updates == 2)
    }

    @Test func aConnectionThatCameUpBeforeTheWatchArmedRetriesFromTheReadingItPushes() {
        let (_, process) = resident()
        process.connection.reading = true

        process.engine.push(.cycleEnded(.requestFailed))

        #expect(process.engine.updates == 2)
        #expect(process.connection.isWatching)
        #expect(process.engine.overlaps == 0)
    }

    @Test func aDropDuringTheRetryEarnsTheNextOneEvenWhenTheRetryThenFails() {
        let (_, process) = resident()
        process.connection.reading = true
        process.engine.push(.cycleEnded(.requestFailed))
        #expect(process.engine.updates == 2)

        process.connection.set(false)
        process.engine.push(.cycleEnded(.requestFailed))
        process.connection.set(true)

        #expect(process.engine.updates == 3)
        #expect(process.engine.overlaps == 0)
    }

    @Test func aDropAndReturnInsideTheRetryThatThenFailsRetriesAtOnceAndItsFailureNoFourth() {
        let (_, process) = resident()
        process.connection.reading = true
        process.engine.push(.cycleEnded(.requestFailed))
        #expect(process.engine.updates == 2)

        process.connection.set(false)
        process.connection.set(true)
        #expect(process.engine.updates == 2)
        process.engine.push(.cycleEnded(.requestFailed))
        #expect(process.engine.updates == 3)
        process.engine.push(.cycleEnded(.requestFailed))

        #expect(process.engine.updates == 3)
        #expect(process.engine.overlaps == 0)
    }

    @Test func aFailedDownloadWatchesNothingAndAConnectionEarnsNoRetry() {
        let (_, process) = resident()

        process.engine.push(.cycleEnded(.failed))

        #expect(!process.connection.isWatching)
        #expect(process.connection.watches == 0)
        process.connection.set(true)
        #expect(process.engine.updates == 1)
    }

    @Test func aFailureAfterARetryEndsTheWatchToo() {
        let (_, process) = resident()
        process.engine.push(.cycleEnded(.requestFailed))
        process.connection.set(true)

        process.engine.push(.cycleEnded(.failed))

        #expect(!process.connection.isWatching)
        process.connection.set(false)
        process.connection.set(true)
        #expect(process.engine.updates == 2)
    }

    @Test func aNextLoginStartIsANewProcessWithItsOwnOneCycle() {
        let (world, process) = resident()
        process.engine.push(.cycleEnded(.failed))

        let next = world.login(running: .release)

        #expect(next?.engine.updates == 1)
        #expect(process.engine.updates == 1)
    }

    @Test func aRetryThatFindsAnUpdateEndsTheWatchAndHandsOverLikeAnyOther() {
        let (world, process) = resident()
        process.engine.push(.cycleEnded(.requestFailed))
        process.connection.set(true)

        process.engine.push(.held)

        #expect(!process.connection.isWatching)
        #expect(world.log.entries.suffix(2) == ["arm restart", "end"])
        #expect(process.engine.overlaps == 0)
    }
}
