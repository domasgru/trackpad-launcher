import Foundation
import LauncherCore
import Testing

@MainActor @Suite struct UpdaterStartTests {
    struct Row: Sendable, CustomTestStringConvertible {
        let placement: Placement
        let signed: Bool
        let canWrite: Bool
        let updates: Bool
        var testDescription: String { "\(placement) signed=\(signed) canWrite=\(canWrite)" }
    }

    nonisolated static let rows: [Row] = [
        Row(placement: .installed, signed: true, canWrite: true, updates: true),
        Row(placement: .installed, signed: true, canWrite: false, updates: false),
        Row(placement: .installed, signed: false, canWrite: true, updates: false),
        Row(placement: .installed, signed: false, canWrite: false, updates: false),
        Row(placement: .elsewhere, signed: true, canWrite: true, updates: false),
        Row(placement: .elsewhere, signed: true, canWrite: false, updates: false),
        Row(placement: .elsewhere, signed: false, canWrite: true, updates: false),
        Row(placement: .elsewhere, signed: false, canWrite: false, updates: false),
        Row(placement: .development, signed: true, canWrite: true, updates: false),
        Row(placement: .development, signed: true, canWrite: false, updates: false),
        Row(placement: .development, signed: false, canWrite: true, updates: false),
        Row(placement: .development, signed: false, canWrite: false, updates: false),
    ]

    private static let engineEntries: Set<String> = ["engine start", "check", "discard", "arm restart"]

    @Test(arguments: rows, [Opening.atLogin, .byHand])
    func onlyAnInstalledSignedWritableCopyBuildsAnUpdaterThatStartsItsEngine(row: Row, opening: Opening) {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let running = RunningBuild(developerIDSigned: row.signed, canWrite: row.canWrite)

        let process = world.launch(opening, placement: row.placement, running: running)

        if row.updates {
            #expect(process.updater != nil)
            #expect(process.engine.starts == 1)
        } else {
            #expect(process.updater == nil)
            #expect(process.engine.starts == 0)
            #expect(process.engine.checks == 0)
            #expect(Set(world.log.entries).isDisjoint(with: Self.engineEntries))
        }
    }

    @Test func aGatedCopyStartsAndChecksInTheTurnItBecomesResident() {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)

        let atLogin = world.launch(.atLogin, running: .release)

        #expect(world.log.entries == ["engine start", "check"])
        #expect(atLogin.windows == [.closed])

        let byHand = world.launch(.byHand, running: .release)

        #expect(world.log.entries == ["engine start", "check", "engine start", "check"])
        #expect(byHand.engine.checks == 1)
        #expect(atLogin.connection.watches == 0)
        #expect(byHand.connection.watches == 0)
        #expect(atLogin.idleClock.waits.isEmpty)
        #expect(byHand.idleClock.waits.isEmpty)
    }

    @Test func openingAndClosingTheWindowAddsNoCheck() {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let process = world.launch(.atLogin, running: .release)

        for _ in 0..<3 {
            process.openAgain(.byHand)
            process.closeWindow()
        }

        #expect(process.engine.starts == 1)
        #expect(process.engine.checks == 1)
        #expect(process.connection.watches == 0)
        #expect(process.idleClock.waits.isEmpty)
    }

    @Test func aLoginStartThatEndsForAnOlderCopyNeverStartsTheEngine() {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)

        let process = world.launch(.atLogin, others: [.earlier], running: .release)

        #expect(process.copies.hasEnded)
        #expect(process.engine.starts == 0)
    }

    @Test func aCopyStillReplacingOthersStartsTheEngineOnlyOnceTheyHaveExited() {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let process = world.launch(.byHand, others: [.earlier], running: .release)

        #expect(process.engine.starts == 0)

        process.letExit(RunningCopy.earlier.id)

        #expect(process.engine.starts == 1)
        #expect(process.engine.checks == 1)
    }

    @Test func aCopyOutsideApplicationsMakesNoEngineCallUntilTheMovedCopyOpens() {
        let world = LifecycleWorld(accessGranted: false)
        let process = world.launch(.byHand, placement: .elsewhere, running: .release)

        #expect(process.updater == nil)
        #expect(process.moveDialog == .asking)

        process.answer(.move)
        process.releaseInstall(.installed)
        let moved = world.launch(.byHand, placement: .installed, running: .release)

        #expect(process.engine.starts == 0)
        #expect(process.engine.checks == 0)
        #expect(moved.engine.checks == 1)
    }

    @Test func aCopyThatCannotWriteMakesNoRequestAndAsksForNothingThenChecksOnceItCan() {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)

        let locked = world.launch(.atLogin, running: .release(canWrite: false))

        #expect(locked.engine.starts == 0)
        #expect(locked.engine.checks == 0)
        #expect(world.permissions.asks.isEmpty)
        #expect(locked.installer.installCalls == 0)
        locked.tap(1)
        #expect(locked.system.broughtToFront == [world.mac.app("Arc")])

        let next = world.launch(.atLogin, running: .release(canWrite: true))

        #expect(next.engine.checks == 1)
    }
}
