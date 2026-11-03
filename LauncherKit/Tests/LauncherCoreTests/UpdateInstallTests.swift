import Foundation
import LauncherCore
import Testing

@MainActor @Suite struct UpdateInstallTests {
    private static let next = Version(1, 1, 0)

    /// 1.0.0 in /Applications, opened by hand, with Arc on the 1-finger gesture and the login item on; the check has
    /// answered [1.1.0].
    private static func offered() throws -> (LifecycleWorld, OneProcess) {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let process = world.launch(.byHand, placement: .installed, running: .release("1.0.0"))
        process.deliver([.version("1.1.0")])
        try #require(process.card == .available(next))
        return (world, process)
    }

    private static func downloading(at fraction: Double = 0.4) throws -> (LifecycleWorld, OneProcess) {
        let (world, process) = try offered()
        process.updateNow()
        process.progress(fraction)
        return (world, process)
    }

    private static func installing() throws -> (LifecycleWorld, OneProcess) {
        let (world, process) = try downloading()
        process.finishDownload()
        try #require(process.card == .installing(next))
        return (world, process)
    }

    private static func opening() throws -> (LifecycleWorld, OneProcess) {
        let (world, process) = try installing()
        process.swapIn()
        try #require(process.updates.opens == 1)
        return (world, process)
    }

    private func arcComesToFront(_ process: OneProcess, _ world: LifecycleWorld) {
        let before = process.system.broughtToFront.count
        process.tap(1)
        #expect(process.system.broughtToFront.count == before + 1)
        #expect(process.system.broughtToFront.last == world.mac.app("Arc"))
    }

