import Foundation
import LauncherCore
import Testing

@MainActor @Suite struct HandOverTests {
    private static let minute = Duration.seconds(60)
    private static let rightThumb = (x: 114.8, y: 10.0)

    private func armings(_ world: LifecycleWorld) -> Int {
        world.log.entries.filter { $0 == "arm restart" }.count
    }

    private func seededWorld() -> LifecycleWorld {
        LifecycleWorld(
            record: [.one: "Arc"], corner: .topRight, hidesBackgroundApps: true, loginItemOn: true)
    }

    private func heldLogin(_ world: LifecycleWorld) throws -> OneProcess {
        let process = try #require(world.login(running: .release))
        process.engine.push(.held(.genuine))
        return process
    }

    @Test func aRefusedRestartLeavesTheProcessRunningAndTriesAgainOnTheNextIdleEdge() throws {
        let world = seededWorld()
        let process = try heldLogin(world)
        process.engine.armWorks = false

        process.idleClock.advance(by: Self.minute)
        #expect(armings(world) == 1)
        #expect(!process.copies.hasEnded)
        #expect(process.idleClock.pending == nil)

        process.idleClock.advance(by: .seconds(3600))
        #expect(armings(world) == 1)
        process.tap(1, thumbAtMM: Self.rightThumb)
        #expect(process.system.broughtToFront == [world.mac.app("Arc")])

        process.touch(.finger)
        process.lift()
        process.engine.armWorks = true
        process.idleClock.advance(by: Self.minute)
        #expect(world.log.entries.suffix(2) == ["arm restart", "end"])
    }

    @Test(arguments: [true, false])
    func aShutdownWithAnUpdateWaitingLeavesItWaitingForTheNextStart(newVersion: Bool) throws {
        let world = seededWorld()
        let waiting = try heldLogin(world)
        #expect(waiting.shouldEnd(.system))

        let next = try #require(world.login(running: .release))
        if newVersion {
            #expect(next.idleClock.pending == nil)
        } else {
            next.engine.push(.held(.genuine))
            next.idleClock.advance(by: Self.minute)
            #expect(world.log.entries.suffix(2) == ["arm restart", "end"])
        }
        #expect(next.windows == [.closed])
        #expect(world.permissions.asks.isEmpty)
        next.tap(1, thumbAtMM: Self.rightThumb)
        #expect(next.system.broughtToFront == [world.mac.app("Arc")])
    }

    @Test func theHandOverEndsTheOldCopyAndTheNewOneStartsSilentlyWithEverythingCarriedOver() throws {
        let world = seededWorld()
        let seedSuite = world.mac.suiteDomain()
        let seedPermissions = world.permissions.granted
        let old = try heldLogin(world)

        old.idleClock.advance(by: Self.minute)

        #expect(world.log.entries.suffix(2) == ["arm restart", "end"])
        #expect(world.loginItem.calls.isEmpty)
        #expect(NSDictionary(dictionary: world.mac.suiteDomain()) == NSDictionary(dictionary: seedSuite))

        let new = world.finishHandOver()
        #expect(new.windows == [.closed])
        #expect(new.moveDialog == nil)
        #expect(world.permissions.asks.isEmpty)
        #expect(world.permissions.granted == seedPermissions)
        #expect(new.engine.starts == 1)
        #expect(new.engine.checks == 0)
        #expect(new.launcher.thumbCorner == .topRight)
        #expect(new.launcher.isHideBackgroundAppsOn)
        new.tap(1, thumbAtMM: Self.rightThumb)
        #expect(new.system.broughtToFront == [world.mac.app("Arc")])
    }

    @Test func aProcessKilledAroundTheArmingLeavesAMacThatStartsEitherWayAsUsual() throws {
        let world = seededWorld()
        let seedSuite = world.mac.suiteDomain()
        let seedPermissions = world.permissions.granted
        try heldLogin(world).idleClock.advance(by: Self.minute)
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
        try heldLogin(world).idleClock.advance(by: Self.minute)
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
        RouteRow(opening: .afterUpdate, placement: .installed, olderCopyRuns: true, route: .runSilently),
        RouteRow(opening: .afterUpdate, placement: .installed, olderCopyRuns: false, route: .runSilently),
        RouteRow(opening: .afterUpdate, placement: .development, olderCopyRuns: true, route: .runWithWindow),
        RouteRow(opening: .afterUpdate, placement: .development, olderCopyRuns: false, route: .runWithWindow),
        RouteRow(opening: .afterUpdate, placement: .elsewhere, olderCopyRuns: true, route: .askToMove),
        RouteRow(opening: .afterUpdate, placement: .elsewhere, olderCopyRuns: false, route: .askToMove),
    ]

