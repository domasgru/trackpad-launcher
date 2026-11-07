import Dispatch
import LauncherCore

/// One-shot `DispatchSource` timer on the main queue, 1 s leeway, on the clock that stops during sleep. Cancel and fire
/// are both on main, so a cancelled wait cannot fire.
@MainActor public final class SystemIdleClock: IdleClock {
    private var source: (any DispatchSourceTimer)?
    private var passed: (@MainActor () -> Void)?
    /// A handler already queued on main when `cancel` runs finds a newer number and does nothing.
    private var generation = 0

    public init() {}

    public func wait(_ duration: Duration, then passed: @escaping @MainActor () -> Void) {
        cancel()
        let number = generation
        self.passed = passed
        let components = duration.components
        let seconds = Double(components.seconds) + Double(components.attoseconds) / 1e18
        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now() + seconds, leeway: .seconds(1))
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.generation == number, let passed = self.passed else { return }
                self.cancel()
                passed()
            }
        }
        self.source = source
        source.resume()
    }

    public func cancel() {
        generation += 1
        source?.cancel()
        source = nil
        passed = nil
    }
}
