import Foundation
import LauncherCore
import Testing

@MainActor @Suite struct UpdateCheckTests {
    private static func newerOne() -> [Release] { [.version("1.1.0")] }

    /// A day on a running copy: every gesture, a permission flipped, a trackpad changed, a login reopen.
    private static func aDayPasses(in world: LifecycleWorld, _ process: OneProcess) {
        for fingers in 1...5 { process.tap(fingers) }
        world.permissions.set(.accessibility, granted: false)
        world.permissions.set(.accessibility, granted: true)
        process.preferences.set(.tapToClick, rawValue: 1, for: .builtIn)
        process.preferences.touch()
        process.openAgain(.atLogin)
    }

    @Test func aNewerVersionAppearsAsTheCardMomentsAfterTheWindowOpens() throws {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let process = try #require(world.login(running: .release("1.0.0")))
        #expect(process.releases.fetches == 0)

        process.openAgain(.byHand)

        #expect(process.history.last == .init(window: .open(request: 1), card: nil))
        #expect(process.releases.fetches == 1)

        process.deliver(Self.newerOne())

        let card = try #require(process.card)
        #expect(card == .available(Version(1, 1, 0)))
        guard case .available(let version) = card else { return }
        #expect(Copy.updateAvailable(version) == "Version 1.1.0 is available")
        #expect(Copy.updateNowButton == "Update now")
    }

    @Test func aListThatAnswersInsideTheCallShowsTheCardWithTheOpening() throws {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let process = try #require(world.login(running: .release("1.0.0")))
        process.releases.answersInline(Self.newerOne())

        process.openAgain(.byHand)

        #expect(process.history.last == .init(window: .open(request: 1), card: .available(Version(1, 1, 0))))
        #expect(process.releases.fetches == 1)
    }

    @Test func reopeningAnOpenWindowChecksNothingAndLaterOpeningsCheckAgain() throws {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let process = try #require(world.login(running: .release("1.0.0")))
        process.openAgain(.byHand)
        process.deliver([])

        process.openAgain(.byHand)
        process.openAgain(.byHand)
        Self.aDayPasses(in: world, process)

        #expect(process.windows.suffix(3).first == .open(request: 2))
        #expect(process.window == .open(request: 3))
        #expect(process.releases.fetches == 1)
        #expect(process.history.allSatisfy { $0.card == nil })

        process.closeWindow()
        process.openAgain(.byHand)
        process.deliver(Self.newerOne())

        #expect(process.releases.fetches == 2)
        #expect(process.card == .available(Version(1, 1, 0)))
    }

    @Test func aCheckThatTheWindowClosedOnIsDropped() throws {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let process = try #require(world.login(running: .release("1.0.0")))
        process.openAgain(.byHand)

        process.closeWindow()
        process.deliver(Self.newerOne())

        #expect(process.history.allSatisfy { $0.card == nil })
        #expect(process.releases.fetches == 1)

        process.openAgain(.byHand)
        process.deliver(Self.newerOne())
        #expect(process.card == .available(Version(1, 1, 0)))
    }

    @Test func anEarlierOpeningsAnswerNeverReachesALaterOpening() throws {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let process = try #require(world.login(running: .release("1.0.0")))
        process.openAgain(.byHand)
        process.closeWindow()
        process.openAgain(.byHand)

        process.deliver(Self.newerOne(), toFetch: 1)
        process.deliver([], toFetch: 2)

        #expect(process.history.allSatisfy { $0.card == nil })
        #expect(process.releases.fetches == 2)

        process.closeWindow()
        process.openAgain(.byHand)
        process.deliver(Self.newerOne())
        #expect(process.card == .available(Version(1, 1, 0)))
    }

    @Test func aFailedCheckIsSilentAndTheNextOpeningChecksAgain() throws {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let process = try #require(world.login(running: .release("1.0.0")))
        process.openAgain(.byHand)

        process.failCheck()

        #expect(process.card == nil)
        #expect(process.history.suffix(2).first == process.history.last)

        process.closeWindow()
        process.openAgain(.byHand)
        process.deliver(Self.newerOne())

        #expect(process.releases.fetches == 2)
        #expect(process.card == .available(Version(1, 1, 0)))
    }

    struct Case: Sendable, CustomTestStringConvertible {
        let running: String
        let macOS: String
        let list: [(version: String, needs: String)]
        let offered: String?
        var testDescription: String { "\(running) on \(macOS) given \(list.map { "\($0.version)/\($0.needs)" }) -> \(offered ?? "none")" }
    }

