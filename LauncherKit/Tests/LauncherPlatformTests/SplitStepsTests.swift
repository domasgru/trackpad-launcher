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

    /// Notes is the first app, on the left; Safari the second, on the right.
    private func steps(
        _ first: SplitApp.Entrance, _ second: SplitApp.Entrance, focus: SplitSide = .left,
        secondEntry: SplitArrival.SecondEntry = .focused
    ) -> [SplitSteps.Step] {
        SplitSteps(
            SplitArrival(
                first: SplitApp(notes, first), second: SplitApp(safari, second), focus: focus, secondEntry: secondEntry)
        ).steps
    }

    private func running(animates: Bool = true, followed: Bool = false) -> SplitApp.Entrance {
        .running(animates: animates, followed: followed)
    }

    private static let entries: [SplitArrival.SecondEntry] = [.focused, .unfocused]

    @Test func bothRunningAndFollowedWatchBothAndFloatBothApart() {
        #expect(
            steps(running(followed: true), running(followed: true)) == [
                .open(safari, activates: true, watched: true), .open(notes, activates: true, watched: true),
                .keepFocus(notes, against: safari.bundleID),
                .startWatch(notes.bundleID), .startWatch(safari.bundleID),
                .launchAnimation(notes, toward: .left), .launchAnimation(safari, toward: .right),
            ])
    }

    @Test func withThePointerOnTheRightTheSecondAppIsOpenedLastAndKeptInFrontAndTheSidesStay() {
        #expect(
            steps(running(), running(), focus: .right) == [
                .open(notes, activates: true, watched: false), .open(safari, activates: true, watched: false),
                .keepFocus(safari, against: notes.bundleID),
                .launchAnimation(notes, toward: .left), .launchAnimation(safari, toward: .right),
            ])
        #expect(
            steps(running(followed: true), .launching(watch: .bouncing), focus: .right, secondEntry: .unfocused) == [
                .reveal(notes, watched: true), .open(safari, activates: true, watched: true),
                .keepFocus(safari, against: notes.bundleID),
                .startWatch(notes.bundleID), .startWatch(safari.bundleID),
                .bounce(safari, toward: .right), .launchAnimation(notes, toward: .left),
            ])
    }

    @Test func unfocusedARunningOtherAppIsRevealedRatherThanOpened() {
        #expect(
            steps(running(followed: true), running(followed: true), secondEntry: .unfocused) == [
                .reveal(safari, watched: true), .open(notes, activates: true, watched: true),
                .keepFocus(notes, against: safari.bundleID),
                .startWatch(notes.bundleID), .startWatch(safari.bundleID),
                .launchAnimation(notes, toward: .left), .launchAnimation(safari, toward: .right),
            ])
    }

    @Test(arguments: entries)
    func aLaunchingOtherAppOpensWithoutTheFocusAndBouncesOnItsSide(entry: SplitArrival.SecondEntry) {
        #expect(
            steps(running(), .launching(watch: .bouncing), secondEntry: entry) == [
                .open(safari, activates: false, watched: true), .open(notes, activates: true, watched: false),
                .keepFocus(notes, against: safari.bundleID),
                .startWatch(safari.bundleID), .bounce(safari, toward: .right), .launchAnimation(notes, toward: .left),
            ])
    }

    @Test func twoBouncesStartFirstAppFirstAfterBothWatches() {
        #expect(
            steps(.launching(watch: .bouncing), .launching(watch: .bouncing)) == [
                .open(safari, activates: false, watched: true), .open(notes, activates: true, watched: true),
                .keepFocus(notes, against: safari.bundleID),
                .startWatch(notes.bundleID), .startWatch(safari.bundleID),
                .bounce(notes, toward: .left), .bounce(safari, toward: .right),
            ])
    }

    @Test func unwatchedLaunchesAreOnlyOpenedAndAnAppThatDoesNotAnimateIsNotFloated() {
        #expect(
            steps(running(animates: false), .launching(watch: nil)) == [
                .open(safari, activates: false, watched: false), .open(notes, activates: true, watched: false),
                .keepFocus(notes, against: safari.bundleID),
            ])
    }

    @Test func anAlreadyLaunchingOtherAppIsOnlyOpenedWithoutTheFocus() {
        #expect(
            steps(running(), .alreadyLaunching) == [
                .open(safari, activates: false, watched: false), .open(notes, activates: true, watched: false),
                .keepFocus(notes, against: safari.bundleID), .launchAnimation(notes, toward: .left),
            ])
    }

    @Test(arguments: [SplitSide.left, .right])
    func bothAppsComeToFrontBeforeAnythingElseTheFocusedOneLastAndKept(focus: SplitSide) {
        let entrances: [SplitApp.Entrance] = [
            running(), running(followed: true), .launching(watch: .bouncing), .launching(watch: nil), .alreadyLaunching,
        ]
        let (focused, other) = focus == .left ? (notes, safari) : (safari, notes)
        for first in entrances {
            for second in entrances {
                for entry in Self.entries {
                    let steps = steps(first, second, focus: focus, secondEntry: entry)
                    #expect(steps[0].bringsToFront(other))
                    #expect(steps[1].opensActivating(focused))
                    #expect(steps[2] == .keepFocus(focused, against: other.bundleID))
                    #expect(steps.dropFirst(3).allSatisfy { !$0.bringsToFront(notes) && !$0.bringsToFront(safari) })
                    if entry == .unfocused {
                        #expect(!steps[0].opensActivating(other), "only the focused app is activated")
                    }
                }
            }
        }
    }
}

private extension SplitSteps.Step {
    func bringsToFront(_ app: AppEntry) -> Bool {
        switch self {
        case .open(let opened, _, _), .reveal(let opened, _): opened == app
        default: false
        }
    }

    func opensActivating(_ app: AppEntry) -> Bool {
        if case .open(let opened, true, _) = self { opened == app } else { false }
    }
}
