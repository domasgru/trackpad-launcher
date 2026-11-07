import LauncherCore
import Testing

@testable import LauncherPlatform

@Suite struct ReadBudgetTests {
    private let budget = ReadBudget(from: Uptime(seconds: 10), within: .milliseconds(200))

    @Test func theTimeoutIsWhatIsLeftOfTheDeadline() throws {
        let full = try #require(budget.timeout(at: Uptime(seconds: 10)))
        let late = try #require(budget.timeout(at: Uptime(seconds: 10.15)))

        #expect(abs(full - 0.2) < 0.0001)
        #expect(abs(late - 0.05) < 0.0001)
    }

    @Test(arguments: [10.2, 10.25, 11])
    func atOrPastTheDeadlineThereIsNoTimeoutSoNoCallIsMade(_ seconds: Double) {
        #expect(budget.timeout(at: Uptime(seconds: seconds)) == nil)
    }

    @Test(arguments: [10.0, 10.15, 10.1999, 10.2])
    func theTimeoutIsNeverZeroOrNegative(_ seconds: Double) {
        if let timeout = budget.timeout(at: Uptime(seconds: seconds)) { #expect(timeout > 0) }
    }

    @Test(arguments: [(10.15, true), (10.2, true), (10.2001, false)])
    func aReadAnswersInTimeUpToTheDeadlineItself(_ end: (seconds: Double, admitted: Bool)) {
        #expect(budget.admits(endedAt: Uptime(seconds: end.seconds)) == end.admitted)
    }
}
