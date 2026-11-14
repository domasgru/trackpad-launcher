import Foundation
import LauncherCore
import Testing

@MainActor @Suite struct AutomaticUpdatesTests {
    private static let rightThumb = (x: 114.8, y: 10.0)
    private static let switchKey = "automaticUpdatesOff"

    private func world(automaticUpdates: Bool = true) -> LifecycleWorld {
        LifecycleWorld(record: [.one: "Arc"], corner: .topRight, loginItemOn: true, automaticUpdates: automaticUpdates)
    }

    private func requests(_ world: LifecycleWorld) -> Int {
        world.log.entries.filter {
            $0 == "probe" || $0 == "update" || $0 == "discard" || $0.hasPrefix("arm restart")
        }.count
    }

    private func login(_ world: LifecycleWorld) throws -> OneProcess {
        try #require(world.login(running: .release))
    }

    private func waitingLogin(_ world: LifecycleWorld) throws -> OneProcess {
        let process = try login(world)
        process.engine.push(.cycleEnded(.requestFailed))
        return process
    }

    private func cardShowing(_ world: LifecycleWorld) -> OneProcess {
        let process = world.launch(.byHand, running: .release)
        process.engine.push(.cycleEnded(.found("1.1.23")))
        return process
    }

    private func updatingFromCard(_ world: LifecycleWorld) -> OneProcess {
        let process = cardShowing(world)
        process.updater.updateNow()
        return process
    }

    private func keys(_ world: LifecycleWorld) -> Set<String> { Set(world.mac.suiteDomain().keys) }

    // MARK: Persistence

    @Test func aNewInstallStartsWithTheSwitchOnAndSavesNothingForIt() {
        let world = LifecycleWorld(loginItemOn: true)

        let process = world.launch(.byHand, running: .release)

        #expect(process.updater.isAutomaticUpdatesOn)
        #expect(!keys(world).contains(Self.switchKey))
        #expect(process.engine.overlaps == 0)
    }

    @Test func anUpgradeFromAVersionWithoutTheSwitchHasItOnAndItsStartMakesNoRequestButTheReopeningOneProbe() {
        let world = LifecycleWorld(loginItemOn: true)
        world.mac.seedSettingsRecord(Data(PersistenceTests.savedSettings.utf8))

        let process = world.launch(.afterUpdate(withWindow: true), running: .release)

        #expect(process.updater.isAutomaticUpdatesOn)
        #expect(requests(world) == 0)
        process.closeWindow()
        process.openAgain(.byHand)
        #expect(process.engine.probes == 1)
        #expect(process.engine.overlaps == 0)
    }

