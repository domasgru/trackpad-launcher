import Foundation
import LauncherCore
import Testing

@MainActor @Suite struct StartAtLoginTests {
    private static let turnedOffKey = "startAtLoginTurnedOffByQuit"

    private func keys(_ world: LifecycleWorld) -> Set<String> { Set(world.mac.suiteDomain().keys) }

    @Test func quitTurnsItOffAndTheNextOpeningByHandTurnsItBackOn() {
        let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        let running = world.launch(.byHand)
        #expect(running.window == .open(request: 1))

        running.quit()

        #expect(!world.loginItem.isOn)
        #expect(keys(world).count == 2 && keys(world).contains("settings"))
        #expect(running.copies.hasEnded)
        #expect(world.login() == nil)

        let reopened = world.launch(.byHand)

        #expect(reopened.window == .open(request: 1))
        #expect(world.loginItem.isOn)
        #expect(keys(world) == ["settings"])
        #expect(reopened.launcher.app(for: .one) == .present(world.mac.app("Arc")))

        let atLogin = world.login()
        #expect(atLogin != nil)
        atLogin?.tap(1)
        #expect(atLogin?.history == [.closed])
        #expect(atLogin?.window == .closed)
        #expect(atLogin?.system.broughtToFront == [world.mac.app("Arc")])
    }

    @Test(arguments: [InMemoryLoginItem.UserOffReading.refusesRegistering, .acceptsRegistering])
    func theUsersOwnOffIsNeverOverridden(reading: InMemoryLoginItem.UserOffReading) {
        func macWhereTheUserTurnedItOff() -> LifecycleWorld {
            let world = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
            world.loginItem.userOffReading = reading
            world.loginItem.userTurnsOff()
            return world
        }

        let opened = macWhereTheUserTurnedItOff()
        opened.launch(.byHand)
        #expect(!opened.loginItem.calls.contains("register"))
        #expect(!opened.loginItem.isOn)

        let quitAndReopened = macWhereTheUserTurnedItOff()
        quitAndReopened.launch(.byHand).quit()
        quitAndReopened.launch(.byHand)
        #expect(quitAndReopened.loginItem.calls.isEmpty)
        #expect(!quitAndReopened.loginItem.isOn)

        let turnedBackOn = macWhereTheUserTurnedItOff()
        turnedBackOn.loginItem.userTurnsOn()
        turnedBackOn.launch(.byHand).quit()
        turnedBackOn.launch(.byHand)
        #expect(turnedBackOn.loginItem.isOn)
    }

