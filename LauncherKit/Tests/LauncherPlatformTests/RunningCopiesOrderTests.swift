import Foundation
import Testing

@testable import LauncherPlatform

@MainActor @Suite struct RunningCopiesOrderTests {
    typealias Copy = (launched: Date?, pid: pid_t)
    static let early = Date(timeIntervalSince1970: 1_000)
    static let late = Date(timeIntervalSince1970: 2_000)
    static let copies: [Copy] = [(early, 10), (early, 20), (late, 5), (late, 30), (nil, 7), (nil, 40)]

    @Test func theEarlierLaunchDateComesFirst() {
        #expect(SystemRunningCopies.started((Self.early, 99), before: (Self.late, 1)))
        #expect(!SystemRunningCopies.started((Self.late, 1), before: (Self.early, 99)))
    }

    @Test func aMissingDateComesAfterAnyDate() {
        #expect(SystemRunningCopies.started((Self.late, 99), before: (nil, 1)))
        #expect(!SystemRunningCopies.started((nil, 1), before: (Self.late, 99)))
    }

    @Test func equalOrMissingDatesFallToTheLowerPid() {
        #expect(SystemRunningCopies.started((Self.early, 10), before: (Self.early, 20)))
        #expect(SystemRunningCopies.started((nil, 7), before: (nil, 40)))
        #expect(!SystemRunningCopies.started((nil, 40), before: (nil, 7)))
    }

    @Test func noCopyComesBeforeItself() {
        for copy in Self.copies { #expect(!SystemRunningCopies.started(copy, before: copy)) }
    }

    @Test func ofTwoDistinctCopiesExactlyOneComesFirst() {
        for (i, a) in Self.copies.enumerated() {
            for b in Self.copies[(i + 1)...] {
                #expect(SystemRunningCopies.started(a, before: b) != SystemRunningCopies.started(b, before: a))
            }
        }
    }
}
