import Foundation
import LauncherCore
import Testing

@MainActor @Suite struct UpdaterEverywhereTests {
    private func world() -> LifecycleWorld {
        LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
    }

    private static let engineEntries: Set<String> = [
        "probe", "update", "discard", "arm restart", "arm restart with window",
    ]

    @Test func aLoginUpdateTakesTheOfferShowsNoCardAndHandsOverWithTheWindowTheUserOpened() {
        let world = world()
        let process = world.launch(.atLogin, running: .release)
        #expect(process.engine.updates == 1)
        #expect(process.engine.offers.isEmpty)

        let answer = process.engine.offer("1.1.23")

        #expect(answer)
        #expect(process.engine.offers == [.init(version: "1.1.23", accepted: true)])
        process.openAgain(.byHand)
        process.engine.push(.held)

        #expect(process.engine.probes == 0)
        #expect(process.cards.allSatisfy { $0 == nil })
        #expect(process.engine.arms == [true])
        #expect(process.copies.hasEnded)
        #expect(process.engine.overlaps == 0)
        #expect(process.engine.unconsented == 0)
    }

    @Test func aWindowCheckThatFindsAVersionShowsTheCardAndDownloadsNothing() {
        let process = world().launch(.byHand, running: .release)
        #expect(process.engine.probes == 1)

        process.engine.push(.cycleEnded(.found("1.1.23")))

        #expect(process.card == .available)
        #expect(process.engine.updates == 0)
        #expect(process.engine.offers.isEmpty)
        #expect(process.engine.overlaps == 0)
        #expect(process.engine.unconsented == 0)
    }

    struct Refused: Sendable, CustomTestStringConvertible {
        let placement: Placement
        let signed: Bool
        let canWrite: Bool
        var testDescription: String { "\(placement) signed=\(signed) canWrite=\(canWrite)" }
    }

    nonisolated static let refused: [Refused] = [
        Refused(placement: .installed, signed: false, canWrite: true),
        Refused(placement: .installed, signed: false, canWrite: false),
        Refused(placement: .development, signed: true, canWrite: true),
        Refused(placement: .development, signed: true, canWrite: false),
        Refused(placement: .development, signed: false, canWrite: true),
        Refused(placement: .development, signed: false, canWrite: false),
    ]

    @Test(arguments: refused)
    func aCopyTheGateTurnsAwayHoldsAnUpdaterAndMakesNoRequest(row: Refused) {
        let world = world()
        let running = RunningBuild(developerIDSigned: row.signed, canWrite: row.canWrite)
        let byHand = world.launch(.byHand, placement: row.placement, running: running)
        let atLogin = world.launch(.atLogin, placement: row.placement, running: running)

        for process in [byHand, atLogin] {
            for _ in 0..<5 {
                process.openAgain(.byHand)
                process.closeWindow()
            }
            for _ in 0..<2 {
                process.connection.set(false)
                process.connection.set(true)
            }

            #expect(process.ports == nil)
            #expect(process.updater.version == "1.1.22")
            #expect(process.updater.card == nil)
            #expect(process.connection.watches == 0)
            #expect(process.engine.overlaps == 0)
            #expect(process.engine.unconsented == 0)
        }
        #expect(Set(world.log.entries).isDisjoint(with: Self.engineEntries))
    }
}
