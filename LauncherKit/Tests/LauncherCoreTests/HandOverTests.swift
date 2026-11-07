import Foundation
import LauncherCore
import Testing

@MainActor @Suite struct HandOverTests {
    private static let rightThumb = (x: 114.8, y: 10.0)

    private func armings(_ world: LifecycleWorld) -> Int {
        world.log.entries.filter { $0.hasPrefix("arm restart") }.count
    }

    private func seededWorld() -> LifecycleWorld {
        LifecycleWorld(
            record: [.one: "Arc"], corner: .topRight, hidesBackgroundApps: true, loginItemOn: true)
    }

    private func heldLogin(_ world: LifecycleWorld) throws -> OneProcess {
        let process = try #require(world.login(running: .release))
        process.engine.push(.held)
        return process
    }

    @Test(arguments: [true, false])
    func aHeldUpdateHandsOverInTheSameTurnWhateverTheTrackpadDoesAndTheWindowDecidesTheHandOver(windowOpen: Bool) throws {
        let world = seededWorld()
        let process = try #require(world.login(running: .release))
        process.restTwoFingers()
        process.openAgain(.byHand)
        if !windowOpen { process.closeWindow() }
        let before = world.log.entries.count

        process.engine.push(.held)

        let armed = windowOpen ? "arm restart with window" : "arm restart"
        #expect(Array(world.log.entries.dropFirst(before)) == [armed, "end"])
        #expect(process.engine.arms == [windowOpen])
        #expect(process.engine.overlaps == 0)
    }

    @Test func aHeldUpdateAtALoginWithNeverAnOpenedWindowArmsSilently() throws {
        let world = seededWorld()

        let process = try heldLogin(world)

        #expect(process.engine.arms == [false])
        #expect(world.log.entries.suffix(2) == ["arm restart", "end"])
        #expect(process.engine.overlaps == 0)
    }

    @Test func aRefusedRestartDiscardsTheHeldUpdateAndLeavesTheProcessRunningWithoutEnding() throws {
        let world = seededWorld()
        let process = try #require(world.login(running: .release))
        process.engine.armWorks = false

        process.engine.push(.held)

        #expect(world.log.entries.suffix(2) == ["arm restart", "discard"])
        #expect(process.engine.discards == 1)
        #expect(armings(world) == 1)
        #expect(!process.copies.hasEnded)
        process.tap(1, thumbAtMM: Self.rightThumb)
        #expect(process.system.broughtToFront == [world.mac.app("Arc")])

        process.engine.push(.cycleEnded(.failed))

        #expect(!process.connection.isWatching)
        #expect(process.card == nil)
        #expect(armings(world) == 1)
        #expect(!world.log.entries.contains("end"))
        #expect(process.engine.overlaps == 0)
    }

    @Test func aDownloadRefusedBeforeAnyHoldEndsTheCycleWithNothingArmedOrShown() throws {
        let world = seededWorld()
        let process = try #require(world.login(running: .release))

        process.engine.push(.cycleEnded(.failed))

        #expect(process.engine.discards == 0)
        #expect(armings(world) == 0)
        #expect(!process.connection.isWatching)
        #expect(process.card == nil)
        #expect(!process.copies.hasEnded)
        #expect(process.engine.overlaps == 0)
    }

    @Test(arguments: [true, false])
    func aShutdownWithAnUpdateWaitingLeavesItWaitingForTheNextStart(newVersion: Bool) throws {
        let world = seededWorld()
        let waiting = try heldLogin(world)
        #expect(waiting.shouldEnd(.system))

        let next = try #require(world.login(running: .release))
        #expect(next.engine.updates == 1)
        if !newVersion {
            next.engine.push(.held)
            #expect(world.log.entries.suffix(2) == ["arm restart", "end"])
        }
        #expect(next.windows == [.closed])
        #expect(world.permissions.asks.isEmpty)
        next.tap(1, thumbAtMM: Self.rightThumb)
        #expect(next.system.broughtToFront == [world.mac.app("Arc")])
    }

    @Test func theSilentHandOverEndsTheOldCopyAndTheNewOneStartsSilentlyWithEverythingCarriedOver() throws {
        let world = seededWorld()
        let seedSuite = world.mac.suiteDomain()
        let seedPermissions = world.permissions.granted
        _ = try heldLogin(world)

        #expect(world.log.entries.suffix(2) == ["arm restart", "end"])
        #expect(world.loginItem.calls.isEmpty)
        #expect(NSDictionary(dictionary: world.mac.suiteDomain()) == NSDictionary(dictionary: seedSuite))

        let new = world.finishHandOver()

        #expect(new.windows == [.closed])
        #expect(new.moveDialog == nil)
        #expect(world.permissions.asks.isEmpty)
        #expect(world.permissions.granted == seedPermissions)
        #expect(new.engine.probes == 0)
        #expect(new.engine.updates == 0)
        #expect(world.loginItem.calls.isEmpty)
        #expect(new.launcher.thumbCorner == .topRight)
        #expect(new.launcher.isHideBackgroundAppsOn)
        new.tap(1, thumbAtMM: Self.rightThumb)
        #expect(new.system.broughtToFront == [world.mac.app("Arc")])
        #expect(new.engine.overlaps == 0)
    }

