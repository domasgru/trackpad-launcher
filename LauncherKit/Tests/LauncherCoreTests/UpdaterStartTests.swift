import Foundation
import LauncherCore
import Testing

@MainActor @Suite struct UpdaterStartTests {
    struct Row: Sendable, CustomTestStringConvertible {
        let placement: Placement
        let signed: Bool
        let canWrite: Bool
        let hasUpdater: Bool
        let updatesAtLogin: Bool
        var testDescription: String { "\(placement) signed=\(signed) canWrite=\(canWrite)" }
    }

    nonisolated static let rows: [Row] = [
        Row(placement: .installed, signed: true, canWrite: true, hasUpdater: true, updatesAtLogin: true),
        Row(placement: .installed, signed: true, canWrite: false, hasUpdater: true, updatesAtLogin: false),
        Row(placement: .installed, signed: false, canWrite: true, hasUpdater: false, updatesAtLogin: false),
        Row(placement: .installed, signed: false, canWrite: false, hasUpdater: false, updatesAtLogin: false),
        Row(placement: .elsewhere, signed: true, canWrite: true, hasUpdater: false, updatesAtLogin: false),
        Row(placement: .elsewhere, signed: true, canWrite: false, hasUpdater: false, updatesAtLogin: false),
        Row(placement: .elsewhere, signed: false, canWrite: true, hasUpdater: false, updatesAtLogin: false),
        Row(placement: .elsewhere, signed: false, canWrite: false, hasUpdater: false, updatesAtLogin: false),
        Row(placement: .development, signed: true, canWrite: true, hasUpdater: false, updatesAtLogin: false),
        Row(placement: .development, signed: true, canWrite: false, hasUpdater: false, updatesAtLogin: false),
        Row(placement: .development, signed: false, canWrite: true, hasUpdater: false, updatesAtLogin: false),
        Row(placement: .development, signed: false, canWrite: false, hasUpdater: false, updatesAtLogin: false),
    ]

    private static let engineEntries: Set<String> = [
        "probe", "update", "discard", "arm restart", "arm restart with window",
    ]

    @Test(arguments: rows)
    func atLoginOnlyASignedCopyInApplicationsThatCanWriteUpdates(row: Row) {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let running = RunningBuild(developerIDSigned: row.signed, canWrite: row.canWrite)

        let process = world.launch(.atLogin, placement: row.placement, running: running)

        #expect((process.updater != nil) == row.hasUpdater)
        #expect(process.engine.updates == (row.updatesAtLogin ? 1 : 0))
        #expect(process.engine.probes == 0)
        if !row.updatesAtLogin {
            #expect(process.connection.watches == 0)
            #expect(Set(world.log.entries).isDisjoint(with: Self.engineEntries))
        }
        #expect(process.engine.overlaps == 0)
    }

    @Test func aLoginStartUpdatesInTheTurnItBecomesResidentWithTheWindowClosed() {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)

        let atLogin = world.launch(.atLogin, running: .release)

        #expect(world.log.entries == ["update"])
        #expect(atLogin.engine.updates == 1)
        #expect(atLogin.engine.probes == 0)
        #expect(atLogin.windows == [.closed])
        #expect(atLogin.connection.watches == 0)
        #expect(atLogin.engine.overlaps == 0)
    }

    @Test(arguments: [false, true])
    func aStartAfterAnUpdateMakesNoEngineCallWhateverTheWindowDoes(withWindow: Bool) {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)

        let process = world.launch(.afterUpdate(withWindow: withWindow), running: .release)

        #expect(process.windows == [withWindow ? .open(request: 1) : .closed])
        #expect(process.engine.updates == 0)
        #expect(process.engine.probes == 0)
        #expect(process.connection.watches == 0)
        #expect(Set(world.log.entries).isDisjoint(with: Self.engineEntries))
        #expect(process.engine.overlaps == 0)
    }

    @Test func aStartByHandChecksOnceAndUpdatesNothing() {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)

        let process = world.launch(.byHand, running: .release)

        #expect(process.engine.probes == 1)
        #expect(process.engine.updates == 0)
        #expect(process.connection.watches == 0)
        #expect(process.engine.overlaps == 0)
    }

    @Test func openingAndClosingTheWindowDuringTheLoginCycleAddsNoCall() {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let process = world.launch(.atLogin, running: .release)

        for _ in 0..<3 {
            process.openAgain(.byHand)
            process.closeWindow()
        }

        #expect(process.engine.updates == 1)
        #expect(process.engine.probes == 0)
        #expect(process.cards.allSatisfy { $0 == nil })
        #expect(process.connection.watches == 0)
        #expect(process.engine.overlaps == 0)
    }

    @Test func aLoginStartThatEndsForAnOlderCopyMakesNoEngineCall() {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)

        let process = world.launch(.atLogin, others: [.earlier], running: .release)

        #expect(process.copies.hasEnded)
        #expect(process.engine.updates == 0)
        #expect(process.engine.probes == 0)
    }

    @Test func aLoginStartStillReplacingOthersUpdatesOnlyOnceTheyHaveExited() {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let process = world.launch(.atLogin, others: [.later], running: .release)

        #expect(process.engine.updates == 0)

        process.letExit(RunningCopy.later.id)

        #expect(process.engine.updates == 1)
        #expect(process.engine.overlaps == 0)
    }

    @Test func aCopyOutsideApplicationsMakesNoEngineCallUntilTheMovedCopyOpens() {
        let world = LifecycleWorld(accessGranted: false)
        let process = world.launch(.byHand, placement: .elsewhere, running: .release)

        #expect(process.updater == nil)
        #expect(process.moveDialog == .asking)

        process.answer(.move)
        process.releaseInstall(.installed)
        let moved = world.launch(.byHand, placement: .installed, running: .release)

        #expect(process.engine.updates == 0)
        #expect(process.engine.probes == 0)
        #expect(moved.engine.updates == 0)
    }

    @Test func aCopyThatCannotWriteMakesNoRequestAndAsksForNothingThenUpdatesOnceItCan() {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)

        let locked = world.launch(.atLogin, running: .release(canWrite: false))

        #expect(locked.engine.updates == 0)
        #expect(locked.engine.probes == 0)
        #expect(world.permissions.asks.isEmpty)
        #expect(locked.installer.installCalls == 0)
        locked.tap(1)
        #expect(locked.system.broughtToFront == [world.mac.app("Arc")])

        let next = world.launch(.atLogin, running: .release(canWrite: true))

        #expect(next.engine.updates == 1)
        #expect(next.engine.overlaps == 0)
    }
}
