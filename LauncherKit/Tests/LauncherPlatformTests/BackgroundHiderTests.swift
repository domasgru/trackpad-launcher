import AppKit
import LauncherCore
import Testing

@testable import LauncherPlatform

/// A stage for `BackgroundHider`: the test sets what macOS would report and posts the workspace's own notifications, so
/// any order of activating and unhiding can be played, with no real app touched.
@MainActor private final class Stage {
    var frontmost: String? = "com.example.before"
    var shown: Set<String> = []
    /// The front app each hide kept, in order.
    var hides: [String] = []
    /// What each hide kept, in order.
    var kept: [KeptApps] = []
    var onHide: (() -> Void)?

    var apps: BackgroundHider.Apps {
        BackgroundHider.Apps(
            frontmost: { [unowned self] in frontmost },
            isShowing: { [unowned self] in shown.contains($0) },
            hideOthers: { [unowned self] in
                hides.append($0.front.rawValue)
                kept.append($0)
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
        hider.hideOthers(keeping: KeptApps(front: safari))
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
        hider.hideOthers(keeping: KeptApps(front: safari))
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
        hider.hideOthers(keeping: KeptApps(front: safari))
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
        hider.hideOthers(keeping: KeptApps(front: safari))
        #expect(stage.hides.isEmpty)
        await stage.settle()
        #expect(stage.hides == [safari.rawValue])
    }

    @Test func aLaterGoalReplacesAnEarlierOneThatNeverArrived() async {
        let stage = Stage()
        let mail = "com.apple.mail"
        stage.shown = [safari.rawValue, mail]
        let hider = BackgroundHider(apps: stage.apps, recheckWaits: [])
        hider.hideOthers(keeping: KeptApps(front: safari))
        hider.hideOthers(keeping: KeptApps(front: BundleID(rawValue: mail)))
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
        hider.hideOthers(keeping: KeptApps(front: safari))
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
            hider.hideOthers(keeping: KeptApps(front: safari))
        }
        #expect(passes == 3)
    }

    private let notes = BundleID(rawValue: "com.apple.Notes")

    @Test func aHideKeepsBothAppsOfASplitGesture() async {
        let stage = Stage()
        stage.frontmost = notes.rawValue
        stage.shown = [notes.rawValue, safari.rawValue]
        let hider = BackgroundHider(apps: stage.apps, recheckWaits: [])
        hider.hideOthers(keeping: KeptApps(front: notes, beside: safari))
        await stage.settle()
        #expect(stage.kept == [KeptApps(front: notes, beside: safari)])
    }

    @Test func theAppBesideTheGoalInFrontHidesNothingAndTheRunGoesOn() async {
        let stage = Stage()
        stage.frontmost = notes.rawValue
        stage.shown = [notes.rawValue, safari.rawValue]
        let hider = BackgroundHider(apps: stage.apps, recheckWaits: [.milliseconds(300), .milliseconds(300)])
        hider.hideOthers(keeping: KeptApps(front: notes, beside: safari))
        await stage.settle()
        #expect(stage.hides.count == 1)
        stage.frontmost = safari.rawValue
        try? await Task.sleep(for: .milliseconds(450))
        #expect(stage.hides.count == 1)
        stage.frontmost = notes.rawValue
        try? await Task.sleep(for: .milliseconds(300))
        #expect(stage.hides.count == 2)
    }

    @Test func aThirdAppInFrontEndsTheRunOfASplitGesture() async {
        let stage = Stage()
        stage.frontmost = notes.rawValue
        stage.shown = [notes.rawValue, safari.rawValue]
        let hider = BackgroundHider(apps: stage.apps, recheckWaits: [.milliseconds(300), .milliseconds(300)])
        hider.hideOthers(keeping: KeptApps(front: notes, beside: safari))
        await stage.settle()
        stage.frontmost = "com.apple.mail"
        try? await Task.sleep(for: .milliseconds(450))
        stage.frontmost = notes.rawValue
        try? await Task.sleep(for: .milliseconds(300))
        #expect(stage.hides.count == 1)
    }

    @Test func theBesideAppInFrontAtTheCallHidesNothingUntilTheGoalArrives() async {
        let stage = Stage()
        stage.frontmost = safari.rawValue
        stage.shown = [safari.rawValue]
        let hider = BackgroundHider(apps: stage.apps, recheckWaits: [])
        hider.hideOthers(keeping: KeptApps(front: notes, beside: safari))
        await stage.settle()
        #expect(stage.hides.isEmpty)
        stage.unhide(notes.rawValue)
        stage.activate(notes.rawValue)
        await stage.settle()
        #expect(stage.hides == [notes.rawValue])
    }

    @Test func anAppKeptBesideItselfIsKeptAlone() async {
        let stage = Stage()
        stage.frontmost = notes.rawValue
        stage.shown = [notes.rawValue]
        let hider = BackgroundHider(apps: stage.apps, recheckWaits: [])
        hider.hideOthers(keeping: KeptApps(front: notes, beside: notes))
        await stage.settle()
        #expect(stage.kept == [KeptApps(front: notes)])
    }

    @Test func aUserWhoMovedOnKeepsWhatTheySee() async {
        let stage = Stage()
        stage.frontmost = safari.rawValue
        stage.shown = [safari.rawValue]
        let hider = BackgroundHider(apps: stage.apps, recheckWaits: [.milliseconds(300)])
        hider.hideOthers(keeping: KeptApps(front: safari))
        await stage.settle()
        #expect(stage.hides.count == 1)
        stage.frontmost = "com.apple.mail"
        try? await Task.sleep(for: .milliseconds(450))
        #expect(stage.hides.count == 1)
    }
}
