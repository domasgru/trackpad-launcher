import Foundation
import Testing
import LauncherCore

@MainActor @Suite struct HideBackgroundAppsTests {
    private func B(_ name: String) -> BundleID { World.bundleID(name) }

    private func hideWorld(frontmost: String = "Safari", hideOn: Bool = true) -> World {
        let world = World.switcherWorld(apps: ["Safari", "Mail", "Notes"], frontmost: frontmost)
        world.launcher.setHideBackgroundApps(on: hideOn)
        world.launcher.setAssignment(.app(world.app("Safari")), for: .one)
        return world
    }

    private func nothingHidOrShown(_ world: World) -> Bool {
        world.system.hidesOthers.isEmpty && world.system.hiddenApps.isEmpty && world.hardware.feedback.isEmpty
            && world.system.broughtToFront.isEmpty
    }

    @Test func theSettingIsOffOnAFreshInstall() {
        let world = World(apps: ["Arc"])
        world.launcher.start()
        #expect(!world.launcher.isHideBackgroundAppsOn)
    }

    @Test func aRecordAReleasedBuildWroteLoadsOffAndATapHidesNothingAtLogin() {
        let world = World()
        for (name, bundleID) in [
            ("Arc", "company.thebrowser.Browser"), ("Figma", "com.figma.Desktop"), ("Spotify", "com.spotify.client"),
        ] {
            world.registry[BundleID(rawValue: bundleID)] = [world.install(name, bundleID: bundleID)]
        }
        world.seedSettingsRecord(Data(PersistenceTests.savedSettings.utf8))

        let relaunched = world.relaunch()
        relaunched.start()
        world.makeRunning(["Arc"])
        // The record anchors the thumb top right.
        world.tap(1, thumbAtMM: (114.8, 10))

        #expect(!relaunched.isHideBackgroundAppsOn)
        #expect(world.system.broughtToFront == [world.app("Arc")])
        #expect(world.system.hidesOthers.isEmpty)
    }