    @Test func aWindowOpenAtTheMomentTheOldVersionStopsBringsTheNewOneUpWithItsWindowAndNoCheck() throws {
        let world = seededWorld()
        let process = try #require(world.login(running: .release))
        process.openAgain(.byHand)
        #expect(process.window == .open(request: 1))
        #expect(process.engine.probes == 0)
        #expect(process.card == nil)
        process.closeWindow()
        process.openAgain(.byHand)
        #expect(process.engine.probes == 0)
        #expect(process.engine.updates == 1)

        process.engine.push(.held)
        #expect(process.engine.arms == [true])

        let new = world.finishHandOver(withWindow: true)

        #expect(new.windows.last == .open(request: 1))
        #expect(new.engine.probes == 0)
        #expect(new.engine.updates == 0)
        #expect(new.card == nil)
        #expect(process.engine.overlaps == 0)
        #expect(new.engine.overlaps == 0)
    }

    @Test func theNewCopyTakesTheWindowFlagTheOldCopyArmedWith() throws {
        let world = seededWorld()
        let process = try #require(world.login(running: .release))
        process.openAgain(.byHand)
        process.engine.push(.held)

        let new = world.finishHandOver()

        #expect(new.window == .open(request: 1))
    }

    @Test func aProcessKilledAroundTheArmingLeavesAMacThatStartsEitherWayAsUsual() throws {
        let world = seededWorld()
        let seedSuite = world.mac.suiteDomain()
        let seedPermissions = world.permissions.granted
        _ = try heldLogin(world)
        let aroundArming = Array(world.snapshots.suffix(2))
        #expect(aroundArming.count == 2)

        for snapshot in aroundArming {
            let atLogin = LifecycleWorld(restoring: snapshot, apps: ["Arc", "Notes"])
            #expect(NSDictionary(dictionary: atLogin.mac.suiteDomain()) == NSDictionary(dictionary: seedSuite))
            #expect(atLogin.permissions.granted == seedPermissions)
            let silent = try #require(atLogin.login(running: .release))
            #expect(silent.windows == [.closed])
            silent.tap(1, thumbAtMM: Self.rightThumb)
            #expect(silent.hardware.feedback == [Trackpad.macBook14.id])

            let byHand = LifecycleWorld(restoring: snapshot, apps: ["Arc", "Notes"])
            let opened = byHand.launch(.byHand, running: .release)
            #expect(opened.windows == [.open(request: 1)])
            #expect(byHand.permissions.asks.isEmpty)
        }
    }

    @Test func openingTheNewCopyByHandAfterwardsOpensTheWindowAsUsual() throws {
        let world = seededWorld()
        _ = try heldLogin(world)
        let new = world.finishHandOver()

        new.openAgain(.byHand)

        #expect(new.window == .open(request: 1))
    }

    nonisolated struct RouteRow: Sendable, CustomTestStringConvertible {
        let opening: Opening
        let placement: Placement
        let olderCopyRuns: Bool
        let route: Route
        var testDescription: String { "\(opening) \(placement) olderCopyRuns \(olderCopyRuns)" }
    }

    nonisolated static let routeTable: [RouteRow] = [
        RouteRow(opening: .atLogin, placement: .installed, olderCopyRuns: true, route: .end),
        RouteRow(opening: .atLogin, placement: .installed, olderCopyRuns: false, route: .runSilently),
        RouteRow(opening: .atLogin, placement: .development, olderCopyRuns: true, route: .end),
        RouteRow(opening: .atLogin, placement: .development, olderCopyRuns: false, route: .runSilently),
        RouteRow(opening: .atLogin, placement: .elsewhere, olderCopyRuns: true, route: .end),
        RouteRow(opening: .atLogin, placement: .elsewhere, olderCopyRuns: false, route: .runSilently),
        RouteRow(opening: .byHand, placement: .installed, olderCopyRuns: true, route: .runWithWindow),
        RouteRow(opening: .byHand, placement: .installed, olderCopyRuns: false, route: .runWithWindow),
        RouteRow(opening: .byHand, placement: .development, olderCopyRuns: true, route: .runWithWindow),
        RouteRow(opening: .byHand, placement: .development, olderCopyRuns: false, route: .runWithWindow),
        RouteRow(opening: .byHand, placement: .elsewhere, olderCopyRuns: true, route: .askToMove),
        RouteRow(opening: .byHand, placement: .elsewhere, olderCopyRuns: false, route: .askToMove),
        RouteRow(opening: .afterUpdate(withWindow: false), placement: .installed, olderCopyRuns: true, route: .runSilently),
        RouteRow(opening: .afterUpdate(withWindow: false), placement: .installed, olderCopyRuns: false, route: .runSilently),
        RouteRow(opening: .afterUpdate(withWindow: false), placement: .development, olderCopyRuns: true, route: .runWithWindow),
        RouteRow(opening: .afterUpdate(withWindow: false), placement: .development, olderCopyRuns: false, route: .runWithWindow),
        RouteRow(opening: .afterUpdate(withWindow: false), placement: .elsewhere, olderCopyRuns: true, route: .askToMove),
        RouteRow(opening: .afterUpdate(withWindow: false), placement: .elsewhere, olderCopyRuns: false, route: .askToMove),
        RouteRow(opening: .afterUpdate(withWindow: true), placement: .installed, olderCopyRuns: true, route: .runWithWindow),
        RouteRow(opening: .afterUpdate(withWindow: true), placement: .installed, olderCopyRuns: false, route: .runWithWindow),
        RouteRow(opening: .afterUpdate(withWindow: true), placement: .development, olderCopyRuns: true, route: .runWithWindow),
        RouteRow(opening: .afterUpdate(withWindow: true), placement: .development, olderCopyRuns: false, route: .runWithWindow),
        RouteRow(opening: .afterUpdate(withWindow: true), placement: .elsewhere, olderCopyRuns: true, route: .askToMove),
        RouteRow(opening: .afterUpdate(withWindow: true), placement: .elsewhere, olderCopyRuns: false, route: .askToMove),
    ]

