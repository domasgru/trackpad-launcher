import Foundation
import LauncherCore
import Testing

@MainActor @Suite struct UpdateFromAlertTests {
    private func world(automaticUpdates: Bool = true) -> LifecycleWorld {
        .updateWorld(automaticUpdates: automaticUpdates)
    }

    /// A release copy answered, clicked and *Found*, then *Update*: no card showed.
    private func updateClicked(_ world: LifecycleWorld) -> OneProcess {
        let process = world.answeredLaunch()
        process.checkForUpdates()
        process.found()
        process.answer(.update)
        return process
    }

    /// A release copy showing its card, clicked and *Found*, then *Update*.
    private func updateClickedOverCard(_ world: LifecycleWorld) -> OneProcess {
        let process = world.launch(.byHand, running: .release)
        process.found()
        process.checkForUpdates()
        process.found()
        process.answer(.update)
        return process
    }

    /// A login copy that waited for the connection, whose retry runs with the window opened by hand and a click waiting:
    /// the retry then offers, and the alert shows over the login download.
    private func alertOverLoginDownload(_ world: LifecycleWorld) throws -> OneProcess {
        let process = try #require(world.login(running: .release))
        process.engine.push(.cycleEnded(.requestFailed))
        process.connection.set(true)
        process.openAgain(.byHand)
        process.checkForUpdates()
        return process
    }

    // MARK: A download that already runs

    @Test func updateTakesOverARunningLoginRetryAndTheDownloadHandsOverWithTheWindow() throws {
        let world = world()
        let process = try alertOverLoginDownload(world)
        #expect(process.engine.updates == 2)
        #expect(process.deadline.armed == .seconds(30))

        #expect(process.engine.offer("1.1.23"))
        #expect(process.updater.alert == LifecycleWorld.offeredAlert)
        #expect(process.updater.checkButton == .updating)
        #expect(process.deadline.armed == nil)

        process.answer(.update)
        #expect(process.engine.updates == 2)
        #expect(process.updater.checkButton == .updating)
        #expect(process.card == nil)

        process.engine.push(.held)
        #expect(process.engine.arms == [true])
        #expect(process.engine.overlaps == 0)
        #expect(process.engine.unconsented == 0)
    }

    @Test func aHandOverBeforeAnyAnswerWithdrawsTheAlertAndEndsTheProcess() throws {
        let world = world()
        let process = try alertOverLoginDownload(world)
        process.engine.offer("1.1.23")

        process.engine.push(.held)

        #expect(process.updater.alert == nil)
        #expect(process.engine.arms == [true])
        #expect(process.copies.hasEnded)
    }

    @Test func aFailureOfTheTakenOverLoginDownloadReportsAFailure() throws {
        let world = world()
        let process = try alertOverLoginDownload(world)
        process.engine.offer("1.1.23")
        process.answer(.update)

        process.engine.push(.cycleEnded(.failed))

        #expect(process.updater.alert == .installFailed(running: "1.1.22"))
        #expect(process.updater.checkButton == .idle)
    }

    @Test func updateWhileADeclinedLoginCycleRunsWaitsForItAndThenTheOneDownloadInstalls() throws {
        let world = world()
        let process = try #require(world.login(running: .release))
        process.setAutomaticUpdates(on: false)
        process.openAgain(.byHand)
        process.checkForUpdates()
        #expect(!process.engine.offer("1.1.23"))
        #expect(process.updater.alert == LifecycleWorld.offeredAlert)

        process.answer(.update)
        #expect(process.engine.updates == 1)
        #expect(process.updater.checkButton == .updating)

        process.engine.push(.cycleEnded(.failed))
        #expect(process.engine.updates == 2)
        #expect(process.engine.offer("1.1.23"))
        process.engine.push(.held)
        #expect(process.engine.arms == [true])
        #expect(process.engine.overlaps == 0)
    }

    @Test func updateNowDuringACheckWaitsForTheReadAndNoAlertAnswersTheClick() {
        let world = world()
        let process = world.launch(.byHand, running: .release)
        process.found()
        process.checkForUpdates()
        #expect(process.engine.probes == 2)

        let from = process.history.count
        process.updater.updateNow()
        #expect(process.updater.checkButton == .updating)
        #expect(process.card == .updating)
        #expect(process.deadline.armed == nil)
        #expect(process.engine.updates == 0)

        process.found()
        #expect(process.engine.updates == 1)
        #expect(process.history.dropFirst(from).allSatisfy { $0.alert == nil })
        #expect(process.engine.overlaps == 0)
    }

    // MARK: What it installs

    @Test func aNewerReleaseMeanwhileIsWhatInstalls() {
        let world = world()
        let process = updateClicked(world)

        #expect(process.engine.offer("1.1.24"))
        #expect(process.engine.offers.last == .init(version: "1.1.24", accepted: true))
        process.engine.push(.held)

        #expect(process.engine.arms == [true])
    }

    // MARK: The window and the card during the download

