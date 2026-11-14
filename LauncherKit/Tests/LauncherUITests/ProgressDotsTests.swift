import AppKit
import LauncherCore
import SwiftUI
import Testing
@testable import LauncherUI

@MainActor @Suite(.serialized) struct ProgressDotsTests {
    private func expectStepping(_ bench: ProgressDotsBench, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let steps = try #require(bench.steps, sourceLocation: sourceLocation)
        let slot = Double(bench.slot)
        #expect(bench.view.maskLayer.animationKeys() == [ProgressDotsView.animationKey], sourceLocation: sourceLocation)
        #expect(steps.keyPath == "bounds.size.width", sourceLocation: sourceLocation)
        let values = steps.values?.compactMap { ($0 as? NSNumber)?.doubleValue } ?? []
        #expect(values.count == 4, sourceLocation: sourceLocation)
        for (value, slots) in zip(values, 0...3) {
            #expect(abs(value - Double(slots) * slot) < 1e-6, sourceLocation: sourceLocation)
        }
        #expect(steps.calculationMode == .discrete, sourceLocation: sourceLocation)
        #expect(steps.keyTimes?.map(\.doubleValue) == [0, 0.25, 0.5, 0.75, 1], sourceLocation: sourceLocation)
        #expect(steps.duration == 1, sourceLocation: sourceLocation)
        #expect(steps.repeatCount == .infinity, sourceLocation: sourceLocation)
        #expect(steps.isRemovedOnCompletion == false, sourceLocation: sourceLocation)
    }

    private func expectStill(_ bench: ProgressDotsBench, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(!bench.anyAnimation, sourceLocation: sourceLocation)
        #expect(
            abs(bench.view.maskLayer.bounds.width - bench.ellipsisWidth) < 1e-6, sourceLocation: sourceLocation)
    }

    @Test func theMaskStepsThroughFourHeldWidthsInOneSecondForever() throws {
        try expectStepping(ProgressDotsBench())
    }

    @Test func theMaskShowsNoneOneTwoThenThreeDotsEachQuarterSecondAndLoops() throws {
        let bench = ProgressDotsBench()
        let times = [0.125, 0.375, 0.625, 0.875, 1.125, 1.375, 1.625, 1.875]
        let slots = try times.map { try bench.presentedSlots(at: $0) }
        for (got, want) in zip(slots, [0, 1, 2, 3, 0, 1, 2, 3]) {
            #expect(abs(got - Double(want)) < 1e-6, "\(slots)")
        }
    }

    @Test func eachStepSwitchesAtItsQuarterSecondBoundary() throws {
        let bench = ProgressDotsBench()
        let samples: [(Double, Double)] = [
            (0.24, 0), (0.26, 1), (0.49, 1), (0.51, 2), (0.74, 2), (0.76, 3), (0.99, 3), (1.01, 0),
        ]
        for (time, want) in samples {
            let got = try bench.presentedSlots(at: time)
            #expect(abs(got - want) < 1e-6, "at \(time) s: \(got) slots, expected \(want)")
        }
    }

    @Test func theBoxIsAsWideAsAnEllipsisAndNothingMovesWhileTheDotsStep() throws {
        let bench = ProgressDotsBench()
        let frame = bench.view.frame
        #expect(abs(bench.view.intrinsicContentSize.width - bench.ellipsisWidth) < 1e-6)
        #expect(abs(bench.slot * 3 - bench.ellipsisWidth) < 1e-9)
        for time in [0.125, 0.375, 0.625, 0.875, 1.125, 1.375, 1.625, 1.875] {
            _ = try bench.presentedSlots(at: time)
            #expect(bench.view.frame == frame)
            let presented = try #require(bench.view.maskLayer.presentation())
            #expect(presented.frame.minX == 0)
            #expect(bench.view.maskLayer.position.x == 0)
        }
    }

    @Test func reduceMotionOnFromTheStartShowsThreeStillDots() {
        expectStill(ProgressDotsBench(reduceMotion: true))
    }

    @Test func theDotsFollowReduceMotionLive() throws {
        let bench = ProgressDotsBench()
        bench.setReduceMotion(true)
        bench.postDisplayOptionsChange()
        expectStill(bench)

        bench.setReduceMotion(false)
        bench.postDisplayOptionsChange()
        try expectStepping(bench)
    }

    @Test func theDotsStepOnlyWhileTheWindowIsOnScreenAndTheViewIsInIt() throws {
        let bench = ProgressDotsBench()
        bench.setOnScreen(false)
        bench.postOcclusionChange()
        expectStill(bench)

        bench.setOnScreen(true)
        bench.postOcclusionChange()
        try expectStepping(bench)

        bench.leave()
        expectStill(bench)

        bench.enter()
        try expectStepping(bench)
    }

    @Test func aWindowOffScreenWhenTheDotsArriveStartsNothing() {
        expectStill(ProgressDotsBench(onScreen: false))
    }

    @Test func repeatedNotificationsLeaveTheSameAnimationInPlace() throws {
        let bench = ProgressDotsBench()
        let steps = try #require(bench.steps)

        bench.postDisplayOptionsChange()
        bench.postOcclusionChange()
        bench.postOcclusionChange()

        #expect(bench.steps === steps)
        #expect(bench.view.maskLayer.animationKeys() == [ProgressDotsView.animationKey])
    }

    @Test func theDotsAreNotAnAccessibilityElementAndHaveNoChildren() {
        let view = ProgressDotsBench().view
        #expect(!view.isAccessibilityElement())
        #expect((view.accessibilityChildren() ?? []).isEmpty)
    }
}

@MainActor @Suite struct ButtonTitleViewTests {
    private func dotsViews(in title: ButtonTitle) -> Int {
        _ = NSApplication.shared
        let host = NSHostingView(rootView: ButtonTitleView(title: title))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 100), styleMask: .borderless, backing: .buffered,
            defer: true)
        window.isReleasedWhenClosed = false
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        func count(_ view: NSView) -> Int {
            (view is ProgressDotsView ? 1 : 0) + view.subviews.map(count).reduce(0, +)
        }
        return count(host)
    }

    @Test(arguments: [ButtonTitle.plain("Check for updates…"), .plain("Update now")])
    func aPlainTitleHoldsNoDots(title: ButtonTitle) {
        #expect(dotsViews(in: title) == 0)
    }

    @Test(arguments: [ButtonTitle.progress(.checking), .progress(.updating)])
    func aProgressTitleHoldsExactlyOneDotsView(title: ButtonTitle) {
        #expect(dotsViews(in: title) == 1)
    }
}
