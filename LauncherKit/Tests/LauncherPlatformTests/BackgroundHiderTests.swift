import AppKit
import LauncherCore
import Testing

@testable import LauncherPlatform

/// A stage for `BackgroundHider`: the test sets what macOS would report and posts the workspace's own notifications, so
/// any order of activating and unhiding can be played, with no real app touched.
@MainActor private final class Stage {
    var frontmost: String? = "com.example.before"
    var shown: Set<String> = []
    var hides: [String] = []
    var onHide: (() -> Void)?

    var apps: BackgroundHider.Apps {
        BackgroundHider.Apps(
            frontmost: { [unowned self] in frontmost },
            isShowing: { [unowned self] in shown.contains($0) },
            hideOthers: { [unowned self] in
                hides.append($0)
                onHide?()
            })
    }

    func activate(_ id: String) {
        frontmost = id
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didActivateApplicationNotification, object: nil)
    }

    func unhide(_ id: String) {
        shown.insert(id)
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didUnhideApplicationNotification, object: nil)
    }

    /// Long enough for the next main-actor turn and any notification queued on the main queue.
    func settle() async {
        for _ in 0..<5 { await Task.yield() }
        try? await Task.sleep(for: .milliseconds(30))
    }
}

/// Serialized: the rows share the process-wide clock host and the workspace's notification centre.
@MainActor @Suite(.serialized) struct BackgroundHiderTests {
    private let safari = BundleID(rawValue: "com.apple.Safari")

    @Test func arrivalNeedsTheAppActiveAndNoLongerHidden() {
        #expect(BackgroundHider.hasArrived(goal: "a", frontmost: "a", isShowing: true))
        #expect(!BackgroundHider.hasArrived(goal: "a", frontmost: "a", isShowing: false))
        #expect(!BackgroundHider.hasArrived(goal: "a", frontmost: "b", isShowing: true))
        #expect(!BackgroundHider.hasArrived(goal: "a", frontmost: nil, isShowing: true))
    }

    @Test func aHiddenAppThatActivatesHidesNothingUntilItIsUnhidden() async {
        let stage = Stage()
        let hider = BackgroundHider(apps: stage.apps, recheckWaits: [])
        hider.hideOthers(than: safari)
        await stage.settle()
        stage.activate(safari.rawValue)
        await stage.settle()
        // The gap macOS leaves: a hide here sends the front to a third app.
        #expect(stage.hides.isEmpty)
        stage.unhide(safari.rawValue)
        await stage.settle()
        #expect(stage.hides == [safari.rawValue])
    }

    @Test func anUnhideBeforeTheActivationHidesOnTheActivation() async {
        let stage = Stage()
        let hider = BackgroundHider(apps: stage.apps, recheckWaits: [])
        hider.hideOthers(than: safari)
        stage.unhide(safari.rawValue)
        await stage.settle()
        #expect(stage.hides.isEmpty)
        stage.activate(safari.rawValue)
        await stage.settle()
        #expect(stage.hides == [safari.rawValue])
    }

    @Test func anotherAppsActivationDoesNotLoseTheHide() async {
        let stage = Stage()
        stage.shown = [safari.rawValue]
        let hider = BackgroundHider(apps: stage.apps, recheckWaits: [])
        hider.hideOthers(than: safari)
        stage.activate("com.example.helper")
        await stage.settle()
        #expect(stage.hides.isEmpty)
        stage.activate(safari.rawValue)
        await stage.settle()
        #expect(stage.hides == [safari.rawValue])
    }

    @Test func anAppAlreadyInFrontHidesOnTheNextTurnAndNotInTheCall() async {
        let stage = Stage()
        stage.frontmost = safari.rawValue
        stage.shown = [safari.rawValue]
        let hider = BackgroundHider(apps: stage.apps, recheckWaits: [])
        hider.hideOthers(than: safari)
        #expect(stage.hides.isEmpty)
        await stage.settle()
        #expect(stage.hides == [safari.rawValue])
    }

    @Test func aLaterGoalReplacesAnEarlierOneThatNeverArrived() async {
        let stage = Stage()
        let mail = "com.apple.mail"
        stage.shown = [safari.rawValue, mail]
        let hider = BackgroundHider(apps: stage.apps, recheckWaits: [])
        hider.hideOthers(than: safari)
        hider.hideOthers(than: BundleID(rawValue: mail))
        stage.activate(safari.rawValue)
        await stage.settle()
        #expect(stage.hides.isEmpty)
        stage.activate(mail)
        await stage.settle()
        #expect(stage.hides == [mail])
    }

    @Test func aGoalThatNeverArrivesGivesUpAndHidesNothing() async {
        let stage = Stage()
        let hider = BackgroundHider(apps: stage.apps, arrivalLimit: .milliseconds(50), recheckWaits: [])
        hider.hideOthers(than: safari)
        let host = await awaiting("the run to end", within: .seconds(30)) { (done: @escaping @Sendable (Bool) -> Void) in
            Task { @MainActor in
                while LaunchClock.hostPanel != nil { try? await Task.sleep(for: .milliseconds(20)) }
                done(true)
            }
        }
        #expect(host == true)
        stage.shown = [safari.rawValue]
        stage.activate(safari.rawValue)
        await stage.settle()
        #expect(stage.hides.isEmpty)
    }

    @Test func laterPassesHideAgainWhileTheAppStaysInFront() async {
        let stage = Stage()
        stage.frontmost = safari.rawValue
        stage.shown = [safari.rawValue]
        let hider = BackgroundHider(apps: stage.apps, recheckWaits: [.milliseconds(20), .milliseconds(20)])
        let passes = await awaiting("three passes", within: .seconds(30)) { (done: @escaping @Sendable (Int) -> Void) in
            stage.onHide = { if stage.hides.count == 3 { done(3) } }
            hider.hideOthers(than: safari)
        }
        #expect(passes == 3)
    }

    @Test func aUserWhoMovedOnKeepsWhatTheySee() async {
        let stage = Stage()
        stage.frontmost = safari.rawValue
        stage.shown = [safari.rawValue]
        let hider = BackgroundHider(apps: stage.apps, recheckWaits: [.milliseconds(300)])
        hider.hideOthers(than: safari)
        await stage.settle()
        #expect(stage.hides.count == 1)
        stage.frontmost = "com.apple.mail"
        try? await Task.sleep(for: .milliseconds(450))
        #expect(stage.hides.count == 1)
    }
}