    @Test(arguments: routeTable)
    func everyOpeningPlacementAndOlderCopyRoutesAsTheTableSays(row: RouteRow) {
        #expect(Route(row.opening, placement: row.placement, olderCopyRuns: row.olderCopyRuns) == row.route)
    }

    @Test func anAfterUpdateStartStopsOtherCopiesInsteadOfEndingLikeALoginStartWould() {
        let world = seededWorld()
        let process = world.launch(.afterUpdate, others: [.earlier], running: .release)

        #expect(process.copies.stopped == [.earlier])
        #expect(!process.copies.hasEnded)
        #expect(process.engine.starts == 0)

        process.openAgain(.byHand)
        process.letExit(RunningCopy.earlier.id)

        #expect(process.window == .open(request: 1))
        #expect(process.engine.starts == 1)
        #expect(process.engine.checks == 0)
    }

    @Test func aFailedInstallBringsTheOldVersionBackWithoutCheckingAndAHoldHandsOverAgain() throws {
        let world = seededWorld()
        try heldLogin(world).idleClock.advance(by: Self.minute)

        let back = world.finishHandOver(installed: false)

        #expect(back.windows == [.closed])
        #expect(back.engine.checks == 0)
        #expect(back.idleClock.pending == nil)
        let before = world.log.entries
        back.idleClock.advance(by: .seconds(3600))
        #expect(world.log.entries == before)

        back.engine.push(.held(.genuine))
        back.idleClock.advance(by: Self.minute)
        #expect(armings(world) == 2)
    }

    @Test(arguments: [Phase.cycleRunning, .heldInUse, .minuteRunning])
    func quitEndsTheProcessInEveryPhaseAndNeverArmsARestart(phase: Phase) throws {
        let world = seededWorld()
        let process = try #require(world.login(running: .release))
        switch phase {
        case .cycleRunning: break
        case .heldInUse:
            process.engine.push(.held(.genuine))
            process.touch(.finger)
        case .minuteRunning: process.engine.push(.held(.genuine))
        }
        process.openAgain(.byHand)
        process.closeWindow()

        process.quit()

        #expect(process.copies.hasEnded)
        #expect(!world.loginItem.isOn)
        #expect(armings(world) == 0)
        #expect(world.login() == nil)

        let again = world.launch(.byHand)
        #expect(again.window == .open(request: 1))
        #expect(world.loginItem.isOn)
    }

    @Test(arguments: [Phase.cycleRunning, .heldInUse, .minuteRunning])
    func anOrdinaryQuitClosesOnlyTheWindowAndASystemQuitAlwaysEnds(phase: Phase) throws {
        let world = seededWorld()
        let process = world.launch(.byHand, running: .release)
        if phase != .cycleRunning { process.engine.push(.held(.genuine)) }
        if phase == .heldInUse { process.touch(.finger) }

        #expect(!process.shouldEnd(.other))
        #expect(process.window == .closed)
        if phase == .minuteRunning { #expect(process.idleClock.pending == Self.minute) }
        #expect(process.shouldEnd(.other))
        #expect(process.shouldEnd(.system))
        #expect(armings(world) == 0)

        let open = world.launch(.byHand, running: .release)
        #expect(open.shouldEnd(.system))
    }

    @Test func afterAHandOverEndedTheProcessEveryWayOfQuittingAnswersYes() throws {
        let world = seededWorld()
        let old = try heldLogin(world)
        old.idleClock.advance(by: Self.minute)

        #expect(old.shouldEnd(.other))
        #expect(old.shouldEnd(.system))
    }

    enum Phase: CaseIterable { case cycleRunning, heldInUse, minuteRunning }
}