    @Test func aChangeOfTheSwitchIsSavedAtOnceUnderItsOwnKeyAndNeverInTheRecord() throws {
        let world = world()
        let process = world.launch(.byHand, running: .release)
        let record = try #require(world.mac.settingsRecordBytes())

        process.setAutomaticUpdates(on: false)

        #expect(keys(world).contains(Self.switchKey))
        #expect(world.mac.settingsRecordBytes() == record)
        let fields = try #require(
            PropertyListSerialization.propertyList(from: record, format: nil) as? [String: Any])
        #expect(fields[Self.switchKey] == nil)
        process.setAutomaticUpdates(on: true)
        #expect(!keys(world).contains(Self.switchKey))
        #expect(world.mac.settingsRecordBytes() == record)
    }

    @Test func anOffSurvivesThePreviousVersionsSaveOfTheRecord() throws {
        let world = world()
        world.launch(.byHand, running: .release).setAutomaticUpdates(on: false)

        try world.mac.previousVersionSaves { $0.isSwipeOn = false }

        #expect(world.mac.freshStore().load()?.isSwipeOn == false)
        let next = world.launch(.byHand, running: .release)
        #expect(!next.updater.isAutomaticUpdatesOn)
    }

    @Test(arguments: ["a string", "false"]) func aValueTheBuildCannotReadStaysOff(kind: String) throws {
        let world = world()
        world.mac.seedSuite([Self.switchKey: kind == "false" ? false as Any : "off" as Any])
        let before = requests(world)

        let process = try login(world)

        #expect(!process.updater.isAutomaticUpdatesOn)
        #expect(requests(world) == before)
    }

    @Test func anOffSurvivesAForceQuitAndALoginStart() throws {
        let world = world()
        world.launch(.byHand, running: .release).setAutomaticUpdates(on: false)
        let before = requests(world)

        let next = try login(world)

        #expect(!next.updater.isAutomaticUpdatesOn)
        #expect(requests(world) == before)
    }

    @Test func anOffSurvivesAQuitAndALoginStart() {
        let world = world()
        let process = world.launch(.byHand, running: .release)
        process.setAutomaticUpdates(on: false)
        process.quit()
        let before = requests(world)

        let next = world.launch(.atLogin, running: .release)

        #expect(!next.updater.isAutomaticUpdatesOn)
        #expect(requests(world) == before)
    }

    @Test func aSwitchTurnedOffAndOnAgainResumesTheLoginUpdateAndTheOpeningsCheck() {
        let world = world()
        let process = world.launch(.byHand, running: .release)
        process.setAutomaticUpdates(on: false)
        process.setAutomaticUpdates(on: true)

        let next = world.launch(.atLogin, running: .release)
        #expect(next.engine.updates == 1)
        next.engine.push(.cycleEnded(.nothingNew))
        next.openAgain(.byHand)

        #expect(next.engine.probes == 1)
        #expect(next.engine.overlaps == 0)
    }

    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    @Test(arguments: 1...50) func aForceQuitProcessLeavesTheSwitchAsItsLastFlipSetIt(seed: Int) throws {
        var random = SeededGenerator(state: UInt64(seed))
        let n = Int.random(in: 1...12, using: &random)
        let k = Int.random(in: 0...n, using: &random)
        let world = world()
        let process = world.launch(.byHand, running: .release)
        for _ in 0..<k { process.setAutomaticUpdates(on: !process.updater.isAutomaticUpdatesOn) }
        let isOn = try #require(process.history.last?.isAutomaticUpdatesOn)

        let next = try login(world)

        #expect(next.updater.isAutomaticUpdatesOn == isOn)
        #expect(keys(world).contains(Self.switchKey) == !isOn)
        #expect(next.engine.updates == (isOn ? 1 : 0))
    }

    // MARK: No automatic request

    @Test func anOffLoginCopyMakesNoRequestThroughDroppedConnectionsAndOpenings() throws {
        let world = world(automaticUpdates: false)
        let process = try login(world)

        for _ in 0..<3 {
            process.connection.set(false)
            process.connection.set(true)
        }
        for _ in 0..<2 {
            process.openAgain(.byHand)
            process.closeWindow()
        }

        #expect(requests(world) == 0)
        #expect(process.connection.watches == 0)
        #expect(process.installer.installCalls == 0)
        #expect(process.engine.overlaps == 0)
    }

    @Test(arguments: [true, false]) func anOffCopyChecksNothingAtItsStartOrWhenItsWindowOpens(canWrite: Bool) {
        let world = world(automaticUpdates: false)
        let process = world.launch(.byHand, running: .release(canWrite: canWrite))

        for _ in 0..<3 {
            process.closeWindow()
            process.openAgain(.byHand)
        }

        #expect(requests(world) == 0)
        #expect(process.history.allSatisfy { $0.card == nil })
        #expect(process.engine.overlaps == 0)
    }

    // MARK: Turning off

    @Test func turningTheSwitchOffRemovesTheCardAtOnce() {
        let process = cardShowing(world())

        process.setAutomaticUpdates(on: false)

        #expect(process.history.last?.card == nil)
        #expect(process.history.dropLast().last?.card == .available)
    }

    @Test func aSwitchTurnedOffBeforeTheWindowChecksAnswersDropsTheAnswerAndChecksNoMore() {
        let process = world().launch(.byHand, running: .release)

        process.setAutomaticUpdates(on: false)
        process.engine.push(.cycleEnded(.found("1.1.23")))
        process.closeWindow()
        process.openAgain(.byHand)

        #expect(process.history.allSatisfy { $0.card == nil })
        #expect(process.engine.probes == 1)
        #expect(process.engine.overlaps == 0)
    }

    @Test func turningTheSwitchOffEndsAWaitForAConnection() throws {
        let process = try waitingLogin(world())
        #expect(process.connection.isWatching)

        process.setAutomaticUpdates(on: false)
        #expect(!process.connection.isWatching)

        process.connection.set(true)
        #expect(process.engine.updates == 1)
        #expect(process.engine.overlaps == 0)
    }

    @Test func aWindowChecksOwedRetryIsDroppedWithTheSwitch() throws {
        let process = try waitingLogin(world())
        process.openAgain(.byHand)

        process.setAutomaticUpdates(on: false)
        process.connection.reading = true
        process.engine.push(.cycleEnded(.requestFailed))

        #expect(process.connection.watches == 1)
        #expect(!process.connection.isWatching)
        #expect(process.engine.updates == 1)
        #expect(process.engine.overlaps == 0)
    }

    @Test func aRunningRetrysWatchStopsWithinTheInputThatTurnsTheSwitchOff() throws {
        let process = try waitingLogin(world())
        process.connection.set(true)
        #expect(process.connection.isWatching)
        #expect(process.engine.updates == 2)

        process.setAutomaticUpdates(on: false)

        #expect(!process.connection.isWatching)
        #expect(process.engine.overlaps == 0)
    }

    @Test func aLoginCheckDroppedBeforeItsOfferDownloadsNothing() throws {
        let world = world()
        let process = try login(world)

        process.setAutomaticUpdates(on: false)
        let accepted = process.engine.offer("1.1.23")
        process.engine.push(.held)
        process.engine.push(.cycleEnded(.nothingNew))
        process.openAgain(.byHand)

        #expect(!accepted)
        #expect(process.engine.unconsented == 1)
        #expect(process.engine.arms.isEmpty)
        #expect(process.engine.discards == 0)
        #expect(process.history.allSatisfy { $0.card != .updating })
        #expect(process.engine.probes == 0)
        #expect(process.engine.updates == 1)
        #expect(process.engine.overlaps == 0)
    }

    @Test func aDownloadFromTheCardCarriesOnAndHandsOverAfterTheSwitchTurnsOff() {
        let world = world()
        let process = updatingFromCard(world)

        process.setAutomaticUpdates(on: false)
        #expect(process.history.last?.card == .updating)
        process.engine.push(.held)

        #expect(process.engine.arms == [true])
        #expect(world.log.entries.last == "end")
        #expect(process.engine.overlaps == 0)
    }

    @Test(arguments: [true, false]) func anOfferedLoginUpdateCarriesOnAndTheWindowDecidesItsHandOver(windowOpen: Bool) throws {
        let world = world()
        let process = try login(world)
        #expect(process.engine.offer("1.1.23"))
        if windowOpen { process.openAgain(.byHand) }

        process.setAutomaticUpdates(on: false)
        process.engine.push(.held)

        #expect(process.engine.arms == [windowOpen])
        #expect(world.log.entries.last == "end")
    }

    @Test func aFailedDownloadAfterTheSwitchWentOffLeavesNoCardAndTheNextOpeningChecksAgain() {
        let world = world()
        let process = updatingFromCard(world)
        process.setAutomaticUpdates(on: false)

        process.engine.push(.cycleEnded(.failed))
        #expect(process.card == nil)
        process.setAutomaticUpdates(on: true)
        #expect(process.card == nil)
        process.tap(1, thumbAtMM: Self.rightThumb)
        #expect(process.system.broughtToFront == [world.mac.app("Arc")])

        process.closeWindow()
        process.openAgain(.byHand)
        #expect(process.engine.probes == 2)
        process.engine.push(.cycleEnded(.found("1.1.23")))
        #expect(process.card == .available)
        #expect(process.engine.overlaps == 0)
    }

    // MARK: Turning on

    @Test func turningTheSwitchOnStartsNothingAndTheNextOpeningChecks() {
        let world = world(automaticUpdates: false)
        let process = world.launch(.byHand, running: .release)

        process.setAutomaticUpdates(on: true)
        #expect(requests(world) == 0)

        process.closeWindow()
        process.openAgain(.byHand)
        #expect(process.engine.probes == 1)
        #expect(process.engine.overlaps == 0)
    }

    @Test func aCardStaysGoneAfterOffAndOnUntilTheNextOpeningFindsOneAgain() {
        let process = cardShowing(world())

        process.setAutomaticUpdates(on: false)
        let offAt = process.history.count - 1
        process.setAutomaticUpdates(on: true)
        #expect(process.history[offAt...].allSatisfy { $0.card == nil })

        process.closeWindow()
        process.openAgain(.byHand)
        process.engine.push(.cycleEnded(.found("1.1.23")))
        #expect(process.card == .available)
        #expect(process.engine.overlaps == 0)
    }

    @Test func aWaitEndedByTheSwitchIsNotRestartedByTurningItBackOn() throws {
        let process = try waitingLogin(world())

        process.setAutomaticUpdates(on: false)
        process.setAutomaticUpdates(on: true)
        process.connection.set(true)

        #expect(process.engine.updates == 1)
        #expect(process.connection.watches == 1)
        #expect(process.engine.overlaps == 0)
    }

    @Test func anOpeningAdoptsTheDroppedLoginReadAndShowsItsAnswerWithoutDownloading() throws {
        let world = world()
        let process = try login(world)

        process.setAutomaticUpdates(on: false)
        process.setAutomaticUpdates(on: true)
        process.openAgain(.byHand)
        #expect(process.engine.probes == 0)
        let accepted = process.engine.offer("1.1.23")

        #expect(!accepted)
        #expect(process.card == .available)
        #expect(process.engine.arms.isEmpty)
        #expect(process.engine.overlaps == 0)
    }
}