    /// The record the menu bar version wrote: all five gestures assigned, Left thumb.
    private static let menuBarVersionRecord = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>assignments</key>
            <dict>
                <key>1</key>
                <dict><key>bundleID</key><dict><key>rawValue</key><string>com.test.arc</string></dict><key>lastKnownURL</key><dict><key>relative</key><string>file:///tl-fixture/Applications/Arc.app</string></dict><key>name</key><string>Arc</string></dict>
                <key>2</key>
                <dict><key>bundleID</key><dict><key>rawValue</key><string>com.test.notes</string></dict><key>lastKnownURL</key><dict><key>relative</key><string>file:///tl-fixture/Applications/Notes.app</string></dict><key>name</key><string>Notes</string></dict>
                <key>3</key>
                <dict><key>bundleID</key><dict><key>rawValue</key><string>com.test.mail</string></dict><key>lastKnownURL</key><dict><key>relative</key><string>file:///tl-fixture/Applications/Mail.app</string></dict><key>name</key><string>Mail</string></dict>
                <key>4</key>
                <dict><key>bundleID</key><dict><key>rawValue</key><string>com.test.safari</string></dict><key>lastKnownURL</key><dict><key>relative</key><string>file:///tl-fixture/Applications/Safari.app</string></dict><key>name</key><string>Safari</string></dict>
                <key>5</key>
                <dict><key>bundleID</key><dict><key>rawValue</key><string>com.test.slack</string></dict><key>lastKnownURL</key><dict><key>relative</key><string>file:///tl-fixture/Applications/Slack.app</string></dict><key>name</key><string>Slack</string></dict>
            </dict>
            <key>handMode</key>
            <string>left</string>
        </dict>
        </plist>
        """

    @Test func anUpgradeFromTheMenuBarVersionKeepsEverythingAndStartsAtLoginSilently() {
        let apps = ["Arc", "Notes", "Mail", "Safari", "Slack"]
        let world = LifecycleWorld(apps: apps, accessGranted: false, loginItemOn: true)
        let record = Data(Self.menuBarVersionRecord.utf8)
        world.mac.seedSettingsRecord(record)
        for app in apps { world.mac.registry[World.bundleID(app)] = [world.mac.app(app).url] }

        let process = world.launch(.atLogin)

        #expect(process.window == .closed)
        #expect(world.permissions.asks.isEmpty)
        #expect(world.loginItem.calls.isEmpty)
        #expect(world.mac.settingsRecordBytes() == record)
        let rightEdge = (x: 114.8, y: 10.0)
        for (index, app) in apps.enumerated() {
            process.tap(index + 1, thumbAtMM: rightEdge)
            #expect(process.system.broughtToFront.last == world.mac.app(app))
        }
        #expect(process.system.broughtToFront.count == 5)

        process.openAgain(.byHand)

        #expect(process.window == .open(request: 1))
        #expect(world.permissions.asks.isEmpty)
        #expect(world.loginItem.isOn)
        #expect(world.loginItem.calls.isEmpty)
    }

    /// Whatever the run does, a kill between any two of its effects, then an opening by hand from /Applications, ends
    /// as the uncrashed run does: the same login item status, only `settings` in the suite, the same record.
    private func convergesAfterAKillAnywhereIn(_ world: LifecycleWorld, run: (LifecycleWorld) -> Void) {
        let before = world.snapshot()
        run(world)
        let left = [before] + world.snapshots + [world.snapshot()]

        func endAfterOpeningByHand(from snapshot: LifecycleWorld.Snapshot) -> (isOn: Bool, keys: Set<String>, record: Settings?) {
            let mac = LifecycleWorld(restoring: snapshot)
            mac.launch(.byHand)
            return (mac.loginItem.isOn, Set(mac.mac.suiteDomain().keys), mac.mac.freshStore().load())
        }

        let uncrashed = endAfterOpeningByHand(from: left.last!)
        #expect(uncrashed.keys == ["settings"])
        #expect(left.count > 2)
        for (index, snapshot) in left.enumerated() {
            let end = endAfterOpeningByHand(from: snapshot)
            #expect(end.isOn == uncrashed.isOn, "login item after a kill at effect \(index)")
            #expect(end.keys == ["settings"], "suite after a kill at effect \(index)")
            #expect(end.record == uncrashed.record, "record after a kill at effect \(index)")
        }
    }

    @Test func aKillAnywhereInAQuitConvergesOnTheNextOpeningByHand() {
        convergesAfterAKillAnywhereIn(LifecycleWorld(record: [:], loginItemOn: true)) { world in
            world.launch(.byHand).quit()
        }
    }

    @Test func aKillAnywhereInTheOpeningAfterAQuitConverges() {
        let world = LifecycleWorld(record: [:], loginItemOn: true)
        world.launch(.byHand).quit()
        convergesAfterAKillAnywhereIn(world) { world in world.launch(.byHand) }
    }

    @Test func aKillAnywhereInAFirstRunConverges() {
        convergesAfterAKillAnywhereIn(LifecycleWorld(accessGranted: false)) { world in world.launch(.byHand) }
    }

    @Test func aDevelopmentBuildOutsideApplicationsNeverTouchesStartingAtLogin() {
        let firstRun = LifecycleWorld(accessGranted: false)
        let process = firstRun.launch(.byHand, placement: .development)

        #expect(process.window == .open(request: 1))
        #expect(firstRun.permissions.asks == [.accessibility])
        #expect(firstRun.mac.freshStore().load() != nil)
        #expect(firstRun.loginItem.calls.isEmpty)

        let installed = LifecycleWorld(record: [.one: "Arc"], loginItemOn: true)
        installed.launch(.byHand, placement: .development).quit()

        #expect(installed.loginItem.calls.isEmpty)
        #expect(installed.loginItem.isOn)
        #expect(installed.login() != nil)
    }
}
