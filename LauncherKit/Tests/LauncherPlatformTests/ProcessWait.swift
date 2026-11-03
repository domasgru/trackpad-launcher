import Foundation

extension Process {
    /// Starts the process; the returned closure blocks the calling thread until it has exited. Unlike
    /// `waitUntilExit`, it never runs the thread's run loop, so a main-actor test waiting here cannot be re-entered by
    /// other main-actor jobs.
    func start() throws -> @Sendable () -> Void {
        let exited = DispatchSemaphore(value: 0)
        terminationHandler = { _ in exited.signal() }
        try run()
        return {
            exited.wait()
            exited.signal()
        }
    }
}
