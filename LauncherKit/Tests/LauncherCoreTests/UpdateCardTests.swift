import Foundation
import LauncherCore
import Testing

@MainActor @Suite struct UpdateCardTests {
    private func world() -> LifecycleWorld {
        LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
    }

    /// A signed copy in /Applications started by hand: its start's probe runs.
    private func byHand(_ world: LifecycleWorld) -> OneProcess {
        world.launch(.byHand, running: .release)
    }

    private func armings(_ world: LifecycleWorld) -> Int {
        world.log.entries.filter { $0.hasPrefix("arm restart") }.count
    }

    /// A by-hand resident whose card shows.
    private func offering(_ world: LifecycleWorld) -> OneProcess {
        let process = byHand(world)
        process.engine.push(.cycleEnded(.found("1.1.23")))
        return process
    }

    /// A by-hand resident whose *Update now* runs.
    private func updating(_ world: LifecycleWorld) -> OneProcess {
        let process = offering(world)
        process.updater.updateNow()
        return process
    }

    @Test func aStartByHandMakesOneCheckAndNoUpdate() {
        let process = byHand(world())

        #expect(process.engine.probes == 1)
        #expect(process.engine.updates == 0)
        #expect(process.window == .open(request: 1))
        #expect(process.card == nil)
        #expect(process.engine.overlaps == 0)
    }

    @Test func eachOpeningChecksOnceAndAReFrontChecksNothing() {
        let process = byHand(world())
        process.engine.push(.cycleEnded(.nothingNew))

        process.closeWindow()
        process.openAgain(.byHand)

        #expect(process.engine.probes == 2)
        #expect(process.card == nil)
        process.engine.push(.cycleEnded(.nothingNew))
        process.openAgain(.byHand)
        #expect(process.engine.probes == 2)

        process.closeWindow()
        process.openAgain(.byHand)
        #expect(process.engine.probes == 3)
        process.closeWindow()
        process.engine.push(.cycleEnded(.found("1.1.23")))
        #expect(process.card == nil)
        process.openAgain(.byHand)
        #expect(process.engine.probes == 4)
        #expect(process.card == nil)
        #expect(process.engine.overlaps == 0)
    }

    @Test func aWindowReopenedBeforeTheDroppedCheckAnswersAddsNoCheckAndTakesItsAnswer() {
        let process = byHand(world())

        process.closeWindow()
        process.openAgain(.byHand)

        #expect(process.engine.probes == 1)
        #expect(process.card == nil)
        process.engine.push(.cycleEnded(.found("1.1.23")))
        #expect(process.card == .available)
        #expect(process.engine.overlaps == 0)
    }

    @Test func aCheckThatFailsOnACopyThatCannotWriteShowsNothingAndWatchesNothing() {
        let process = world().launch(.byHand, running: .release(canWrite: false))

        process.engine.push(.cycleEnded(.requestFailed))

        #expect(process.card == nil)
        #expect(!process.connection.isWatching)
        #expect(process.engine.overlaps == 0)
    }

    @Test func aFoundUpdateShowsTheCardDownloadsNothingAndGoesWithTheWindow() {
        let process = byHand(world())
        #expect(process.engine.updates == 0)

        process.engine.push(.cycleEnded(.found("1.1.23")))

        #expect(process.card == .available)
        #expect(process.engine.updates == 0)
        process.closeWindow()
        #expect(process.card == nil)
        #expect(process.engine.overlaps == 0)
    }

    @Test func aLoginCheckFailedForTheNetworkLeavesTheWindowsCheckToTakeOverItsRetry() throws {
        let world = world()
        let process = try #require(world.login(running: .release))
        process.engine.push(.cycleEnded(.requestFailed))
        #expect(process.connection.isWatching)

        process.openAgain(.byHand)

        #expect(!process.connection.isWatching)
        #expect(process.engine.probes == 1)
        process.engine.push(.cycleEnded(.requestFailed))
        #expect(process.connection.isWatching)
        #expect(process.card == nil)
        process.connection.set(true)
        #expect(process.engine.updates == 2)
        #expect(process.engine.overlaps == 0)
    }

    @Test func aCheckThatDroppedWhileTheLoginRetryWasOwedDoesNotRunItBeforeItsAnswer() throws {
        let process = try #require(world().login(running: .release))
        process.engine.push(.cycleEnded(.requestFailed))
        process.openAgain(.byHand)
        process.closeWindow()

        process.connection.set(true)
        #expect(process.engine.updates == 1)

        process.engine.push(.cycleEnded(.requestFailed))
        #expect(process.connection.isWatching)
        #expect(process.engine.updates == 2)
        #expect(process.engine.overlaps == 0)
    }