    @Test(arguments: [
        Case(running: "1.0.0", macOS: "26.0", list: [("1.1.0", "26.0"), ("1.2.0", "27.0")], offered: "1.1.0"),
        Case(running: "1.9.0", macOS: "26.0", list: [("1.10.0", "26.0")], offered: "1.10.0"),
        Case(running: "1.0.0", macOS: "26.0", list: [("1.2.0", "26.0"), ("1.10.0", "26.0"), ("1.9.0", "26.0")], offered: "1.10.0"),
        Case(running: "1.0.0", macOS: "26.0", list: [("1.1.0", "27.0")], offered: nil),
        Case(running: "1.1.0", macOS: "26.0", list: [("1.1.0", "26.0")], offered: nil),
        Case(running: "1.1", macOS: "26.0", list: [("1.1.0", "26.0")], offered: nil),
        Case(running: "1.1.0", macOS: "26.0", list: [("1.0.5", "26.0")], offered: nil),
        Case(running: "1.0.0", macOS: "26.6.2", list: [("1.1.0", "26.6.2")], offered: "1.1.0"),
        Case(running: "1.0.0", macOS: "26.6.2", list: [("1.1.0", "26.6.3")], offered: nil),
    ])
    func theCardOffersTheHighestReleaseThatCountsAsNewer(_ row: Case) throws {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let process = try #require(world.login(running: .release(row.running, macOS: row.macOS)))
        process.openAgain(.byHand)

        process.deliver(row.list.map { .version($0.version, needs: $0.needs) })

        let expected = row.offered.map { UpdateCard.available(Version($0)!) }
        #expect(process.card == expected)
        if let offered = row.offered, case .available(let version)? = process.card {
            #expect(Copy.updateAvailable(version) == "Version \(offered) is available")
        }
    }

    @Test func aLoginStartAndAWholeDayNeverMakeARequestButAnOpeningMakesExactlyOne() throws {
        let first = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let atLogin = try #require(first.login(running: .release("1.0.0")))
        Self.aDayPasses(in: first, atLogin)
        #expect(atLogin.releases.fetches == 0)
        #expect(atLogin.card == nil)

        let second = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let opened = try #require(second.login(running: .release("1.0.0")))
        opened.openAgain(.byHand)
        opened.deliver(Self.newerOne())
        opened.closeWindow()
        Self.aDayPasses(in: second, opened)
        #expect(opened.releases.fetches == 1)
        #expect(opened.card == nil)
    }

    @Test func aReleaseCopyOutsideApplicationsNeverChecksAndEndsOnQuit() {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let process = world.launch(.atLogin, placement: .elsewhere, running: .release("1.0.0"))
        process.tap(1)
        process.openAgain(.byHand)
        #expect(process.moveDialog == .asking)

        process.answer(.quit)

        #expect(process.updater == nil)
        #expect(process.releases.fetches == 0)
        #expect(process.copies.hasEnded)
    }

    @Test func aReleaseCopyOpenedFromDownloadsWithTheDialogUnansweredNeverChecks() {
        let world = LifecycleWorld(record: [.one: "Arc"])
        let process = world.launch(.byHand, placement: .elsewhere, running: .release("1.0.0"))

        #expect(process.moveDialog == .asking)
        #expect(process.updater == nil)
        #expect(process.releases.fetches == 0)
    }

    @Test(arguments: [Placement.installed, .development])
    func aDevelopmentBuildOpensItsWindowWithoutACheckOrACard(placement: Placement) {
        let world = LifecycleWorld(record: [.one: "Arc"])
        let process = world.launch(.byHand, placement: placement, running: .development)
        process.openAgain(.byHand)

        #expect(process.window == .open(request: 2))
        #expect(process.updater == nil)
        #expect(process.releases.fetches == 0)
        #expect(process.history.allSatisfy { $0.card == nil })
    }

    @Test func theCardsLayoutIgnoresProgressAndTellsTheFourStatesApart() {
        let version = Version(1, 1, 0)
        #expect(UpdateCard.downloading(version, progress: 0.4).layout == UpdateCard.downloading(version, progress: 0.9).layout)
        let layouts: [UpdateCard.Layout] = [
            UpdateCard.available(version).layout, UpdateCard.downloading(version, progress: 0).layout,
            UpdateCard.installing(version).layout, UpdateCard.failed(version).layout,
        ]
        #expect(Set(layouts).count == 4)
    }
}
