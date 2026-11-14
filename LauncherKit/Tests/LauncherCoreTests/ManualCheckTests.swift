import Foundation
import LauncherCore
import Testing

@MainActor @Suite struct ManualCheckTests {
    private func world(automaticUpdates: Bool = true) -> LifecycleWorld {
        LifecycleWorld(record: [.one: "Arc"], loginItemOn: true, automaticUpdates: automaticUpdates)
    }

    private func requests(_ world: LifecycleWorld) -> Int {
        world.log.entries.filter {
            $0 == "probe" || $0 == "update" || $0 == "discard" || $0.hasPrefix("arm restart")
        }.count
    }

    /// A release copy whose start's probe ended `.nothingNew`.
    private func answered(_ world: LifecycleWorld) -> OneProcess {
        let process = world.launch(.byHand, running: .release)
        process.engine.push(.cycleEnded(.nothingNew))
        return process
    }

    private func found(_ process: OneProcess) { process.engine.push(.cycleEnded(.found("1.1.23"))) }

    private static let offered = UpdateAlert.updateAvailable(from: "1.1.22", to: "1.1.23")

    // MARK: The click reads the list once

    @Test func aClickWithTheSwitchOffReadsTheListOnceAndAnswersWithoutAnotherRead() {
        let world = world(automaticUpdates: false)
        let process = world.launch(.byHand, running: .release)

        process.checkForUpdates()

        #expect(process.engine.probes == 1)
        #expect(process.engine.updates == 0)
        #expect(process.connection.watches == 0)
        #expect(process.updater.checkButton == .checking)
        #expect(process.updater.checkButton.title == .progress(.checking))
        #expect(!process.updater.checkButton.isEnabled)
        #expect(process.deadline.armed == .seconds(30))

        process.engine.push(.cycleEnded(.nothingNew))

        #expect(process.updater.alert == .upToDate("1.1.22"))
        #expect(process.updater.checkButton == .idle)
        #expect(process.deadline.armed == nil)
        #expect(process.engine.probes == 1)
        #expect(process.engine.overlaps == 0)
    }

    @Test func aClickWhileTheCardShowsReadsTheListAgainAndKeepsTheCard() {
        let world = world()
        let process = world.launch(.byHand, running: .release)
        found(process)
        #expect(process.card == .available)
        let from = process.history.count

        process.checkForUpdates()
        #expect(process.engine.probes == 2)
        found(process)

        #expect(process.updater.alert == Self.offered)
        #expect(process.history.dropFirst(from).map(\.card).allSatisfy { $0 == .available })
        #expect(process.engine.overlaps == 0)
    }

    @Test func aSecondClickWhileCheckingDoesNothingAndTheAnswerChangesButtonAndAlertTogether() throws {
        let world = world()
        let process = answered(world)
        let from = process.history.count

        process.checkForUpdates()
        process.checkForUpdates()
        found(process)

        #expect(process.engine.probes == 2)
        #expect(process.deadline.arms == [.seconds(30)])
        let states = Array(process.history.dropFirst(from))
        let answer = try #require(states.last)
        #expect(states.dropLast().allSatisfy { $0.button == .checking && $0.alert == nil })
        #expect(answer.alert == Self.offered)
        #expect(answer.button == .idle)
    }

    // MARK: No answer, failure, adoption

    @Test func aCheckWithNoAnswerWithin30SecondsFailsAndALaterAnswerShowsNothing() {
        let world = world()
        let process = answered(world)
        process.checkForUpdates()

        process.deadline.pass()

        #expect(process.updater.alert == .checkFailed)
        #expect(process.updater.checkButton == .idle)
        process.answer(.dismissed)
        found(process)
        #expect(process.updater.alert == nil)
        #expect(process.card == nil)
        #expect(process.engine.probes == 2)
    }

    @Test func aClickAfterAPassAdoptsTheReadStillRunningWithAFresh30Seconds() {
        let world = world()
        let process = answered(world)
        process.checkForUpdates()
        process.deadline.pass()
        process.answer(.dismissed)

        process.checkForUpdates()

        #expect(process.engine.probes == 2)
        #expect(process.deadline.arms == [.seconds(30), .seconds(30)])
        #expect(process.updater.checkButton == .checking)
        found(process)
        #expect(process.updater.alert == Self.offered)
        #expect(process.engine.overlaps == 0)
    }

