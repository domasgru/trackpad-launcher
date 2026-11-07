import Foundation
import Testing
import LauncherCore

@Suite struct WindowStackValueTests {
    @Test(arguments: [(0, nil), (1, nil), (2, 2), (3, 3), (4, 4), (5, 4), (7, 4)] as [(Int, Int?)])
    func aStackHasOneIconPerWindowFromTwoUpToFour(windows: Int, icons: Int?) {
        let stack = WindowStack(windows: windows)
        #expect(stack?.icons == icons)
        #expect(stack?.copies == icons.map { $0 - 1 })
    }
}

@Suite struct SwitcherTakeTests {
    private let safari = AppEntry(
        bundleID: BundleID(rawValue: "com.test.safari"), name: "Safari", url: URL(fileURLWithPath: "/Applications/Safari.app"))
    private let mail = AppEntry(
        bundleID: BundleID(rawValue: "com.test.mail"), name: "Mail", url: URL(fileURLWithPath: "/Applications/Mail.app"))

    private func switcher() throws -> Switcher {
        try #require(
            Switcher(
                frontmost: safari, running: [safari, mail], leavingOut: [], serial: 1, trackpad: TrackpadID(rawValue: 1)))
    }

    private func stack(_ windows: Int) throws -> WindowStack { try #require(WindowStack(windows: windows)) }

    private func read(windows count: Int) -> WindowRead {
        .windows(
            AppWindows(
                visible: (0..<count).map { AppWindow(id: WindowID(rawValue: UInt32($0 + 1)), title: "W\($0)") },
                minimised: []))
    }

    @Test func everySlotStartsPending() throws {
        #expect(try switcher().stacks == [.pending, .pending])
    }

    @Test func aReadFillsAPendingSlotOnceAndThenHolds() throws {
        var switcher = try switcher()

        let taken = switcher.take(read(windows: 3), at: 1)
        #expect(taken)
        #expect(try switcher.stacks == [.pending, .stack(stack(3))])

        let again = switcher.take(read(windows: 2), at: 1)
        #expect(again == false)
        #expect(try switcher.stacks[1] == .stack(stack(3)))
    }

    @Test func aSlotOutOfRangeChangesNothing() throws {
        var switcher = try switcher()
        let taken = switcher.take(read(windows: 3), at: 2)
        #expect(taken == false)
        let again = switcher.take(read(windows: 3), at: -1)
        #expect(again == false)
        #expect(switcher.stacks == [.pending, .pending])
    }

    @Test func aSingleWindowAnUnansweredReadAndTheOwnProcessAreAlone() throws {
        var switcher = try switcher()
        let taken = switcher.take(read(windows: 1), at: 0)
        #expect(taken)
        let again = switcher.take(.unanswered, at: 1)
        #expect(again)
        #expect(switcher.stacks == [.alone, .alone])

        var own = try self.switcher()
        let ownTaken = own.take(.ownProcess, at: 0)
        #expect(ownTaken)
        #expect(own.stacks[0] == .alone)
    }

    @Test func noWindowsAtAllIsAlone() throws {
        var switcher = try switcher()
        let taken = switcher.take(read(windows: 0), at: 0)
        #expect(taken)
        #expect(switcher.stacks[0] == .alone)
    }
}

@Suite struct WindowStackLayoutTests {
    private func close(_ values: [Double], _ expected: [Double]) -> Bool {
        values.count == expected.count && zip(values, expected).allSatisfy { abs($0 - $1) < 0.0001 }
    }

    private func stack(_ windows: Int) throws -> WindowStack { try #require(WindowStack(windows: windows)) }

    private func topEdges(_ copies: [WindowStackLayout.Copy]) -> [Double] { copies.map { $0.rise + $0.side / 2 } }

    @Test func copiesAreSmallerAndPeekSixPointsPerLayerAboveTheIcon() throws {
        let layout = WindowStackLayout(row: SwitcherRowLayout(iconCount: 5, displayWidth: 1512))
        let copies = layout.copies(of: try stack(4))

        #expect(close(copies.map(\.side), [73.6, 67.2, 60.8]))
        #expect(close(topEdges(copies), [46, 52, 58]))
    }

    @Test func aShrunkRowShrinksTheStackByTheSameFactor() throws {
        let row = SwitcherRowLayout(iconCount: 10, displayWidth: 540)
        #expect(row.scale == 0.5)
        let copies = WindowStackLayout(row: row).copies(of: try stack(4))

        #expect(close(copies.map(\.side), [36.8, 33.6, 30.4]))
        #expect(close(topEdges(copies), [23, 26, 29]))
    }

    @Test func aTwoIconStackHasTheFirstCopyOnly() throws {
        let layout = WindowStackLayout(row: SwitcherRowLayout(iconCount: 5, displayWidth: 1512))
        #expect(layout.copies(of: try stack(2)).count == 1)
        #expect(close(layout.copies(of: try stack(3)).map(\.side), [73.6, 67.2]))
    }

    @Test func eachCopyStartsRisingFortyMillisecondsAfterTheOneInFrontAndAllAreAtRestWithinHalfASecond() throws {
        let layout = WindowStackLayout(row: SwitcherRowLayout(iconCount: 5, displayWidth: 1512))
        let delays = try layout.copies(of: stack(4)).map(\.delay)
        let lastDelay = try #require(delays.last)

        #expect(close(delays, [0, 0.04, 0.08]))
        #expect(WindowStackLayout.riseDuration == 0.3)
        #expect(close([lastDelay + WindowStackLayout.riseDuration], [0.38]))
        #expect(lastDelay + WindowStackLayout.riseDuration < 0.5)
    }

    @Test func theRiseIsASoftEaseOut() {
        let curve = WindowStackLayout.riseCurve
        #expect(curve.1 > curve.0)
        #expect(curve.3 == 1)
    }
}
