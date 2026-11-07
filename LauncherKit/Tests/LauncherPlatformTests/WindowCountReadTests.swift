import AppKit
import ApplicationServices
import LauncherCore
import Synchronization
import Testing

@testable import LauncherPlatform

/// The answers `readEach` gave, and who is waiting for how many of them.
private final class AnswerLog: Sendable {
    struct Answer: Sendable {
        let slot: Int
        let read: WindowRead
        let onMainThread: Bool
    }

    typealias Fire = @Sendable ([Answer]) -> Void

    private struct State {
        var answers: [Answer] = []
        var waiting: [(count: Int, fire: Fire)] = []
    }

    private let state = Mutex(State())

    var answers: [Answer] { state.withLock { $0.answers } }

    func add(_ answer: Answer) {
        let due = state.withLock { state -> (fires: [Fire], answers: [Answer]) in
            state.answers.append(answer)
            let count = state.answers.count
            let due = state.waiting.filter { $0.count <= count }.map(\.fire)
            state.waiting.removeAll { $0.count <= count }
            return (due, state.answers)
        }
        for fire in due.fires { fire(due.answers) }
    }

    /// Calls `fire` once with all answers when at least `count` have come, at once if they already have.
    func notify(at count: Int, _ fire: @escaping Fire) {
        let ready = state.withLock { state -> [Answer]? in
            guard state.answers.count < count else { return state.answers }
            state.waiting.append((count, fire))
            return nil
        }
        if let ready { fire(ready) }
    }
}

@MainActor @Suite(.serialized) struct WindowCountReadTests {
    private static let finder = AppEntry(
        bundleID: BundleID(rawValue: "com.apple.finder"), name: "Finder",
        url: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"))

    @Test func everySlotIsAnsweredOnceOnTheMainActorAfterTheCallReturns() async {
        let reader = AppWindowReader()
        let notRunning = AppEntry(
            bundleID: BundleID(rawValue: "com.test.not-running"), name: "Nothing",
            url: URL(fileURLWithPath: "/Applications/Nothing.app"))
        let log = AnswerLog()
        var answeredDuringCall = true

        let answers: [AnswerLog.Answer]? = await awaiting("both slots to be answered") { done in
            log.notify(at: 2, done)
            reader.readEach([notRunning, Self.finder], within: .milliseconds(200)) { slot, read in
                log.add(.init(slot: slot, read: read, onMainThread: Thread.isMainThread))
            }
            answeredDuringCall = !log.answers.isEmpty
        }

        #expect(!answeredDuringCall)
        guard let answers else { return }
        #expect(answers.count == 2)
        #expect(answers.allSatisfy { $0.onMainThread })
        #expect(answers.first { $0.slot == 0 }?.read == .unanswered)
        let finderRead = answers.first { $0.slot == 1 }?.read
        if AXIsProcessTrusted() {
            guard case .windows? = finderRead else {
                Issue.record("Finder answers its windows when trusted, got \(String(describing: finderRead))")
                return
            }
        } else {
            #expect(finderRead == .unanswered)
        }
    }

    @Test func aHeldReadDelaysNoOtherAppAndAllReadsShareOneBudgetOffTheMainThread() async {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        var apps: [AppEntry] = []
        var firstPID: pid_t = 0
        for running in NSWorkspace.shared.runningApplications
        where !running.isTerminated && running.processIdentifier != ownPID {
            guard let entry = RunningApp.entry(for: running), !apps.contains(where: { $0.url == entry.url }) else {
                continue
            }
            if apps.isEmpty { firstPID = running.processIdentifier }
            apps.append(entry)
            if apps.count == 3 { break }
        }
        guard apps.count == 3 else {
            Issue.record("Needs three running apps with bundles, found \(apps.count)")
            return
        }
        let release = DispatchSemaphore(value: 0)
        let heldPID = firstPID
        let seen = Mutex<[(pid: pid_t, onMainThread: Bool, budget: ReadBudget)]>([])
        let log = AnswerLog()
        let reader = AppWindowReader()
        let readOne: @Sendable (AppWindowReader.Target, ReadBudget) -> WindowRead = { target, budget in
            seen.withLock { $0.append((target.pid, Thread.isMainThread, budget)) }
            if target.pid == heldPID {
                _ = release.wait(timeout: .now() + 30)
            }
            return .windows(AppWindows(visible: [], minimised: []))
        }

        let others: [AnswerLog.Answer]? = await awaiting("the two unheld reads to be answered") { done in
            log.notify(at: 2, done)
            reader.readEach(apps, within: .milliseconds(200), readOne: readOne) { slot, read in
                log.add(.init(slot: slot, read: read, onMainThread: Thread.isMainThread))
            }
        }
        #expect(others?.map(\.slot).sorted() == [1, 2])
        #expect(others?.allSatisfy { $0.onMainThread } == true)

        let all: [AnswerLog.Answer]? = await awaiting("the held read to be answered") { done in
            log.notify(at: 3, done)
            release.signal()
        }
        #expect(all?.map(\.slot).sorted() == [0, 1, 2])
        #expect(all?.allSatisfy { $0.onMainThread } == true)
        let calls = seen.withLock { $0 }
        #expect(calls.count == 3)
        #expect(calls.allSatisfy { !$0.onMainThread })
        #expect(calls.dropFirst().allSatisfy { $0.budget == calls[0].budget })
    }
}
