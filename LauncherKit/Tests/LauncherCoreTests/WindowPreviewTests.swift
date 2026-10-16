import Testing
import LauncherCore

@MainActor @Suite struct WindowPreviewTests {
    @Test func withoutScreenRecordingRowsShowIconsAndAGrantShowsPreviewsOfVisibleWindowsFromTheNextWindowSwipe() {
        let world = World.windowWorld(visible: ["Docs", "Mail"], minimised: ["Notes"], screenRecording: false)

        let first = world.windowSwipe(3.5, lift: false)
        let lifted = first.lift()
        #expect(world.launcher.windowSwitcher?.showsPreviews == false)
        #expect(world.launcher.windowSwitcher?.previewWindows == [])
        world.play(lifted)
        #expect(world.permissions.asks.isEmpty)

        world.permissions.set(.screenRecording, granted: true)
        world.play(lifted.land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 3.5)))

        #expect(world.launcher.windowSwitcher?.showsPreviews == true)
        #expect(world.launcher.windowSwitcher?.previewWindows == [world.window("Docs"), world.window("Mail")])
        #expect(world.permissions.asks.isEmpty)
    }

    @Test func aGrantMidWindowSwipeLeavesTheOpenSwitcherAsItBeganAndTheNextWindowSwipeShowsPreviews() {
        let world = World.windowWorld(visible: ["Docs", "Mail", "News"], screenRecording: false)
        let atMail = world.windowSwipe(3.5, 12, lift: false)
        let serial = world.launcher.windowSwitcher?.serial
        let runs = world.hardware.runCount

        world.permissions.set(.screenRecording, granted: true)
        let atNews = atMail.slide(byMM: (0, 12))
        world.play(atNews)

        #expect(world.hardware.runCount == runs)
        #expect(world.launcher.windowSwitcher?.serial == serial)
        #expect(world.launcher.windowSwitcher?.showsPreviews == false)
        #expect(world.launcher.windowSwitcher?.selection.selected == 2)

        let lifted = atNews.lift()
        world.play(lifted)
        world.play(lifted.land(fingers: 2, atMM: (62, 30)).slide(byMM: (0, 3.5)))

        #expect(world.launcher.windowSwitcher?.showsPreviews == true)
    }

    @Test(arguments: ["a notification that changes nothing", "a relaunch"])
    func aGrantWhoseBroadcastNeverCameShowsPreviewsAfterTheNextPushOrARelaunch(after event: String) {
        let world = World.windowWorld(visible: ["Docs", "Mail"], screenRecording: false)

        world.permissions.set(.screenRecording, granted: true, push: false)
        if event == "a relaunch" { world.relaunch().start() } else { world.preferences.touch() }
        world.windowSwipe(3.5, lift: false)

        #expect(world.launcher.windowSwitcher?.showsPreviews == true, "\(event)")
        #expect(world.launcher.windowSwitcher?.previewWindows == [world.window("Docs"), world.window("Mail")])
    }

    // MARK: The screen recording hint

    @Test func theHintShowsWhileScreenRecordingIsMissingAndTheWindowSwipeIsOn() {
        let world = World(accessGranted: true)
        world.launcher.start()
        var seen = [world.launcher.screenRecordingHint]

        world.launcher.setWindowSwipe(on: false)
        seen.append(world.launcher.screenRecordingHint)
        world.launcher.setWindowSwipe(on: true)
        seen.append(world.launcher.screenRecordingHint)
        world.permissions.set(.screenRecording, granted: true)
        seen.append(world.launcher.screenRecordingHint)
        world.permissions.set(.screenRecording, granted: false)
        seen.append(world.launcher.screenRecordingHint)

        #expect(seen == [.ask, nil, .ask, nil, .ask])
    }

    @Test func theFirstPressAsksMacOSOnceAndLaterPressesOpenSystemSettingsAcrossARelaunchUntilTheGrant() {
        let world = World(accessGranted: true)
        world.launcher.start()
        #expect(world.launcher.screenRecordingHint == .ask)
        var storedDuringAsk: [Bool?] = []
        world.permissions.onAsk = { [unowned world] in
            storedDuringAsk.append(world.store.load()?.hasAskedForScreenRecording)
        }

        world.launcher.askForScreenRecording()
        #expect(world.launcher.screenRecordingHint == .openSettings)
        world.launcher.askForScreenRecording()

        #expect(world.permissions.asks == [.screenRecording])
        #expect(storedDuringAsk == [true])
        world.relaunch().start()
        #expect(world.launcher.screenRecordingHint == .openSettings)
        world.permissions.set(.screenRecording, granted: true)
        #expect(world.launcher.screenRecordingHint == nil)
    }
}
