import Foundation
import LauncherCore
import Testing

@MainActor @Suite struct ReplacingOtherCopiesTests {
    @Test func openingByHandStopsAnEarlierCopyAndStartsOnlyOnceItHasExited() {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let process = world.launch(.byHand, others: [.earlier])

        #expect(process.copies.stopped == [.earlier])
        #expect(process.lifecycle.launcher == nil)
        #expect(process.residentsBuilt == 0)
        #expect(process.hardware.runCount == 0)
        #expect(process.history == [.closed])
        #expect(world.permissions.asks.isEmpty)
        #expect(world.loginItem.calls.isEmpty)

        process.letExit(.earlier)

        #expect(process.residentsBuilt == 1)
        #expect(process.window == .open(request: 1))
        process.tap(1)
        #expect(process.system.broughtToFront == [world.mac.app("Arc")])
    }

    @Test func everyOtherCopyIsStoppedAtOnceAndTheLastExitStartsTheResident() {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let process = world.launch(.byHand, others: [.earlier, .tools])
        #expect(process.copies.stopped == [.earlier, .tools])

        process.letExit(.earlier)
        #expect(process.residentsBuilt == 0)
        #expect(process.hardware.runCount == 0)

        process.letExit(.tools)
        #expect(process.residentsBuilt == 1)
        #expect(process.window == .open(request: 1))
    }

    @Test func aCopyThatAlreadyExitedStartsTheResidentBeforeLaunchedReturns() {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let process = world.launch(.byHand, others: [.earlier], alreadyExited: [.earlier])

        #expect(process.residentsBuilt == 1)
        #expect(process.window == .open(request: 1))
    }

    @Test func aDuplicatedExitPushChangesNothing() {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let process = world.launch(.byHand, others: [.earlier])

        process.letStoppedCopiesExit()
        process.deliverExitAgain()

        #expect(process.residentsBuilt == 1)
        #expect(process.window == .open(request: 1))
        #expect(process.hardware.runCount == 1)
    }

    @Test func aLoginStartWaitingForALaterCopyOpensTheWindowOnlyIfOpenedByHandMeanwhile() {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)

        let reopened = world.login(others: [.later])!
        reopened.openAgain(.byHand)
        #expect(reopened.residentsBuilt == 0)
        reopened.letExit(.later)
        #expect(reopened.window == .open(request: 1))

        let silent = world.login(others: [.later])!
        silent.openAgain(.atLogin)
        silent.letExit(.later)
        #expect(silent.window == .closed)

        let untouched = world.login(others: [.later])!
        #expect(untouched.shouldEnd(.system))
        untouched.letExit(.later)
        #expect(untouched.window == .closed)
        #expect(untouched.residentsBuilt == 1)
    }

    @Test func aResidentLoginReopenLeavesItsWindowClosed() {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let process = world.login(others: [.later])!
        process.letStoppedCopiesExit()

        process.openAgain(.atLogin)

        #expect(process.window == .closed)
    }

    @Test func ofTwoLoginStartsTheOlderKeepsRunningAndTheNewerEnds() {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let newer = world.login(others: [.earlier])!
        let older = world.login(others: [.later])!

        #expect(newer.copies.hasEnded)
        #expect(newer.copies.stopped.isEmpty)
        #expect(newer.residentsBuilt == 0)

        #expect(older.copies.stopped == [.later])
        older.letExit(.later)
        #expect(older.residentsBuilt == 1)
        #expect(older.window == .closed)
        #expect(older.hardware.runCount == 1)
        #expect(!older.copies.hasEnded)
    }
}

private extension OneProcess {
    func letExit(_ copy: RunningCopy) { letExit(copy.id) }
}