    @Test func theChoiceSurvivesARelaunchAndALoginStart() throws {
        let world = World(apps: ["Arc"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)
        world.launcher.setHideBackgroundApps(on: true)
        let bytes = try #require(world.settingsRecordBytes())
        let record = try #require(try PropertyListSerialization.propertyList(from: bytes, format: nil) as? [String: Any])
        #expect(record["isHideBackgroundAppsOn"] as? Bool == true)

        let relaunched = world.relaunch()
        relaunched.start()
        world.makeRunning(["Arc"])
        #expect(relaunched.isHideBackgroundAppsOn)
        world.tap(1)
        #expect(world.system.hidesOthers == [B("Arc")])

        relaunched.openedByHand()
        #expect(relaunched.isHideBackgroundAppsOn)
    }

    @Test func aRecordHoldingOnlyTheKeyLoadsItOnWithEveryOtherDefault() {
        let world = World()
        world.seedSettingsRecord(Data("""
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>isHideBackgroundAppsOn</key>
                <true/>
            </dict>
            </plist>
            """.utf8))

        var expected = Settings()
        expected.isHideBackgroundAppsOn = true
        #expect(world.store.load() == expected)
    }

    @Test func flippingTheSwitchHidesAndShowsNothing() {
        let world = hideWorld(hideOn: false)

        world.launcher.setHideBackgroundApps(on: true)
        #expect(world.system.hidesOthers.isEmpty)
        #expect(world.system.broughtToFront.isEmpty)
        #expect(world.system.hiddenApps.isEmpty)

        world.tap(1)
        #expect(world.system.hiddenApps == [B("Mail"), B("Notes")])

        world.launcher.setHideBackgroundApps(on: false)
        #expect(world.system.hiddenApps == [B("Mail"), B("Notes")])
        #expect(world.system.hidesOthers.count == 1)

        world.tap(1)
        #expect(world.system.broughtToFront == [world.app("Safari"), world.app("Safari")])
        #expect(world.system.hidesOthers.count == 1)
    }

    @Test func aTapHidesEverythingElseAfterTheBringToFrontAndTheAnimation() {
        let world = hideWorld(frontmost: "Mail")
        var seen: (broughtToFront: [AppEntry], launchAnimations: [AppEntry])?
        world.system.onHideOtherApps = { [unowned world] in
            seen = (world.system.broughtToFront, world.system.launchAnimations)
        }

        world.tap(1)

        #expect(world.system.broughtToFront == [world.app("Safari")])
        #expect(world.system.hidesOthers == [B("Safari")])
        #expect(world.system.hiddenApps == [B("Mail"), B("Notes")])
        #expect(world.system.launchAnimations == [world.app("Safari")])
        #expect(world.hardware.feedback == [Trackpad.macBook14.id])
        #expect(seen?.broughtToFront == [world.app("Safari")])
        #expect(seen?.launchAnimations == [world.app("Safari")])
    }

    @Test func aTapOnTheAppAlreadyInFrontStillHidesTheOthers() {
        let world = hideWorld()
        world.tap(1)
        #expect(world.system.hidesOthers == [B("Safari")])
        #expect(world.system.hiddenApps == [B("Mail"), B("Notes")])
    }

    @Test func withTheLaunchAnimationOffATapStillHides() {
        let world = hideWorld(frontmost: "Mail")
        world.launcher.setLaunchAnimation(on: false)

        world.tap(1)

        #expect(world.system.broughtToFront == [world.app("Safari")])
        #expect(world.system.hidesOthers == [B("Safari")])
        #expect(world.system.launchAnimations.isEmpty)
        #expect(world.system.bounces.isEmpty)
    }

    @Test(arguments: [true, false])
    func anAppWithNoProcessIsBroughtToFrontAndNothingIsHidden(animates: Bool) {
        let world = hideWorld()
        world.launcher.setLaunchAnimation(on: animates)
        world.install("Figma")
        world.launcher.setAssignment(.app(world.app("Figma")), for: .two)

        world.tap(2)

        #expect(world.system.broughtToFront == [world.app("Figma")])
        #expect(world.system.hidesOthers.isEmpty)
        #expect(world.system.bounces.map(\.app) == (animates ? [world.app("Figma")] : []))
    }

    @Test func aGestureWhoseBounceStillPlaysHidesNothing() {
        let world = hideWorld()
        world.install("Figma")
        world.launcher.setAssignment(.app(world.app("Figma")), for: .two)
        world.tap(2)

        world.tap(2)

        #expect(world.system.bounces.count == 1)
        #expect(world.system.hidesOthers.isEmpty)
    }

    @Test func aTapWithNoAssignmentOrAnUninstalledAppHidesNothing() {
        let world = hideWorld()
        world.launcher.setAssignment(.app(world.app("Notes")), for: .two)
        world.remove("Notes")

        world.tap(3)
        world.tap(2)

        #expect(world.system.hidesOthers.isEmpty)
        #expect(world.system.broughtToFront.isEmpty)
    }

    @Test func aSwipeLiftHidesEverythingElseAndKeepsTheSelectedApp() {
        let world = World.switcherWorld(apps: ["Safari", "Mail", "Notes"], frontmost: "Notes")
        world.launcher.setHideBackgroundApps(on: true)

        world.swipe(3.5, 12)

        #expect(world.system.broughtToFront == [world.app("Safari")])
        #expect(world.system.hidesOthers == [B("Safari")])
        #expect(world.system.hiddenApps == [B("Mail"), B("Notes")])
        #expect(world.hardware.feedback.count == 1)
    }

    @Test func aSwipeLiftOnAHiddenAppBringsItForwardAndHidesTheOthers() {
        let world = hideWorld()
        world.tap(1)

        world.swipe(3.5, 12, 12)

        #expect(world.system.broughtToFront == [world.app("Safari"), world.app("Notes")])
        #expect(world.system.hidesOthers == [B("Safari"), B("Notes")])
        #expect(world.system.hiddenApps == [B("Mail"), B("Safari")])
        #expect(world.hardware.feedback.count == 2)
    }

    @Test func aHiddenAppTheLastSwapLeftBehindIsTheNextTapsTarget() {
        let world = hideWorld(frontmost: "Safari")
        world.swap()
        world.activate("Mail")

        world.tap(1)

        #expect(world.system.broughtToFront.last == world.app("Safari"))
        #expect(world.system.hidesOthers.last == B("Safari"))
    }

    @Test func eachSwapOfASeriesHidesEverythingElseIncludingTheHiddenTarget() {
        let world = hideWorld()
        world.tap(1)

        let script = world.swap(taps: 1, lift: false)
        #expect(world.system.broughtToFront == [world.app("Safari"), world.app("Mail")])
        #expect(world.system.hidesOthers == [B("Safari"), B("Mail")])
        #expect(world.system.hiddenApps == [B("Safari"), B("Notes")])

        world.activate("Mail")
        world.play(script.thumbTap(atMM: (10, 10)).lift())
        #expect(world.system.broughtToFront == [world.app("Safari"), world.app("Mail"), world.app("Safari")])
        #expect(world.system.hidesOthers == [B("Safari"), B("Mail"), B("Safari")])
        #expect(world.system.hiddenApps == [B("Mail"), B("Notes")])
        #expect(world.hardware.pulses.allSatisfy { $0.haptic == .gesture })
    }

    @Test func twoThumbTapsBeforeAnyActivationLandsAlternateToo() {
        let world = hideWorld()
        world.tap(1)

        world.swap(taps: 2)

        #expect(world.system.broughtToFront == [world.app("Safari"), world.app("Mail"), world.app("Safari")])
        #expect(world.system.hidesOthers == [B("Safari"), B("Mail"), B("Safari")])
    }

    @Test func aWindowSwipeHidesNothingWhileSlidingAndEverythingButTheFrontAppOnTheLift() {
        let world = World.windowWorld(visible: ["Docs", "Mail"])
        world.launcher.setHideBackgroundApps(on: true)
        let script = TouchScript(Trackpad.macBook14.surface).thumb(atMM: (10, 10)).land(fingers: 2, atMM: (62, 30))
            .slide(byMM: (0, 3.5)).slide(byMM: (0, 12))

        let hides = world.playFrameByFrame(script) { world.system.hidesOthers }
        #expect(hides.allSatisfy { $0.isEmpty })
        #expect(world.system.windows.onScreenTitles.first == "Mail")

        world.play(script.lift())
        #expect(world.system.windows.onScreenTitles == ["Mail", "Docs"])
        #expect(world.system.hidesOthers == [B("Safari")])
        #expect(world.system.hiddenApps == [B("Mail"), B("Preview"), B("TextEdit"), B("Notes")])
        #expect(world.hardware.feedback.count == 1)
        #expect(world.system.broughtToFront.isEmpty)
    }

    @Test func liftingOnTheFrontmostAppHidesNothing() {
        let world = hideWorld()
        world.swipe(3.5)
        #expect(nothingHidOrShown(world))
    }

    @Test func aCancelledWindowSwipeHidesNothing() {
        let world = World.windowWorld(visible: ["Docs", "Mail"])
        world.launcher.setHideBackgroundApps(on: true)
        let hand = world.windowSwipe(3.5, 12, lift: false)
        world.play(hand.wait(.milliseconds(10)).land(fingers: 1, atMM: (86, 45)).lift())
        #expect(nothingHidOrShown(world))
    }

    @Test func aSwipeWhoseTargetQuitBeforeTheLiftHidesNothing() {
        let world = hideWorld()
        let hand = world.swipe(3.5, 12, lift: false)
        world.makeRunning(["Safari", "Notes"])
        world.play(hand.lift())
        #expect(nothingHidOrShown(world))
    }

    @Test func aWindowSwipeLiftingOnTheFrontWindowHidesNothing() {
        let world = World.windowWorld(visible: ["Docs", "Mail"])
        world.launcher.setHideBackgroundApps(on: true)
        world.windowSwipe(3.5, 12, -12)
        #expect(world.system.windows.raised == [[world.window("Mail")], [world.window("Docs")], []])
        #expect(world.system.hidesOthers.isEmpty)
        #expect(world.system.hiddenApps.isEmpty)
        #expect(world.hardware.feedback.isEmpty)
        #expect(world.system.broughtToFront.isEmpty)
    }

    @Test func aSwapWithNothingToSwapToHidesNothing() {
        let world = World.switcherWorld(apps: ["Safari"], running: ["Safari"])
        world.launcher.setHideBackgroundApps(on: true)
        world.swap()
        #expect(nothingHidOrShown(world))
    }
}
