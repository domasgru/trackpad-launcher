import AppKit
import LauncherCore
import Testing

@testable import LauncherPlatform

@Suite struct FocusKeeperRuleTests {
    private let kept = BundleID(rawValue: "com.kept"), other = BundleID(rawValue: "com.other")

    @Test func theOtherAppTakingTheFocusRefocusesTheKeptOneKeptRepeatsAndAThirdEndsTheKeep() {
        #expect(FocusKeeper.response(toActivationOf: "com.other", keeping: kept, against: other) == .refocus)
        #expect(FocusKeeper.response(toActivationOf: "com.kept", keeping: kept, against: other) == .carryOn)
        #expect(FocusKeeper.response(toActivationOf: "com.third", keeping: kept, against: other) == .end)
        #expect(FocusKeeper.response(toActivationOf: nil, keeping: kept, against: other) == .end)
    }
}

/// Activations posted to a center of the test's own, naming apps that always run: Finder is the app kept in front,
/// the Dock the split's other app, SystemUIServer a third app. Nothing is activated for real.
@MainActor @Suite struct FocusKeeperTests {
    private let center = NotificationCenter()
    private let finder: NSRunningApplication
    private let dock: NSRunningApplication
    private let third: NSRunningApplication
    private let kept = AppEntry(
        bundleID: BundleID(rawValue: "com.apple.finder"), name: "Finder",
        url: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"))
    private let dockID = BundleID(rawValue: "com.apple.dock")

    init() throws {
        func app(_ id: String) throws -> NSRunningApplication {
            try #require(NSRunningApplication.runningApplications(withBundleIdentifier: id).first)
        }
        finder = try app("com.apple.finder")
        dock = try app("com.apple.dock")
        third = try app("com.apple.systemuiserver")
    }

    private func activate(_ app: NSRunningApplication) {
        center.post(
            name: NSWorkspace.didActivateApplicationNotification, object: nil,
            userInfo: [NSWorkspace.applicationUserInfoKey: app])
    }

    @Test func whileItKeepsEachActivationOfTheOtherAppBringsTheKeptAppBack() {
        var refocused: [String] = []
        let keeper = FocusKeeper(center: center, duration: .seconds(60)) { refocused.append($0.name) }
        keeper.keep(kept, against: dockID)

        activate(finder)
        #expect(refocused.isEmpty)
        activate(dock)
        activate(finder)
        activate(dock)
        #expect(refocused == ["Finder", "Finder"])
        keeper.end()
    }

    @Test func aThirdAppsActivationEndsTheKeep() {
        var refocused = 0
        let keeper = FocusKeeper(center: center, duration: .seconds(60)) { _ in refocused += 1 }
        keeper.keep(kept, against: dockID)
        activate(third)
        activate(dock)
        #expect(refocused == 0, "the user moved on")
    }

    @Test func aNewKeepOrEndReplacesThePendingOne() {
        var refocused: [String] = []
        let keeper = FocusKeeper(center: center, duration: .seconds(60)) { refocused.append($0.name) }
        keeper.keep(kept, against: BundleID(rawValue: "com.apple.systemuiserver"))
        keeper.keep(kept, against: dockID)
        activate(third)
        #expect(refocused.isEmpty, "the first keep is gone, and the third app ended the second")

        keeper.keep(kept, against: dockID)
        keeper.end()
        activate(dock)
        #expect(refocused.isEmpty)
    }

    @Test(.timeLimit(.minutes(1))) func theKeepEndsAfterItsDurationOnItsOwn() async {
        var refocused = 0
        var keeper: FocusKeeper?
        let ended: Void? = await awaiting("the keep's end") { done in
            keeper = FocusKeeper(center: center, duration: .milliseconds(50), ended: { done(()) }) { _ in refocused += 1 }
            keeper?.keep(kept, against: dockID)
        }
        #expect(ended != nil)
        activate(dock)
        #expect(refocused == 0, "the keep is over")
    }
}

@Suite struct SplitPointerSideTests {
    @Test func theLineBetweenTheHalvesDecidesTheSideAndTheLeftHalfTakesTheOddPoint() {
        let visible = CGRect(x: 0, y: 0, width: 1511, height: 949)
        #expect(SplitHalves.side(of: 0, visible: visible) == .left)
        #expect(SplitHalves.side(of: 755.9, visible: visible) == .left)
        #expect(SplitHalves.side(of: 756, visible: visible) == .right)
        #expect(SplitHalves.side(of: 1510, visible: visible) == .right)

        let second = CGRect(x: 1512, y: 0, width: 1920, height: 1055)
        #expect(SplitHalves.side(of: 2471, visible: second) == .left)
        #expect(SplitHalves.side(of: 2472, visible: second) == .right)
    }
}
