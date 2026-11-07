import Foundation
import LauncherCore
import Testing

@MainActor @Suite struct UpdateWaitsTests {
    private static let minute = Duration.seconds(60)

    private func heldWorld(
        _ opening: Opening = .atLogin, attached: [Trackpad] = [.macBook14]
    ) -> (world: LifecycleWorld, process: OneProcess) {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let process = world.launch(opening, running: .release, attached: attached)
        return (world, process)
    }

    private func handOvers(_ world: LifecycleWorld) -> [String] {
        world.log.entries.filter { $0 == "arm restart" || $0 == "end" }
    }

    @Test func aUserWorkingOnTheTrackpadKeepsTheUpdateWaiting() {
        let (world, process) = heldWorld()
        process.engine.push(.held(.genuine))

        for _ in 0..<3 {
            process.touch(.finger)
            process.idleClock.advance(by: .seconds(59))
            process.lift()
            process.idleClock.advance(by: .seconds(59))
            #expect(handOvers(world).isEmpty)
        }
        process.touch(.finger)
        process.lift()
        process.idleClock.advance(by: .seconds(59))
        #expect(handOvers(world).isEmpty)
        process.idleClock.advance(by: .seconds(1))

        #expect(handOvers(world) == ["arm restart", "end"])
    }

    @Test func anOpenSettingsWindowBlocksEveryInstall() {
        let (world, process) = heldWorld(.byHand)
        process.engine.push(.held(.genuine))

        process.idleClock.advance(by: .seconds(600))

        #expect(process.idleClock.pending == nil)
        #expect(process.idleClock.waits.isEmpty)
        #expect(handOvers(world).isEmpty)
    }

    @Test func theMinuteCountsFromTheWindowClosingWhenItClosesLast() {
        let (world, process) = heldWorld(.byHand)
        process.engine.push(.held(.genuine))
        process.idleClock.advance(by: .seconds(600))

        process.closeWindow()
        process.idleClock.advance(by: .seconds(59))
        #expect(handOvers(world).isEmpty)
        process.idleClock.advance(by: .seconds(1))

        #expect(handOvers(world) == ["arm restart", "end"])
    }

    @Test func theMinuteCountsFromTheLiftWhenTheFingerLeavesLast() {
        let (world, process) = heldWorld(.byHand)
        process.engine.push(.held(.genuine))
        process.touch(.finger)

        process.closeWindow()
        process.idleClock.advance(by: .seconds(30))
        process.lift()
        process.idleClock.advance(by: .seconds(59))
        #expect(handOvers(world).isEmpty)
        process.idleClock.advance(by: .seconds(1))

        #expect(handOvers(world) == ["arm restart", "end"])
    }

    @Test func reopeningTheWindowDuringTheMinuteStartsItAgainOnClosing() {
        let (world, process) = heldWorld(.byHand)
        process.engine.push(.held(.genuine))
        process.closeWindow()

        process.idleClock.advance(by: .seconds(30))
        process.openAgain(.byHand)
        process.idleClock.advance(by: .seconds(600))
        #expect(handOvers(world).isEmpty)
        process.closeWindow()
        process.idleClock.advance(by: .seconds(59))
        #expect(handOvers(world).isEmpty)
        process.idleClock.advance(by: .seconds(1))

        #expect(handOvers(world) == ["arm restart", "end"])
    }

    @Test func bringingAnOpenWindowToTheFrontRestartsNothing() {
        let (_, process) = heldWorld(.byHand)
        process.engine.push(.held(.genuine))
        process.closeWindow()
        process.openAgain(.byHand)
        let waits = process.idleClock.waits

        process.openAgain(.byHand)
        process.openAgain(.byHand)

        #expect(process.idleClock.waits == waits)
        #expect(process.idleClock.pending == nil)
    }

    @Test func nothingWaitsUntilAnUpdateIsHeld() {
        let (_, process) = heldWorld()

        process.idleClock.advance(by: .seconds(3600))

        #expect(process.idleClock.waits.isEmpty)
    }

    @Test(arguments: [[], [Trackpad.macBook14]])
    func aMacWithNoTrackpadInUseHandsOverAMinuteAfterTheHold(attached: [Trackpad]) {
        let (world, process) = heldWorld(attached: attached)

        process.engine.push(.held(.genuine))

        #expect(process.idleClock.pending == Self.minute)
        process.idleClock.advance(by: Self.minute)
        #expect(handOvers(world) == ["arm restart", "end"])
    }

    @Test func contactIsSensedOnlyWhileAGenuineUpdateIsHeld() {
        let (world, process) = heldWorld(.byHand)
        var sensing: [Bool] = []
        process.hardware.onSensesContactSet = { sensing.append(process.hardware.sensesContact) }

        for _ in 0..<100 {
            process.tap(1)
            process.openAgain(.byHand)
            process.closeWindow()
            process.engine.push(.cycleEnded(.failed))
        }
        process.engine.push(.held(.notGenuine))

        #expect(sensing.isEmpty)
        #expect(!process.hardware.sensesContact)
        #expect(process.idleClock.waits.isEmpty)

        process.engine.push(.held(.genuine))
        #expect(process.hardware.sensesContact)
        process.engine.push(.held(.genuine))
        #expect(process.hardware.sensesContact)
        process.engine.push(.cycleEnded(.nothingNew))
        #expect(!process.hardware.sensesContact)

        process.engine.push(.held(.genuine))
        process.lift()
        process.idleClock.pass()
        #expect(handOvers(world) == ["arm restart", "end"])
        #expect(!process.hardware.sensesContact)
    }

