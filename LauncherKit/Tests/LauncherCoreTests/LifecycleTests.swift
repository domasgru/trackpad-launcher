import Foundation
import LauncherCore
import Testing

@MainActor @Suite struct LifecycleTests {
    @Test func openingByHandAfterACrashStartsGesturesAndShowsTheWindowOnce() {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let process = world.launch(.byHand)

        #expect(process.residentsBuilt == 1)
        #expect(process.window == .open(request: 1))
        #expect(world.permissions.asks.isEmpty)
        #expect(world.loginItem.calls.isEmpty)
        #expect(!process.copies.hasEnded)

        process.lifecycle.launched(Launch(opening: .byHand))
        #expect(process.residentsBuilt == 1)
        #expect(process.window == .open(request: 1))

        process.tap(1)
        #expect(process.system.broughtToFront == [world.mac.app("Arc")])
        #expect(process.hardware.feedback == [Trackpad.macBook14.id])
    }

    @Test func openingAgainShowsTheSameWindowEveryTimeAndClosingKeepsGesturesRunning() {
        let world = LifecycleWorld(record: [.two: "Arc"], loginItemOn: true)
        let process = world.login()!
        #expect(process.history == [.closed])

        process.openAgain(.byHand)
        process.openAgain(.byHand)
        process.openAgain(.byHand)
        process.closeWindow()
        process.tap(2)
        process.openAgain(.byHand)

        #expect(
            process.history == [
                .closed, .open(request: 1), .open(request: 2), .open(request: 3), .closed, .open(request: 4),
            ])
        #expect(process.residentsBuilt == 1)
        #expect(!process.copies.hasEnded)
        #expect(process.system.broughtToFront == [world.mac.app("Arc")])
    }

    @Test func aLoginStartIsSilentAndLeavesTheSavedSettingsAlone() throws {
        let world = LifecycleWorld(accessGranted: false, record: [.one: "Arc"], loginItemOn: true)
        let seeded = world.mac.settingsRecordBytes()
        let process = world.login()!
        var windows: [Launcher.Window] = [process.window]

        process.tap(1)
        windows.append(process.window)

        #expect(windows == [.closed, .closed])
        #expect(world.permissions.asks.isEmpty)
        #expect(world.loginItem.calls.isEmpty)
        #expect(world.mac.settingsRecordBytes() == seeded)
        #expect(process.system.broughtToFront == [world.mac.app("Arc")])
    }

    @Test func aLoginStartOnAMacWithoutSettingsDoesNothingUntilOpenedByHand() {
        let world = LifecycleWorld(accessGranted: false)
        var atRegistration: [Settings?] = []
        var atAsk: [Settings?] = []
        world.loginItem.onRegister = { [mac = world.mac] in atRegistration.append(mac.freshStore().load()) }
        world.permissions.onAsk = { [mac = world.mac] in atAsk.append(mac.freshStore().load()) }

        let process = world.launch(.atLogin)

        #expect(process.window == .closed)
        #expect(world.permissions.asks.isEmpty)
        #expect(world.loginItem.calls.isEmpty)
        #expect(world.mac.freshStore().load() == nil)
        #expect(process.hardware.running.count == 1)

        process.openAgain(.byHand)

        #expect(world.loginItem.calls == ["register"])
        #expect(world.permissions.asks == [.accessibility])
        #expect(atRegistration == [nil])
        #expect(atAsk == [nil])
        #expect(world.mac.freshStore().load() != nil)
        #expect(process.window == .open(request: 1))
    }

    @Test func aLoginStartReachingTheRunningCopyChangesNothing() {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let process = world.login()!

        process.openAgain(.atLogin)

        #expect(process.history == [.closed, .closed])
    }

    @Test func theFirstRunByHandEnrolsAsksOpensAndGesturesWork() {
        let world = LifecycleWorld(accessGranted: false)
        var atRegistration: [Settings?] = []
        var atAsk: [Settings?] = []
        world.loginItem.onRegister = { [mac = world.mac] in atRegistration.append(mac.freshStore().load()) }
        world.permissions.onAsk = { [mac = world.mac] in atAsk.append(mac.freshStore().load()) }

        let process = world.launch(.byHand)

        #expect(atRegistration == [nil])
        #expect(atAsk == [nil])
        #expect(world.mac.freshStore().load() != nil)
        #expect(process.window == .open(request: 1))
        #expect(process.launcher.rows.map(\.app) == Array(repeating: .unassigned, count: 5))
        #expect(world.loginItem.isOn)

        process.launcher.setAssignment(.app(world.mac.app("Arc")), for: .one)
        process.tap(1)
        #expect(process.system.broughtToFront == [world.mac.app("Arc")])

        world.launch(.byHand)
        #expect(world.permissions.asks == [.accessibility])
        #expect(world.loginItem.calls == ["register"])
    }

    @Test func theFirstRunWithAccessGrantedAsksNothing() {
        let world = LifecycleWorld(accessGranted: true)

        let process = world.launch(.byHand)

        #expect(world.permissions.asks.isEmpty)
        #expect(world.loginItem.calls == ["register"])
        #expect(process.window == .open(request: 1))
    }

    @Test func aLaterRunNeverAsksAndShowsTheHint() {
        let world = LifecycleWorld(accessGranted: true)
        world.launch(.byHand)
        world.permissions.set(.accessibility, granted: false)

        let later = world.launch(.byHand)

        #expect(world.permissions.asks.isEmpty)
        #expect(world.loginItem.calls == ["register"])
        #expect(later.window == .open(request: 1))
        #expect(!later.launcher.isAccessibilityGranted)
    }

    @Test func theQuitButtonEndsTheProcessAtOnceWithTheWindowOpen() {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let process = world.launch(.byHand)
        #expect(process.window == .open(request: 1))

        process.quit()

        #expect(process.copies.hasEnded)
        #expect(process.window == .open(request: 1))
    }

    @Test func anOrdinaryQuitWhileTheWindowIsOpenOnlyClosesItAndAQuitWithItClosedEnds() {
        let world = LifecycleWorld(
            record: [.three: "Arc", .two: "Notes"], loginItemOn: true)
        let process = world.launch(.byHand)

        let answer = process.shouldEnd(.other)

        #expect(!answer)
        #expect(process.window == .closed)
        #expect(!process.copies.hasEnded)
        #expect(process.launcher.app(for: .two) == .present(world.mac.app("Notes")))
        process.tap(3)
        #expect(process.system.broughtToFront == [world.mac.app("Arc")])

        #expect(process.shouldEnd(.other))
    }

    @Test func aSystemQuitEndsInEveryStageAndLeavesTheWindow() {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let closed = world.login()!
        #expect(closed.shouldEnd(.system))
        #expect(closed.window == .closed)

        let open = world.launch(.byHand)
        #expect(open.shouldEnd(.system))
        #expect(open.window == .open(request: 1))

        let ending = world.launch(.byHand)
        ending.quit()
        #expect(ending.shouldEnd(.system))
        #expect(ending.window == .open(request: 1))
    }
}

