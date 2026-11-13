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

    private func steps(
        _ first: SplitApp.Entrance, _ second: SplitApp.Entrance, secondEntry: SplitArrival.SecondEntry = .focused
    ) -> [SplitSteps.Step] {
        SplitSteps(
            SplitArrival(first: SplitApp(notes, first), second: SplitApp(safari, second), secondEntry: secondEntry)
        ).steps
    }

    private func running(animates: Bool = true, followed: Bool = false) -> SplitApp.Entrance {
        .running(animates: animates, followed: followed)
    }

    private static let entries: [SplitArrival.SecondEntry] = [.focused, .unfocused(raised: true), .unfocused(raised: false)]

    @Test func bothRunningAndFollowedWatchBothAndFloatBothApart() {
        #expect(
            steps(running(followed: true), running(followed: true)) == [
                .open(safari, activates: true, watched: true), .open(notes, activates: true, watched: true),
                .startWatch(notes.bundleID), .startWatch(safari.bundleID),
                .launchAnimation(notes, toward: .left), .launchAnimation(safari, toward: .right),
            ])
    }

    @Test func unfocusedARunningSecondAppIsNeverActivatedAndWhenRaisedTheFirstAppOpensAfterTheRaise() {
        #expect(
            steps(running(followed: true), running(followed: true), secondEntry: .unfocused(raised: true)) == [
                .open(safari, activates: false, watched: true),
                .raiseThenOpen(raised: safari, first: notes, watched: true),
                .startWatch(notes.bundleID), .startWatch(safari.bundleID),
                .launchAnimation(notes, toward: .left), .launchAnimation(safari, toward: .right),
            ])
        #expect(
            steps(running(), running(), secondEntry: .unfocused(raised: false)) == [
                .open(safari, activates: false, watched: false), .open(notes, activates: true, watched: false),
                .launchAnimation(notes, toward: .left), .launchAnimation(safari, toward: .right),
            ])
    }

    @Test(arguments: entries)
    func aLaunchingSecondAppOpensWithoutTheFocusIsNeverRaisedAndBouncesOnTheRight(entry: SplitArrival.SecondEntry) {
        #expect(
            steps(running(), .launching(watch: .bouncing), secondEntry: entry) == [
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
        for entry in Self.entries {
            let steps = steps(first, second, secondEntry: entry)

            #expect(steps.prefix(2).map(\.isOpen) == [true, true])
            #expect(steps.dropFirst(2).allSatisfy { $0.isOpen == false })
            #expect(steps[0].isWatchedOpen == secondWatched)
            #expect(steps[1].opensFirst(notes, watched: firstWatched))
        }
    }

    @Test(arguments: [
        SplitApp.Entrance.running(animates: true, followed: true), .running(animates: false, followed: false),
        .launching(watch: .bouncing), .launching(watch: .unseen), .launching(watch: nil), .alreadyLaunching,
    ])
    func unfocusedOnlyTheFirstAppIsEverActivated(second: SplitApp.Entrance) {
        for raised in [true, false] {
            for first in [running(), .launching(watch: .bouncing), .alreadyLaunching] {
                let activated = steps(first, second, secondEntry: .unfocused(raised: raised)).compactMap {
                    step -> BundleID? in
                    switch step {
                    case .open(let app, true, _): app.bundleID
                    case .raiseThenOpen(_, let first, _): first.bundleID
                    default: nil
                    }
                }
                #expect(activated == [notes.bundleID])
            }
        }
    }
}

private extension SplitSteps.Step {
    var isOpen: Bool {
        switch self {
        case .open, .raiseThenOpen: true
        default: false
        }
    }

    var isWatchedOpen: Bool {
        if case .open(_, _, let watched) = self { watched } else { false }
    }

    func opensFirst(_ app: AppEntry, watched: Bool) -> Bool {
        switch self {
        case .open(let opened, true, let isWatched): opened == app && isWatched == watched
        case .raiseThenOpen(_, let first, let isWatched): first == app && isWatched == watched
        default: false
        }
    }
}