    @Test func aRetryAlreadySpentOnASteadyReadingStaysSpentThroughTheWindowsCheck() throws {
        let process = try #require(world().login(running: .release))
        process.engine.push(.cycleEnded(.requestFailed))
        process.connection.set(true)
        #expect(process.engine.updates == 2)
        process.engine.push(.cycleEnded(.requestFailed))

        process.openAgain(.byHand)
        process.engine.push(.cycleEnded(.requestFailed))

        #expect(process.connection.isWatching)
        #expect(process.engine.updates == 2)
        process.connection.set(false)
        process.connection.set(true)
        #expect(process.engine.updates == 3)
        #expect(process.engine.overlaps == 0)
    }

    @Test func aCheckThatFindsNothingSettlesTheLoginRetryForEver() throws {
        let process = try #require(world().login(running: .release))
        process.engine.push(.cycleEnded(.requestFailed))
        process.openAgain(.byHand)

        process.engine.push(.cycleEnded(.nothingNew))

        #expect(!process.connection.isWatching)
        process.connection.set(false)
        process.connection.set(true)
        #expect(!process.connection.isWatching)
        #expect(process.engine.updates == 1)
    }

    struct GateRow: Sendable, CustomTestStringConvertible {
        let placement: Placement
        let signed: Bool
        let canWrite: Bool
        let probes: Int
        var testDescription: String { "\(placement) signed=\(signed) canWrite=\(canWrite)" }
    }

    nonisolated static let gateRows: [GateRow] = [
        GateRow(placement: .installed, signed: true, canWrite: true, probes: 1),
        GateRow(placement: .installed, signed: true, canWrite: false, probes: 1),
        GateRow(placement: .installed, signed: false, canWrite: true, probes: 0),
        GateRow(placement: .installed, signed: false, canWrite: false, probes: 0),
        GateRow(placement: .elsewhere, signed: true, canWrite: true, probes: 0),
        GateRow(placement: .elsewhere, signed: true, canWrite: false, probes: 0),
        GateRow(placement: .elsewhere, signed: false, canWrite: true, probes: 0),
        GateRow(placement: .elsewhere, signed: false, canWrite: false, probes: 0),
        GateRow(placement: .development, signed: true, canWrite: true, probes: 0),
        GateRow(placement: .development, signed: true, canWrite: false, probes: 0),
        GateRow(placement: .development, signed: false, canWrite: true, probes: 0),
        GateRow(placement: .development, signed: false, canWrite: false, probes: 0),
    ]

    @Test(arguments: gateRows)
    func onlyASignedCopyInApplicationsChecksWhenOpenedByHand(row: GateRow) {
        let world = LifecycleWorld(accessGranted: false)
        let running = RunningBuild(developerIDSigned: row.signed, canWrite: row.canWrite)

        let process = world.launch(.byHand, placement: row.placement, running: running)

        #expect(process.engine.probes == row.probes)
        #expect(process.engine.updates == 0)
        #expect((process.ports != nil) == (row.probes == 1))
        process.engine.push(.cycleEnded(.found("1.1.23")))
        #expect((process.card != nil) == (row.probes == 1))
        #expect(process.engine.overlaps == 0)
    }

    @Test func aMoveDialogMakesNoCheckAndTheInstalledCopyItOpensChecks() {
        let world = LifecycleWorld(accessGranted: false)
        let process = world.launch(.byHand, placement: .elsewhere, running: .release)
        #expect(process.moveDialog == .asking)
        #expect(process.engine.probes == 0)

        process.answer(.move)
        process.releaseInstall(.installed)
        let moved = world.launch(.byHand, placement: .installed, running: .release)

        #expect(process.engine.probes == 0)
        #expect(moved.engine.probes == 1)
    }

    @Test func updateNowKeepsTheCardThroughACloseAndReopenWithNoCheckAndHandsOverWithTheWindow() {
        let world = world()
        let process = offering(world)

        process.updater.updateNow()

        #expect(process.engine.updates == 1)
        #expect(process.card == .updating)
        process.closeWindow()
        #expect(process.card == .updating)
        process.openAgain(.byHand)
        #expect(process.engine.probes == 1)
        #expect(process.card == .updating)
        process.closeWindow()
        let before = world.log.entries.count

        process.engine.push(.held)

        #expect(process.engine.arms == [true])
        #expect(Array(world.log.entries.dropFirst(before)) == ["arm restart with window", "end"])
        let new = world.finishHandOver(withWindow: true)
        #expect(new.window == .open(request: 1))
        #expect(new.engine.probes == 0)
        #expect(new.card == nil)
        #expect(process.engine.overlaps == 0)
    }

