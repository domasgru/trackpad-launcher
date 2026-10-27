import Foundation
import LauncherCore
import Testing

@MainActor @Suite struct MoveToApplicationsTests {
    private static let leftThumbEdge = (x: 114.8, y: 10.0)

    private func sameSuite(_ a: [String: Any], _ b: [String: Any]) -> Bool {
        NSDictionary(dictionary: a).isEqual(to: b)
    }

    @Test(arguments: [Placement.installed, .elsewhere, .development])
    func aLoginStartRunsSilentlyWhereverItLies(placement: Placement) {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)

        let process = world.launch(.atLogin, placement: placement)
        #expect(process.moveDialog == nil)
        process.openAgain(.atLogin)
        #expect(process.moveDialog == nil)

        #expect(process.residentsBuilt == 1)
        #expect(process.history == [.closed, .closed])
        #expect(world.permissions.asks.isEmpty)
        #expect(world.loginItem.calls.isEmpty)
        process.tap(1)
        #expect(process.system.broughtToFront == [world.mac.app("Arc")])
    }

    @Test func aDevelopmentBuildOpenedByHandStopsTheInstalledCopyThenOpensItsWindowWithoutAsking() {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)

        let process = world.launch(.byHand, others: [.earlier], placement: .development)
        #expect(process.moveDialog == nil)
        #expect(process.copies.stopped == [.earlier])
        #expect(process.residentsBuilt == 0)

        process.letExit(RunningCopy.earlier.id)

        #expect(process.moveDialog == nil)
        #expect(process.window == .open(request: 1))
        #expect(world.loginItem.calls.isEmpty)
    }

    @Test(arguments: [true, false])
    func aCopyInDownloadsOpenedByHandOnlyAsksAndQuitLeavesTheMacAsItWas(hasSettings: Bool) {
        let world = LifecycleWorld(accessGranted: false, record: hasSettings ? [.one: "Arc"] : nil, loginItemOn: true)
        let before = world.mac.suiteDomain()

        let process = world.launch(.byHand, others: [.earlier], placement: .elsewhere)

        #expect(process.moveDialog == .asking)
        #expect(process.lifecycle.launcher == nil)
        #expect(process.residentsBuilt == 0)
        #expect(process.hardware.runCount == 0)
        #expect(process.copies.stopped.isEmpty)
        #expect(world.permissions.asks.isEmpty)
        #expect(world.loginItem.calls.isEmpty)
        #expect(process.installer.installCalls == 0)
        #expect(sameSuite(world.mac.suiteDomain(), before))

        process.answer(.quit)

        #expect(process.copies.hasEnded)
        #expect(sameSuite(world.mac.suiteDomain(), before))
        #expect(world.loginItem.calls.isEmpty)
        #expect(world.permissions.asks.isEmpty)
        #expect(world.log.entries.isEmpty)
    }

    @Test func aResidentStartedAtLoginKeepsItsGesturesWhileTheDialogAsks() {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let process = world.launch(.atLogin, placement: .elsewhere)
        let resident = process.launcher

        process.openAgain(.byHand)

        #expect(process.moveDialog == .asking)
        #expect(process.lifecycle.launcher === resident)
        #expect(process.window == .closed)
        process.tap(1)
        #expect(process.system.broughtToFront == [world.mac.app("Arc")])

        process.openAgain(.byHand)
        #expect(process.moveDialog == .asking)
        #expect(process.history == [.closed, .closed, .closed])

        process.answer(.quit)

        #expect(process.copies.hasEnded)
        #expect(world.loginItem.calls.isEmpty)
    }

    @Test func movingFromDownloadsOnTheFirstRunInstallsOnceWithoutSpendingTheFirstRun() {
        let world = LifecycleWorld(accessGranted: false)
        let process = world.launch(.byHand, placement: .elsewhere)

        process.answer(.move)

        #expect(process.moveDialog == nil)
        #expect(process.installer.isHolding)
        process.answer(.move)
        process.openAgain(.byHand)
        #expect(process.installer.installCalls == 1)
        #expect(process.moveDialog == nil)
        #expect(!process.copies.hasEnded)

        process.releaseInstall(.installed)

        #expect(process.installer.removeOriginalCalls == 1)
        #expect(process.installer.openInstalledCopyCalls == 1)
        #expect(process.copies.hasEnded)
        #expect(world.loginItem.calls.isEmpty)
        #expect(world.permissions.asks.isEmpty)
        #expect(world.mac.freshStore().load() == nil)
        #expect(world.log.entries == ["install", "removeOriginal", "openInstalledCopy"])

        var atRegistration: [Settings?] = []
        var atAsk: [Settings?] = []
        world.loginItem.onRegister = { [mac = world.mac] in atRegistration.append(mac.freshStore().load()) }
        world.permissions.onAsk = { [mac = world.mac] in atAsk.append(mac.freshStore().load()) }

        let installed = world.launch(.byHand, placement: .installed)

        #expect(atRegistration == [nil])
        #expect(atAsk == [nil])
        #expect(world.permissions.asks == [.accessibility])
        #expect(world.mac.freshStore().load() != nil)
        #expect(installed.window == .open(request: 1))
    }

    @Test func movingOverAnOlderCopyKeepsEverySettingAndHandsStartingAtLoginOver() {
        let world = LifecycleWorld(record: [.one: "Arc"], handMode: .left, loginItemOn: true)
        let process = world.launch(.byHand, others: [.earlier], placement: .elsewhere)
        #expect(process.copies.stopped.isEmpty)

        process.answer(.move)
        process.releaseInstall(.installed)

        #expect(!world.loginItem.isOn)
        #expect(world.mac.suiteDomain()["startAtLoginTurnedOffByQuit"] as? Bool == true)
        #expect(process.copies.stopped == [.earlier])
        #expect(process.installer.openInstalledCopyCalls == 0)
        #expect(!process.copies.hasEnded)

        process.letExit(RunningCopy.earlier.id)

        #expect(process.installer.openInstalledCopyCalls == 1)
        #expect(process.copies.hasEnded)
        #expect(world.log.entries == ["install", "unregister", "removeOriginal", "stop", "openInstalledCopy"])

        let installed = world.launch(.byHand, placement: .installed)

        #expect(world.loginItem.isOn)
        #expect(Set(world.mac.suiteDomain().keys) == ["settings"])
        #expect(installed.window == .open(request: 1))
        #expect(installed.launcher.handMode == .left)
        installed.tap(1, thumbAtMM: Self.leftThumbEdge)
        #expect(installed.system.broughtToFront == [world.mac.app("Arc")])
    }

    @Test func movingKeepsStartingAtLoginOffWhenTheUserTurnedItOff() {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        world.loginItem.userTurnsOff()
        let process = world.launch(.byHand, others: [.earlier], placement: .elsewhere)

        process.answer(.move)
        process.releaseInstall(.installed)
        process.letExit(RunningCopy.earlier.id)
        world.launch(.byHand, placement: .installed)

        #expect(!world.loginItem.isOn)
        #expect(!world.loginItem.calls.contains("register"))
    }

    @Test func cancellingTheInstallEndsTheProcessWithNothingChanged() {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let before = world.mac.suiteDomain()
        let process = world.launch(.byHand, others: [.earlier], placement: .elsewhere)

        process.answer(.move)
        process.releaseInstall(.cancelled)

        #expect(process.copies.hasEnded)
        #expect(world.loginItem.calls.isEmpty)
        #expect(process.installer.removeOriginalCalls == 0)
        #expect(process.installer.openInstalledCopyCalls == 0)
        #expect(process.copies.stopped.isEmpty)
        #expect(sameSuite(world.mac.suiteDomain(), before))
    }

    @Test func cancellingTheInstallEndsAResidentStartedAtLoginToo() {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let process = world.launch(.atLogin, placement: .elsewhere)
        process.openAgain(.byHand)

        process.answer(.move)
        process.releaseInstall(.cancelled)

        #expect(process.copies.hasEnded)
        #expect(world.loginItem.calls.isEmpty)
    }

    @Test func aFailedInstallShowsTheReasonAndQuitEndsWithNothingChanged() {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let before = world.mac.suiteDomain()
        let process = world.launch(.atLogin, placement: .elsewhere)
        process.openAgain(.byHand)

        process.answer(.move)
        process.releaseInstall(.failed(reason: "The disk is full."))

        #expect(process.moveDialog == .failed(reason: "The disk is full."))
        process.tap(1)
        #expect(process.system.broughtToFront == [world.mac.app("Arc")])

        process.answer(.quit)

        #expect(process.copies.hasEnded)
        #expect(world.loginItem.calls.isEmpty)
        #expect(process.installer.removeOriginalCalls == 0)
        #expect(sameSuite(world.mac.suiteDomain(), before))
    }

    @Test func aSystemQuitEndsWhileTheDialogAsksTheInstallIsHeldAndTheFailureShows() {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)

        let asking = world.launch(.byHand, placement: .elsewhere)
        #expect(asking.shouldEnd(.system))

        let moving = world.launch(.byHand, placement: .elsewhere)
        moving.answer(.move)
        #expect(moving.shouldEnd(.system))
        #expect(!moving.shouldEnd(.other))

        let failed = world.launch(.byHand, placement: .elsewhere)
        failed.answer(.move)
        failed.releaseInstall(.failed(reason: "No."))
        #expect(failed.shouldEnd(.system))
        #expect(failed.shouldEnd(.other))
    }

    /// Whatever the move does, a kill between any two of its effects leaves either the Mac as it was before, with the
    /// original opened again, or an installed copy that converges on the uncrashed run's end state when opened.
    private func convergesAfterAKillAnywhereIn(_ world: LifecycleWorld, others: [RunningCopy]) {
        let before = world.snapshot()
        let process = world.launch(.byHand, others: others, placement: .elsewhere)
        process.answer(.move)
        process.releaseInstall(.installed)
        for copy in others { process.letExit(copy.id) }
        let installedAt = world.installedAt!
        let left = [before] + world.snapshots + [world.snapshot()]

        func end(from snapshot: LifecycleWorld.Snapshot, placement: Placement) -> (
            isOn: Bool, keys: Set<String>, record: Settings?
        ) {
            let mac = LifecycleWorld(restoring: snapshot)
            mac.launch(.byHand, placement: placement)
            return (mac.loginItem.isOn, Set(mac.mac.suiteDomain().keys), mac.mac.freshStore().load())
        }

        let uncrashed = end(from: left.last!, placement: .installed)
        #expect(left.count > 3)
        for (index, snapshot) in left.enumerated() {
            if index <= installedAt {
                let restored = LifecycleWorld(restoring: snapshot)
                #expect(sameSuite(restored.mac.suiteDomain(), before.suite), "suite after a kill at effect \(index)")
                #expect(restored.loginItem.isOn == before.loginItemIsOn, "login item after a kill at effect \(index)")
                let reopened = end(from: snapshot, placement: .elsewhere)
                #expect(reopened.isOn == before.loginItemIsOn, "login item reopening after a kill at effect \(index)")
            } else {
                let converged = end(from: snapshot, placement: .installed)
                #expect(converged.isOn == uncrashed.isOn, "login item after a kill at effect \(index)")
                #expect(converged.keys == ["settings"], "suite after a kill at effect \(index)")
                #expect(converged.record == uncrashed.record, "record after a kill at effect \(index)")
            }
        }
    }

    @Test func aKillAnywhereInAFirstMoveConverges() {
        convergesAfterAKillAnywhereIn(LifecycleWorld(accessGranted: false, loginItemOn: false), others: [])
    }

    @Test func aKillAnywhereInAMoveOverAnOlderCopyConverges() {
        convergesAfterAKillAnywhereIn(
            LifecycleWorld(record: [.one: "Arc"], handMode: .left, loginItemOn: true), others: [.earlier])
    }
}