    @Test func aNotGenuineUpdateIsDiscardedFirstAndNothingWaitsOrShowsOrRestarts() {
        let (world, process) = heldWorld(.byHand)
        let window = process.window

        process.engine.push(.held(.notGenuine))

        #expect(world.log.entries.last == "discard")
        #expect(process.engine.discards == 1)
        #expect(!process.hardware.sensesContact)
        #expect(process.idleClock.pending == nil)
        #expect(process.window == window)
        process.idleClock.advance(by: .seconds(3600))
        #expect(process.idleClock.waits.isEmpty)
        process.engine.push(.cycleEnded(.failed))
        #expect(process.idleClock.waits.isEmpty)
        #expect(process.window == window)
        #expect(handOvers(world).isEmpty)

        process.engine.push(.held(.genuine))
        #expect(process.idleClock.pending == nil)
        process.closeWindow()
        #expect(process.idleClock.pending == Self.minute)
    }

    @Test func quittingRightAfterANotGenuineVerdictDiscardsBeforeEndingAndArmsNothing() {
        let (world, process) = heldWorld()

        process.engine.push(.held(.notGenuine))
        process.quit()

        let entries = world.log.entries
        let discard = entries.firstIndex(of: "discard")
        let end = entries.firstIndex(of: "end")
        #expect(discard != nil && end != nil && discard! < end!)
        #expect(!entries.contains("arm restart"))
    }

    @Test func aLiftLandingAsSensingTurnsOnIsNeitherLostNorStuck() {
        let (_, process) = heldWorld()
        process.touch(.finger)
        process.hardware.onSensesContactSet = {
            if process.hardware.sensesContact { process.lift() }
        }

        process.engine.push(.held(.genuine))

        #expect(process.idleClock.pending == Self.minute)
    }

    @Test func theFireReadsTheLevelWhenAnEdgeIsStillQueued() {
        let (world, process) = heldWorld()
        process.engine.push(.held(.genuine))
        process.hardware.holdContactEdges()

        process.touch(.finger)
        process.idleClock.advance(by: Self.minute)

        #expect(handOvers(world).isEmpty)
        process.hardware.releaseContactEdges()
        #expect(process.idleClock.pending == nil)

        process.lift()
        process.idleClock.advance(by: Self.minute)
        #expect(handOvers(world) == ["arm restart", "end"])
    }

    @Test func aWakeReplacingTheSessionsRestartsTheMinuteAndARestingFingerCancelsIt() {
        let (world, process) = heldWorld()
        process.touch(.finger)
        process.engine.push(.held(.genuine))
        process.hardware.holdContactEdges()
        process.lift()

        process.wake()

        #expect(process.idleClock.pending == Self.minute)
        process.hardware.releaseContactEdges()
        process.touch(.finger)
        #expect(process.idleClock.pending == nil)
        #expect(handOvers(world).isEmpty)
    }

    enum Reset: CaseIterable, Sendable { case wake, preference, permission }

    @Test(arguments: Reset.allCases)
    func aRunThatChangesRestartsTheMinute(reset: Reset) {
        let (world, process) = heldWorld()
        process.engine.push(.held(.genuine))
        process.idleClock.advance(by: .seconds(30))

        switch reset {
        case .wake: process.wake()
        case .preference: process.preferences.set(.tapToClick, rawValue: 1, for: .builtIn)
        case .permission: world.permissions.set(.accessibility, granted: false)
        }
        process.idleClock.advance(by: .seconds(59))
        #expect(handOvers(world).isEmpty)
        process.idleClock.advance(by: .seconds(1))

        #expect(handOvers(world) == ["arm restart", "end"])
    }

    @Test func aFailedCycleDropsTheWaitAndASecondHoldStartsItAgain() {
        let (world, process) = heldWorld()
        process.engine.push(.held(.genuine))
        #expect(process.idleClock.pending == Self.minute)

        process.engine.push(.cycleEnded(.failed))

        #expect(process.idleClock.pending == nil)
        #expect(!process.hardware.sensesContact)
        process.idleClock.advance(by: .seconds(3600))
        #expect(handOvers(world).isEmpty)

        process.engine.push(.held(.genuine))
        #expect(process.idleClock.pending == Self.minute)
    }

    @Test func aRefusedRestartKeepsTheUpdateReadyAndTheNextIdleEdgeTriesAgain() {
        let (world, process) = heldWorld()
        process.engine.armWorks = false
        process.engine.push(.held(.genuine))

        process.idleClock.advance(by: Self.minute)

        #expect(handOvers(world) == ["arm restart"])
        process.touch(.finger)
        process.lift()
        process.engine.armWorks = true
        process.idleClock.advance(by: Self.minute)
        #expect(handOvers(world) == ["arm restart", "arm restart", "end"])
    }
}