    @Test func updateNowOnlyActsWhileTheCardOffersIt() {
        let process = byHand(world())

        process.updater.updateNow()
        #expect(process.engine.updates == 0)

        process.engine.push(.cycleEnded(.found("1.1.23")))
        process.updater.updateNow()
        process.updater.updateNow()
        #expect(process.engine.updates == 1)
        #expect(process.engine.overlaps == 0)
    }

    @Test func aFailedUpdateReturnsTheCardWithTheWindowOpenAndNothingElse() {
        for outcome in [CycleOutcome.requestFailed, .failed] {
            let process = updating(world())

            process.engine.push(.cycleEnded(outcome))

            #expect(process.card == .available)
            #expect(!process.connection.isWatching)
            process.updater.updateNow()
            #expect(process.engine.updates == 2)
            #expect(process.engine.overlaps == 0)
        }
    }

    @Test func anUpdateThatFindsNothingNewDropsTheCard() {
        let process = updating(world())

        process.engine.push(.cycleEnded(.nothingNew))

        #expect(process.card == nil)
    }

    @Test func aRefusedRestartKeepsTheProcessWorkingAndReturnsTheCard() {
        let world = world()
        let process = updating(world)
        process.engine.armWorks = false

        process.engine.push(.held)

        #expect(process.engine.discards == 1)
        #expect(armings(world) == 0)
        #expect(!process.copies.hasEnded)
        process.tap(1)
        #expect(process.system.broughtToFront == [world.mac.app("Arc")])
        process.engine.push(.cycleEnded(.failed))
        #expect(process.card == .available)
        #expect(process.engine.overlaps == 0)
    }

    @Test func aFailedUpdateWithTheWindowClosedLeavesNoCardAndTheNextOpeningChecks() {
        let process = updating(world())
        process.closeWindow()

        process.engine.push(.cycleEnded(.failed))

        #expect(process.card == nil)
        process.openAgain(.byHand)
        #expect(process.engine.probes == 2)
        #expect(process.card == nil)
        process.engine.push(.cycleEnded(.found("1.1.23")))
        #expect(process.card == .available)
        #expect(process.engine.overlaps == 0)
    }

    @Test func aSwapThatFailedBringsTheOldVersionBackWithItsWindowAndNoCheck() {
        let world = world()
        let process = updating(world)
        process.engine.push(.held)

        let back = world.finishHandOver(installed: false, withWindow: true)

        #expect(back.window == .open(request: 1))
        #expect(back.engine.probes == 0)
        #expect(world.installedAt == nil)
    }

    private enum Stage: CaseIterable { case probe, card, updating }

    private func process(at stage: Stage, in world: LifecycleWorld) -> OneProcess {
        switch stage {
        case .probe: byHand(world)
        case .card: offering(world)
        case .updating: updating(world)
        }
    }

    @Test(arguments: Stage.allCases)
    private func quitEndsTheAppAtOnceInAnyStageAndArmsNothing(stage: Stage) {
        let world = world()
        let process = process(at: stage, in: world)

        process.quit()

        #expect(process.copies.hasEnded)
        #expect(!world.loginItem.isOn)
        #expect(armings(world) == 0)
        #expect(world.login() == nil)
    }

    @Test(arguments: Stage.allCases)
    private func aSystemEndNeverWaitsAndAnotherQuitOnlyClosesAnOpenWindow(stage: Stage) {
        for windowOpen in [true, false] {
            let world = world()
            let process = process(at: stage, in: world)
            if !windowOpen { process.closeWindow() }
            #expect(process.shouldEnd(.system))
            #expect(armings(world) == 0)
        }

        let world = world()
        let process = process(at: stage, in: world)
        #expect(!process.shouldEnd(.other))
        #expect(process.window == .closed)
        #expect(process.card == (stage == .updating ? .updating : nil))
        #expect(process.shouldEnd(.other))
    }

    @Test func theCardsTextAndButtonFollowItsState() {
        #expect(UpdateCard.available.text == "Update available")
        #expect(UpdateCard.updating.text == "Update available")
        #expect(UpdateCard.available.buttonTitle == "Update now")
        #expect(UpdateCard.available.isButtonEnabled)
        #expect(UpdateCard.updating.buttonTitle == "Updating…")
        #expect(!UpdateCard.updating.isButtonEnabled)
    }
}