    @Test(arguments: [true, false])
    func updateNowDownloadsInstallsOpensTheNewVersionAndEndsTheOldOne(oldCopyAlreadyExited: Bool) throws {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let process = world.launch(.byHand, placement: .installed, running: .release("1.0.0"))
        process.deliver([.version("1.1.0")])
        let before = world.mac.suiteDomain()

        process.updateNow()

        #expect(process.card == .downloading(Self.next, progress: 0))
        #expect(Copy.updateDownloading(Self.next) == "Downloading version 1.1.0…")
        #expect(Copy.cancelButton == "Cancel")

        process.progress(0.4)
        arcComesToFront(process, world)
        #expect(process.card == .downloading(Self.next, progress: 0.4))

        process.finishDownload()
        arcComesToFront(process, world)
        #expect(process.card == .installing(Self.next))
        #expect(Copy.updateInstalling(Self.next) == "Installing version 1.1.0…")
        #expect(process.isInstalling)

        process.swapIn()
        arcComesToFront(process, world)
        #expect(process.card == .installing(Self.next))
        #expect(process.updates.opens == 1)
        #expect(!process.copies.hasEnded)

        process.answerOpen(started: true)
        #expect(process.copies.hasEnded)

        let old = RunningCopy.earlier
        let replacement = world.launch(
            .byHand, others: [old], alreadyExited: oldCopyAlreadyExited ? [old] : [], placement: .installed,
            running: .release("1.1.0"))
        if !oldCopyAlreadyExited { replacement.letExit(old.id) }

        #expect(replacement.window == .open(request: 1))
        #expect(replacement.releases.fetches == 1)
        replacement.deliver([.version("1.1.0")])
        #expect(replacement.card == nil)
        arcComesToFront(replacement, world)

        #expect(world.loginItem.isOn)
        #expect(world.loginItem.calls.isEmpty)
        #expect(world.permissions.asks.isEmpty)
        #expect(world.snapshots.count == 2)
        for snapshot in world.snapshots { #expect(NSDictionary(dictionary: snapshot.suite).isEqual(to: before)) }
        #expect(NSDictionary(dictionary: world.mac.suiteDomain()).isEqual(to: before))
    }

    @Test func cancelDuringTheDownloadReturnsToAvailableAndAnEarlierAttemptsEventsChangeNothing() throws {
        let (world, process) = try Self.downloading()

        process.cancel()

        #expect(process.card == .available(Self.next))
        #expect(process.updates.cancels == 1)
        process.updates.deliverLate(.progress(0.6), attempt: 1)
        process.updates.deliverLate(.downloaded, attempt: 1)
        #expect(process.card == .available(Self.next))
        #expect(world.installedAt == nil)
        #expect(!process.copies.hasEnded)
        arcComesToFront(process, world)

        process.updateNow()

        #expect(process.updates.requests.count == 2)
        #expect(process.card == .downloading(Self.next, progress: 0))
    }

    @Test func cancelExistsOnlyWhileDownloading() throws {
        let (worlds, available) = try Self.offered()
        let more = try [Self.installing(), Self.opening(), Self.downloading()]
        defer { withExtendedLifetime((worlds, more)) {} }
        available.cancel()
        #expect(available.card == .available(Self.next))

        let installing = more[0].1
        installing.cancel()
        #expect(installing.card == .installing(Self.next))

        let opening = more[1].1
        opening.cancel()
        #expect(opening.card == .installing(Self.next))

        let failed = more[2].1
        failed.failUpdate()
        failed.cancel()
        #expect(failed.card == .failed(Self.next))

        for process in [available, installing, opening, failed] { #expect(process.updates.cancels == 0) }
    }

    @Test func theCardReadsInstallingExactlyWhenAnInstallIsUnderWay() throws {
        let (runWorld, run) = try Self.downloading()
        let (declinedWorld, declined) = try Self.installing()
        defer { withExtendedLifetime((runWorld, declinedWorld)) {} }
        run.finishDownload()
        run.swapIn()
        run.answerOpen(started: false)
        run.updateNow()
        run.finishDownload()
        run.decline()
        run.updateNow()
        run.finishDownload()
        run.failUpdate()
        declined.decline()

        for process in [run, declined] {
            #expect(process.history.contains { $0.isInstalling })
            for published in process.history {
                var isInstallingCard = false
                if case .installing? = published.card { isInstallingCard = true }
                #expect(isInstallingCard == published.isInstalling)
            }
        }
    }

    @Test func closingTheWindowOrAnOrdinaryQuitDuringTheDownloadCancelsItAndChangesNothing() throws {
        for dock in [false, true] {
            let (world, process) = try Self.downloading()

            if dock {
                #expect(!process.shouldEnd(.other))
            } else {
                process.closeWindow()
            }

            #expect(process.window == .closed)
            #expect(process.updates.cancels == 1)
            process.updates.deliverLate(.downloaded, attempt: 1)
            #expect(process.card == nil)
            #expect(process.updates.opens == 0)
            #expect(world.installedAt == nil)
            #expect(!process.copies.hasEnded)
            arcComesToFront(process, world)

            process.openAgain(.byHand)
            process.deliver([.version("1.1.0")])
            #expect(process.card == .available(Self.next))
            #expect(Copy.updateAvailable(Self.next) == "App version 1.1.0 is available")
        }
    }

    @Test func quitTrackpadLauncherDuringTheDownloadEndsTheProcessWithNothingSwapped() throws {
        let (world, process) = try Self.downloading()

        process.quit()

        #expect(process.copies.hasEnded)
        #expect(world.installedAt == nil)
        #expect(process.updates.opens == 0)
    }

    @Test(arguments: [false, true])
    func whileTheUpdateInstallsQuitDoesNothingAndEveryOrdinaryQuitOnlyClosesTheWindow(swapped: Bool) throws {
        let (world, process) = swapped ? try Self.opening() : try Self.installing()

        process.quit()

        #expect(!process.copies.hasEnded)
        #expect(process.window == .open(request: 1))
        #expect(world.loginItem.calls.isEmpty)

        #expect(!process.shouldEnd(.other))
        #expect(process.window == .closed)
        #expect(process.card == .installing(Self.next))
        #expect(process.updates.cancels == 0)

        #expect(!process.shouldEnd(.other))
        #expect(!process.copies.hasEnded)
        #expect(process.shouldEnd(.system))
    }

    @Test func closingDuringTheInstallLetsItFinishAndReopeningShowsItWithoutACheck() throws {
        let (world, process) = try Self.installing()

        process.closeWindow()
        process.openAgain(.byHand)

        #expect(process.window == .open(request: 2))
        #expect(process.card == .installing(Self.next))
        #expect(process.releases.fetches == 1)

        process.closeWindow()
        process.swapIn()
        process.openAgain(.byHand)

        #expect(process.window == .open(request: 3))
        #expect(process.card == .installing(Self.next))
        #expect(process.releases.fetches == 1)

        process.answerOpen(started: true)
        #expect(process.copies.hasEnded)

        let replacement = world.launch(.byHand, others: [.earlier], alreadyExited: [.earlier], running: .release("1.1.0"))
        #expect(replacement.window == .open(request: 1))
    }

    @Test func aKillAtAnyEffectOfTheUpdateLeavesAMacThatOpensWholeAndUntouched() throws {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let seeded = try #require(world.mac.freshStore().load())
        let process = world.launch(.byHand, placement: .installed, running: .release("1.0.0"))
        process.deliver([.version("1.1.0")])
        process.updateNow()
        process.finishDownload()
        process.swapIn()
        process.answerOpen(started: true)
        let installedAt = try #require(world.installedAt)
        #expect(world.snapshots.count == 2)

        for (index, snapshot) in world.snapshots.enumerated() {
            let restored = LifecycleWorld(restoring: snapshot)
            let version = index < installedAt ? "1.0.0" : "1.1.0"

            let reopened = restored.launch(.byHand, placement: .installed, running: .release(version))

            #expect(reopened.window == .open(request: 1))
            #expect(reopened.releases.fetches == 1)
            #expect(restored.mac.freshStore().load() == seeded)
            #expect(restored.loginItem.isOn)
            #expect(restored.loginItem.calls.isEmpty)
            #expect(restored.permissions.asks.isEmpty)
        }
    }

    @Test(arguments: [false, true])
    func aFailedDownloadShowsTheFailedCardAndTryAgainStartsAnotherAttempt(failsInside: Bool) throws {
        let (world, process) = try Self.offered()
        if failsInside { process.updates.failsInline() }
        process.updateNow()
        if !failsInside {
            process.progress(0.4)
            process.failUpdate()
        }

        #expect(process.card == .failed(Self.next))
        #expect(Copy.updateFailed == "The update couldn't be installed.")
        #expect(Copy.tryAgainButton == "Try again")
        #expect(!process.copies.hasEnded)
        arcComesToFront(process, world)

        process.updateNow()

        #expect(process.card == .downloading(Self.next, progress: 0))
        #expect(process.updates.requests == [.version("1.1.0"), .version("1.1.0")])
        process.updates.deliverLate(.progress(0.9), attempt: 1)
        process.updates.deliverLate(.downloaded, attempt: 1)
        #expect(process.card == .downloading(Self.next, progress: 0))

        process.finishDownload()
        #expect(process.card == .installing(Self.next))
    }

    @Test func anInstallThatFailsBeforeTheNewVersionIsInPlaceLeavesTheRunningOneWorking() throws {
        let (world, process) = try Self.installing()

        process.failUpdate()

        #expect(process.card == .failed(Self.next))
        #expect(!process.isInstalling)
        #expect(world.installedAt == nil)
        arcComesToFront(process, world)
        process.quit()
        #expect(process.copies.hasEnded)
    }

    @Test func aNewVersionThatMacOSDidNotOpenShowsFailedAndTryAgainConverges() throws {
        let (world, process) = try Self.installing()
        process.swapIn()

        process.answerOpen(started: false)

        #expect(process.card == .failed(Self.next))
        #expect(!process.isInstalling)
        #expect(!process.copies.hasEnded)
        arcComesToFront(process, world)

        process.updateNow()
        #expect(process.updates.requests.count == 2)
        process.finishDownload()
        process.swapIn()
        #expect(process.updates.opens == 2)
        process.answerOpen(started: true)
        #expect(process.copies.hasEnded)
    }

    @Test func aFailureWhileTheWindowIsClosedChecksAgainAtTheNextOpening() throws {
        let (_, process) = try Self.installing()
        process.closeWindow()
        process.failUpdate()

        process.openAgain(.byHand)

        #expect(process.releases.fetches == 2)
        #expect(process.card == nil)
        process.deliver([.version("1.1.0")])
        #expect(process.card == .available(Self.next))
    }

    @Test func aCancelledAdministratorPromptReturnsToUpdateNowWithNoErrorAndNothingChanged() throws {
        let (world, process) = try Self.installing()

        process.decline()

        #expect(process.card == .available(Self.next))
        #expect(!process.isInstalling)
        #expect(world.installedAt == nil)
        arcComesToFront(process, world)

        let (closedWorld, closed) = try Self.installing()
        defer { withExtendedLifetime(closedWorld) {} }
        closed.closeWindow()
        closed.decline()
        closed.openAgain(.byHand)
        #expect(closed.releases.fetches == 2)
        #expect(closed.card == nil)
        closed.deliver([.version("1.1.0")])
        #expect(closed.card == .available(Self.next))

        process.quit()
        #expect(process.copies.hasEnded)
    }
}