    @Test(arguments: routeTable)
    func everyOpeningPlacementAndOlderCopyRoutesAsTheTableSays(row: RouteRow) {
        #expect(Route(row.opening, placement: row.placement, olderCopyRuns: row.olderCopyRuns) == row.route)
    }

    @Test(arguments: [false, true])
    func anAfterUpdateStartStopsOtherCopiesInsteadOfEndingLikeALoginStartWould(withWindow: Bool) {
        let world = seededWorld()
        let process = world.launch(.afterUpdate(withWindow: withWindow), others: [.earlier], running: .release)

        #expect(process.copies.stopped == [.earlier])
        #expect(!process.copies.hasEnded)
        #expect(process.engine.updates == 0)

        process.letExit(RunningCopy.earlier.id)

        #expect(process.window == (withWindow ? .open(request: 1) : .closed))
        #expect(process.engine.updates == 0)
        #expect(process.engine.probes == 0)
    }

    @Test func aFailedInstallBringsTheOldVersionBackSilentlyWithoutCheckingAndAHoldHandsOverAgain() throws {
        let world = seededWorld()
        _ = try heldLogin(world)

        let back = world.finishHandOver(installed: false)

        #expect(back.windows == [.closed])
        #expect(back.engine.updates == 0)
        #expect(back.engine.probes == 0)
        #expect(back.card == nil)
    }

    @Test func quitEndsTheProcessAndNeverArmsARestartInEitherLoginPhase() throws {
        for awaitingConnection in [false, true] {
            let world = seededWorld()
            let process = try #require(world.login(running: .release))
            if awaitingConnection { process.engine.push(.cycleEnded(.requestFailed)) }
            #expect(process.connection.isWatching == awaitingConnection)
            process.openAgain(.byHand)
            process.closeWindow()

            process.quit()

            #expect(process.copies.hasEnded)
            #expect(!world.loginItem.isOn)
            #expect(armings(world) == 0)
            #expect(world.login() == nil)
            #expect(process.engine.overlaps == 0)
        }
    }

    @Test func quitThenOpeningByHandTurnsStartingAtLoginBackOn() throws {
        let world = seededWorld()
        let process = try #require(world.login(running: .release))
        process.quit()

        let again = world.launch(.byHand)

        #expect(again.window == .open(request: 1))
        #expect(world.loginItem.isOn)
    }

    @Test(arguments: [false, true])
    func aSystemEndIsAlwaysAllowedAndAnotherCopysStopClosesTheWindowFirstInEveryLoginPhase(awaitingConnection: Bool) throws {
        for windowOpen in [false, true] {
            let world = seededWorld()
            let process = try #require(world.login(running: .release))
            if awaitingConnection { process.engine.push(.cycleEnded(.requestFailed)) }
            if windowOpen { process.openAgain(.byHand) }

            #expect(process.shouldEnd(.system))
            #expect(armings(world) == 0)
            if windowOpen {
                #expect(!process.shouldEnd(.other))
                #expect(process.window == .closed)
            }
            #expect(process.shouldEnd(.other))
            #expect(armings(world) == 0)
        }
    }

    @Test func anOrdinaryQuitClosesOnlyTheWindowAndASystemQuitAlwaysEnds() {
        let world = seededWorld()
        let process = world.launch(.byHand, running: .release)

        #expect(!process.shouldEnd(.other))
        #expect(process.window == .closed)
        #expect(process.shouldEnd(.other))
        #expect(process.shouldEnd(.system))
        #expect(armings(world) == 0)

        let open = world.launch(.byHand, running: .release)
        #expect(open.shouldEnd(.system))
    }

    @Test func afterAHandOverEndedTheProcessEveryWayOfQuittingAnswersYes() throws {
        let world = seededWorld()
        let old = try heldLogin(world)

        #expect(old.shouldEnd(.other))
        #expect(old.shouldEnd(.system))
    }
}