    @Test func reopeningTheWindowDuringAnUpdateFromTheAlertChecksNothingAndShowsNoCard() {
        let world = world()
        let process = updateClicked(world)
        let from = process.history.count

        process.closeWindow()
        process.openAgain(.byHand)

        #expect(process.engine.probes == 2)
        #expect(process.history.dropFirst(from).allSatisfy { $0.card == nil && $0.button == .updating })
        #expect(process.updater.checkButton == .updating)

        process.closeWindow()
        process.engine.push(.held)
        #expect(process.engine.arms == [true])
    }

    @Test func updateFromTheAlertWhileTheCardShowsReadsUpdatingOnBothButtons() {
        let world = world()
        let process = updateClickedOverCard(world)

        #expect(process.card == .updating)
        #expect(process.updater.checkButton == .updating)
        #expect(process.card?.isButtonEnabled == false)
        #expect(!process.updater.checkButton.isEnabled)
    }

    @Test func openingTheWindowDuringALoginUpdateChecksNothingAndShowsNoCard() throws {
        let world = world()
        let process = try #require(world.login(running: .release))
        process.engine.offer("1.1.23")

        process.openAgain(.byHand)

        #expect(process.engine.probes == 0)
        #expect(process.card == nil)
        #expect(process.updater.checkButton == .updating)
    }

    @Test func reopeningTheWindowDuringUpdateNowKeepsTheCardUpdating() {
        let world = world()
        let process = world.launch(.byHand, running: .release)
        process.found()
        process.updater.updateNow()

        process.closeWindow()
        process.openAgain(.byHand)

        #expect(process.engine.probes == 1)
        #expect(process.card == .updating)
        #expect(process.updater.checkButton == .updating)
    }

    // MARK: How it ends

    @Test(arguments: ["failed", "requestFailed", "refusedRestart"])
    func aDownloadThatEndsWithoutInstallingAlertsAndReturnsTheButton(ending: String) {
        let world = world()
        let process = updateClicked(world)
        switch ending {
        case "failed":
            process.engine.push(.cycleEnded(.failed))
        case "requestFailed":
            process.engine.push(.cycleEnded(.requestFailed))
        default:
            process.engine.armWorks = false
            process.engine.push(.held)
            process.engine.push(.cycleEnded(.failed))
        }

        #expect(process.updater.alert == .installFailed(running: "1.1.22"))
        #expect(process.updater.alert?.title == "Couldn't install the update")
        #expect(process.updater.alert?.message == "Trackpad App 1.1.22 keeps running. Try again later.")
        #expect(process.updater.alert?.buttons.map(\.title) == ["OK"])
        #expect(process.updater.checkButton == .idle)
        #expect(!process.copies.hasEnded)
        process.tap(1)
        #expect(process.system.broughtToFront == [world.mac.app("Arc")])
    }

    @Test func aRefusedRestartAfterTheAlertKeepsTheProcessWorking() {
        let world = world()
        let process = updateClicked(world)
        process.engine.armWorks = false
        process.engine.push(.held)
        process.engine.push(.cycleEnded(.failed))

        process.tap(1)

        #expect(process.system.broughtToFront == [world.mac.app("Arc")])
    }

    @Test func aFailureWithTheWindowClosedShowsNothingThenOrLater() {
        let world = world()
        let process = updateClicked(world)
        process.closeWindow()
        let from = process.history.count

        process.engine.push(.cycleEnded(.failed))
        process.openAgain(.byHand)

        #expect(process.history.dropFirst(from).allSatisfy { $0.alert == nil })
        #expect(process.updater.checkButton == .idle)
    }

    @Test func aCancelledAdministratorPromptShowsNoAlertAndReturnsTheButton() {
        let world = world()
        let process = updateClicked(world)

        process.engine.push(.cycleEnded(.cancelled))

        #expect(process.updater.alert == nil)
        #expect(process.updater.checkButton == .idle)
        #expect(!process.copies.hasEnded)
    }

    @Test func aCancelledPromptAfterUpdateOverTheCardReturnsTheCard() {
        let world = world()
        let process = updateClickedOverCard(world)

        process.engine.push(.cycleEnded(.cancelled))

        #expect(process.updater.alert == nil)
        #expect(process.card == .available)
    }

    @Test func turningTheSwitchOffLetsTheDownloadInstall() {
        let world = world()
        let process = updateClicked(world)
        process.setAutomaticUpdates(on: false)

        process.engine.push(.held)

        #expect(process.engine.arms == [true])
    }

    @Test func aFailureAfterTheSwitchWentOffAlertsButBringsNoCardBack() {
        let world = world()
        let process = updateClickedOverCard(world)
        process.setAutomaticUpdates(on: false)

        process.engine.push(.cycleEnded(.failed))

        #expect(process.updater.alert == .installFailed(running: "1.1.22"))
        #expect(process.card == nil)
    }

    @Test func updateThatFindsNothingNewAnyMoreReadsUpToDate() {
        let world = world()
        let process = updateClicked(world)

        process.engine.push(.cycleEnded(.nothingNew))

        #expect(process.updater.alert == .upToDate("1.1.22"))
        #expect(process.updater.checkButton == .idle)
    }
}