    @Test func anEngineThatAnswersInsideTheCallEndsTheCheckInTheSameInput() {
        let world = world()
        let process = answered(world)
        process.engine.answersInside = .cycleEnded(.failed)

        process.checkForUpdates()

        #expect(process.engine.probes == 2)
        #expect(process.updater.alert == .checkFailed)
        #expect(process.updater.checkButton == .idle)
        #expect(process.deadline.armed == nil)
        #expect(process.engine.overlaps == 0)
    }

    @Test(arguments: [CycleOutcome.requestFailed, .failed])
    func aFailedCheckAlertsOnceAndNothingRetriesWhenTheConnectionReturns(outcome: CycleOutcome) {
        let world = world()
        let process = answered(world)
        process.checkForUpdates()
        process.engine.push(.cycleEnded(outcome))

        #expect(process.updater.alert == .checkFailed)
        #expect(process.updater.alert?.title == "Couldn't check for updates")
        #expect(process.updater.alert?.message == "Check your internet connection and try again.")
        #expect(process.updater.alert?.buttons.map(\.title) == ["OK"])
        #expect(process.updater.checkButton == .idle)
        let before = requests(world)
        process.connection.set(false)
        process.connection.set(true)
        #expect(requests(world) == before)
        #expect(process.connection.watches == 0)
    }

    @Test func aClickWhileTheWindowsOwnCheckRunsTakesThatReadAndAddsNoCard() {
        let world = world()
        let process = world.launch(.byHand, running: .release)
        #expect(process.engine.probes == 1)

        process.checkForUpdates()
        #expect(process.engine.probes == 1)
        #expect(process.updater.checkButton == .checking)
        found(process)

        #expect(process.updater.alert == Self.offered)
        #expect(process.cards.allSatisfy { $0 == nil })
    }

    // MARK: The alerts as values

