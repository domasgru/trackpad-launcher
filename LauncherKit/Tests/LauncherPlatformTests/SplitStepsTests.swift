import Foundation
import LauncherCore
import Testing

@testable import LauncherPlatform

@Suite struct SplitStepsTests {
    private let notes = AppEntry(
        bundleID: BundleID(rawValue: "com.apple.Notes"), name: "Notes", url: URL(fileURLWithPath: "/Applications/Notes.app"))
    private let safari = AppEntry(
        bundleID: BundleID(rawValue: "com.apple.Safari"), name: "Safari",
        url: URL(fileURLWithPath: "/Applications/Safari.app"))

    private func steps(_ first: SplitApp.Entrance, _ second: SplitApp.Entrance) -> [SplitSteps.Step] {
        SplitSteps(SplitArrival(first: SplitApp(notes, first), second: SplitApp(safari, second))).steps
    }

    private func running(animates: Bool = true, followed: Bool = false) -> SplitApp.Entrance {
        .running(animates: animates, followed: followed)
    }

    @Test func bothRunningAndFollowedWatchBothAndFloatBothApart() {
        #expect(
            steps(running(followed: true), running(followed: true)) == [
                .open(safari, activates: true, watched: true), .open(notes, activates: true, watched: true),
                .startWatch(notes.bundleID), .startWatch(safari.bundleID),
                .launchAnimation(notes, toward: .left), .launchAnimation(safari, toward: .right),
            ])
    }

    @Test func aLaunchingSecondAppOpensWithoutTheFocusAndBouncesOnTheRight() {
        #expect(
            steps(running(), .launching(watch: .bouncing)) == [
                .open(safari, activates: false, watched: true), .open(notes, activates: true, watched: false),
                .startWatch(safari.bundleID), .bounce(safari, toward: .right), .launchAnimation(notes, toward: .left),
            ])
    }

    @Test func aLaunchingFirstAppBouncesOnTheLeftAndTheRunningSecondAppIsActivated() {
        #expect(
            steps(.launching(watch: .bouncing), running()) == [
                .open(safari, activates: true, watched: false), .open(notes, activates: true, watched: true),
                .startWatch(notes.bundleID), .bounce(notes, toward: .left), .launchAnimation(safari, toward: .right),
            ])
    }

    @Test func twoBouncesStartFirstAppFirstAfterBothWatches() {
        #expect(
            steps(.launching(watch: .bouncing), .launching(watch: .bouncing)) == [
                .open(safari, activates: false, watched: true), .open(notes, activates: true, watched: true),
                .startWatch(notes.bundleID), .startWatch(safari.bundleID),
                .bounce(notes, toward: .left), .bounce(safari, toward: .right),
            ])
    }

    @Test func unseenWatchesBounceNothing() {
        #expect(
            steps(.launching(watch: .unseen), .launching(watch: .unseen)) == [
                .open(safari, activates: false, watched: true), .open(notes, activates: true, watched: true),
                .startWatch(notes.bundleID), .startWatch(safari.bundleID),
            ])
    }

    @Test func unwatchedLaunchesAreOnlyOpenedAndAnAppThatDoesNotAnimateIsNotFloated() {
        #expect(
            steps(running(animates: false), .launching(watch: nil)) == [
                .open(safari, activates: false, watched: false), .open(notes, activates: true, watched: false),
            ])
    }

    @Test func anAlreadyLaunchingAppIsOnlyOpenedWithoutTheFocus() {
        #expect(
            steps(running(), .alreadyLaunching) == [
                .open(safari, activates: false, watched: false), .open(notes, activates: true, watched: false),
                .launchAnimation(notes, toward: .left),
            ])
    }

    @Test(arguments: [
        (SplitApp.Entrance.launching(watch: .bouncing), SplitApp.Entrance.launching(watch: .bouncing), true, true),
        (.running(animates: true, followed: true), .launching(watch: .unseen), true, true),
        (.alreadyLaunching, .running(animates: true, followed: false), false, false),
    ])
    func bothOpensComeBeforeAnythingElseAndTheFirstAppsIsLast(
        first: SplitApp.Entrance, second: SplitApp.Entrance, firstWatched: Bool, secondWatched: Bool
    ) {
        let steps = steps(first, second)

        #expect(steps.prefix(2).map(\.isOpen) == [true, true])
        #expect(steps.dropFirst(2).allSatisfy { $0.isOpen == false })
        #expect(steps[0].isWatchedOpen == secondWatched)
        #expect(steps[1] == .open(notes, activates: true, watched: firstWatched))
    }
}

private extension SplitSteps.Step {
    var isOpen: Bool {
        if case .open = self { true } else { false }
    }

    var isWatchedOpen: Bool {
        if case .open(_, _, let watched) = self { watched } else { false }
    }
}
