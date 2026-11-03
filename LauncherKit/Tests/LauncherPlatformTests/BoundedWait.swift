import Foundation
import Testing

/// Awaits a value that `start` arranges to be delivered once, through the closure it is handed. When none arrives within
/// `limit`, records an issue naming `what` and returns nil: a test fails rather than waits forever. `start` runs at
/// once, on the caller's isolation; the closure it receives may be called from anywhere, any number of times.
nonisolated(nonsending) func awaiting<T: Sendable>(
    _ what: String, within limit: Duration = .seconds(30), sourceLocation: SourceLocation = #_sourceLocation,
    start: (@escaping @Sendable (T) -> Void) -> Void
) async -> T? {
    await withCheckedContinuation { (continuation: CheckedContinuation<T?, Never>) in
        let once = ResumeOnce(continuation)
        start { value in once.resume(with: value) }
        once.bound(Task {
            try? await Task.sleep(for: limit)
            if once.resume(with: nil) {
                Issue.record("Timed out after \(limit) waiting for \(what)", sourceLocation: sourceLocation)
            }
        })
    }
}

private final class ResumeOnce<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T?, Never>?
    private var timer: Task<Void, Never>?
    private var finished = false

    init(_ continuation: CheckedContinuation<T?, Never>) { self.continuation = continuation }

    /// True when this call was the one that resumed the continuation.
    @discardableResult
    func resume(with value: T?) -> Bool {
        lock.lock()
        let taken = continuation
        continuation = nil
        finished = true
        let timer = timer
        lock.unlock()
        taken?.resume(returning: value)
        timer?.cancel()
        return taken != nil
    }

    /// Cancels `timer` as soon as the wait has ended, at once when it already has.
    func bound(_ timer: Task<Void, Never>) {
        lock.lock()
        let done = finished
        if !done { self.timer = timer }
        lock.unlock()
        if done { timer.cancel() }
    }
}