    @Test func theUpdateAlertAsksToRestartWithUpdateAsTheDefaultAndNotNowOnEscape() {
        let process = answered(world())
        process.checkForUpdates()
        found(process)

        let alert = process.updater.alert
        #expect(alert?.title == "Restart Trackpad App to update?")
        #expect(
            alert?.message
                == "Update Trackpad App from 1.1.22 to 1.1.23.\n\nTrackpad App will quit to install the update and open again.")
        #expect(
            alert?.buttons == [
                AlertButton(title: "Update", answer: .update, isCancel: false),
                AlertButton(title: "Not now", answer: .dismissed, isCancel: true),
            ])
    }

    @Test func notNowChangesNothingAndTheNextCheckOffersTheSameVersionAgain() {
        let world = world(automaticUpdates: false)
        let process = world.launch(.byHand, running: .release)
        process.checkForUpdates()
        found(process)
        #expect(process.updater.alert == Self.offered)

        process.answer(.dismissed)
        #expect(process.updater.alert == nil)
        process.checkForUpdates()
        found(process)

        #expect(process.updater.alert == Self.offered)
        #expect(process.cards.allSatisfy { $0 == nil })
        #expect(process.engine.updates == 0)
    }

    @Test func theUpToDateAlertQuotesTheRunningVersion() {
        let process = answered(world())
        process.checkForUpdates()
        process.engine.push(.cycleEnded(.nothingNew))

        let alert = process.updater.alert
        #expect(alert == .upToDate("1.1.22"))
        #expect(alert?.title == "Trackpad App is up to date")
        #expect(alert?.message == "You're running the latest version, 1.1.22.")
        #expect(alert?.buttons.map(\.title) == ["OK"])
    }

    // MARK: The window closes, the switch turns off

    @Test func closingTheWindowDropsACheckSilentlyNowAndAtTheNextOpening() {
        let world = world(automaticUpdates: false)
        let process = world.launch(.byHand, running: .release)
        process.checkForUpdates()
        let from = process.history.count

        process.closeWindow()
        #expect(process.deadline.armed == nil)
        #expect(process.updater.checkButton == .idle)
        found(process)
        process.openAgain(.byHand)

        #expect(process.history.dropFirst(from).allSatisfy { $0.alert == nil && $0.card == nil })
        #expect(process.updater.checkButton == .idle)
    }

    @Test func aCheckDroppedByClosingAndAnOpeningBeforeTheAnswerStillShowsTheCardOnly() {
        let world = world()
        let process = answered(world)
        process.checkForUpdates()

        process.closeWindow()
        process.openAgain(.byHand)
        #expect(process.engine.probes == 2)
        found(process)

        #expect(process.card == .available)
        #expect(process.history.allSatisfy { $0.alert == nil })
    }

    @Test func turningTheSwitchOffLetsACheckCarryOn() {
        let world = world()
        let process = answered(world)
        process.checkForUpdates()
        process.setAutomaticUpdates(on: false)
        #expect(process.deadline.armed == .seconds(30))
        found(process)

        #expect(process.updater.alert == Self.offered)
        #expect(process.deadline.armed == nil)
    }

    @Test func aCheckWaitingOnTheLoginReadSurvivesTheSwitchGoingOffAndAnswersWhenOffered() throws {
        let world = world()
        let process = try #require(world.login(running: .release))
        process.openAgain(.byHand)
        process.checkForUpdates()
        #expect(process.engine.probes == 0)
        #expect(process.updater.checkButton == .checking)

        process.setAutomaticUpdates(on: false)
        let accepted = process.engine.offer("1.1.23")

        #expect(!accepted)
        #expect(process.updater.alert == Self.offered)
        #expect(process.updater.checkButton == .idle)
    }

    // MARK: A copy that cannot update

    struct Refused: CustomTestStringConvertible, Sendable {
        let placement: Placement
        let build: RunningBuild
        var testDescription: String { "\(placement) signed \(build.developerIDSigned) canWrite \(build.canWrite)" }
    }

    nonisolated static let refused: [Refused] = [
        Refused(placement: .installed, build: RunningBuild(developerIDSigned: false, canWrite: true)),
        Refused(placement: .installed, build: RunningBuild(developerIDSigned: false, canWrite: false)),
        Refused(placement: .development, build: RunningBuild(developerIDSigned: true, canWrite: true)),
        Refused(placement: .development, build: RunningBuild(developerIDSigned: true, canWrite: false)),
        Refused(placement: .development, build: RunningBuild(developerIDSigned: false, canWrite: true)),
        Refused(placement: .development, build: RunningBuild(developerIDSigned: false, canWrite: false)),
    ]

    @Test(arguments: refused)
    func aCopyTheGateRefusesAnswersAClickWithAnAlertAndMakesNoRequest(copy: Refused) {
        let world = world()
        let process = world.launch(.byHand, placement: copy.placement, running: copy.build)
        #expect(process.updater.checkButton == .idle)

        process.checkForUpdates()

        #expect(process.updater.alert == .unavailable)
        #expect(process.updater.alert?.title == "Updates aren't available for this copy")
        #expect(process.updater.alert?.message == "This copy of Trackpad App can't update itself.")
        #expect(process.updater.alert?.buttons.map(\.title) == ["OK"])
        #expect(process.updater.checkButton == .idle)
        #expect(requests(world) == 0)
        #expect(process.connection.watches == 0)

        process.closeWindow()
        #expect(process.updater.alert == nil)

        process.openAgain(.byHand)
        process.setAutomaticUpdates(on: false)
        let next = world.launch(.byHand, placement: copy.placement, running: copy.build)
        #expect(!next.updater.isAutomaticUpdatesOn)
    }

    // MARK: Withdrawn alerts, and Update

    @Test func aClickWhileAnAlertShowsChangesNothingAndALateAnswerToAClosedWindowsAlertDoesNothing() {
        let world = world()
        let process = answered(world)
        process.checkForUpdates()
        found(process)
        let before = process.history.last

        process.checkForUpdates()
        #expect(process.history.last?.alert == before?.alert)
        #expect(process.history.last?.button == before?.button)
        #expect(process.engine.probes == 2)

        process.closeWindow()
        #expect(process.updater.alert == nil)
        process.updater.answer(.update, to: Self.offered)
        #expect(process.engine.updates == 0)
    }

    @Test func updateFromTheAlertWithTheSwitchOffDownloadsOnceAndTheNewVersionKeepsTheSwitchOff() {
        let world = world(automaticUpdates: false)
        let process = world.launch(.byHand, running: .release)
        process.checkForUpdates()
        found(process)

        process.answer(.update)

        #expect(process.engine.updates == 1)
        #expect(process.updater.checkButton == .updating)
        #expect(process.engine.offer("1.1.23"))
        process.engine.push(.held)
        #expect(process.engine.arms == [true])

        let next = world.finishHandOver()
        #expect(next.window != .closed)
        #expect(!next.updater.isAutomaticUpdatesOn)
        next.closeWindow()
        next.openAgain(.byHand)
        #expect(next.engine.probes == 0)
        #expect(next.engine.updates == 0)
    }
}
