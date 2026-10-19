import AppKit
import CoreGraphics
import LauncherCore
import Testing

@testable import LauncherPlatform

/// What `onLaunchProgress` delivered, with when. It ends the bounce re-entrantly on the terminal reports a row names,
/// as the model does, and otherwise leaves it. It holds no policy.
@MainActor final class ProgressLog {
    struct Entry {
        let at: ContinuousClock.Instant
        let app: BundleID
        let progress: LaunchProgress
    }

    private(set) var entries: [Entry] = []
    var progresses: [LaunchProgress] { entries.map(\.progress) }
    /// The ending the driver gives the bounce when this report arrives.
    var endings: [LaunchProgress: LaunchBounceEnding] = [:]
    /// The limit the driver sets when the app finished launching.
    var limitOnFinish: Duration?
    private var waiters: [Int: (condition: (ProgressLog) -> Bool, continuation: CheckedContinuation<Bool, Never>)] = [:]
    private var waiterCount = 0

    init(_ actions: WorkspaceActions) {
        actions.onLaunchProgress = { [unowned self, unowned actions] app, progress in
            entries.append(Entry(at: .now, app: app, progress: progress))
            if progress == .finishedLaunching, let limit = limitOnFinish {
                actions.limitLaunchBounce(of: app, to: limit)
            }
            if let ending = endings[progress] { actions.endLaunchBounce(of: app, with: ending) }
            for (id, waiter) in waiters where waiter.condition(self) {
                waiters[id] = nil
                waiter.continuation.resume(returning: true)
            }
        }
    }

    /// True once `count` reports arrived, false when `bound` passes first.
    func wait(forCount count: Int, within bound: Duration) async -> Bool {
        if entries.count >= count { return true }
        waiterCount += 1
        let id = waiterCount
        return await withCheckedContinuation { continuation in
            waiters[id] = ({ $0.entries.count >= count }, continuation)
            Task {
                try? await Task.sleep(for: bound)
                if let waiter = waiters.removeValue(forKey: id) { waiter.continuation.resume(returning: false) }
            }
        }
    }
}

/// A real `WorkspaceActions` whose pointer and displays the test sets.
@MainActor final class BounceBench {
    let actions: WorkspaceActions
    let log: ProgressLog
    private let pointer: Pointer

    private final class Pointer {
        var location = CGPoint(x: 700, y: 400)
        var displays: [LaunchDisplay]? = nil
    }

    init() {
        let pointer = Pointer()
        self.pointer = pointer
        actions = WorkspaceActions(
            screen: {
                ScreenRead(
                    pointer: pointer.location,
                    displays: pointer.displays
                        ?? NSScreen.screens.map { LaunchDisplay(frame: $0.frame, scale: $0.backingScaleFactor) })
            }, promptsUser: false)
        log = ProgressLog(actions)
    }

    var tip: CGPoint {
        get { pointer.location }
        set { pointer.location = newValue }
    }

    /// Replaces the system's displays with these, which need not exist.
    func setDisplays(_ displays: [LaunchDisplay]) { pointer.displays = displays }

    /// Reads as no display at all.
    func disconnectDisplays() { pointer.displays = [] }

    /// The display holding `point`, as the system's screens answer.
    static func display(holding point: CGPoint) -> CGRect {
        (NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.screens[0]).frame
    }

    func entry(_ bundle: ProbeBundles.Bundle) -> AppEntry {
        AppEntry(bundleID: BundleID(rawValue: bundle.id), name: "Probe", url: bundle.url)
    }

    /// Ends every bounce a row may have left playing.
    func tearDown(_ bundles: [ProbeBundles.Bundle]) {
        for bundle in bundles { actions.endLaunchBounce(of: BundleID(rawValue: bundle.id), with: .quietFade) }
    }
}

/// Our own windows at the panels' level, from the window server's list: frames in AppKit's global coordinates (y up).
@MainActor enum OwnWindows {
    static func panels() -> [CGRect] {
        let infos = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return infos.compactMap { info in
            guard info[kCGWindowOwnerPID as String] as? Int32 == getpid(),
                  info[kCGWindowLayer as String] as? Int == 1000,
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds)
            else { return nil }
            return CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
        }
    }

    /// Samples the list every 10 ms until `found` accepts it or `bound` passes; the last sample otherwise.
    @discardableResult
    static func sample(
        until found: ([CGRect]) -> Bool, within bound: Duration = .seconds(1)
    ) async -> (matched: Bool, panels: [CGRect]) {
        let deadline = ContinuousClock.now + bound
        var panels = Self.panels()
        while !found(panels), ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
            panels = Self.panels()
        }
        return (found(panels), panels)
    }
}

/// Whole seconds between two instants.
func elapsed(from start: ContinuousClock.Instant, to end: ContinuousClock.Instant) -> Double {
    (end - start).seconds
}

/// Opens a bundle the way the Dock would and answers its process once macOS lists it.
@MainActor func openLikeTheDock(_ bundle: ProbeBundles.Bundle) async -> NSRunningApplication? {
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.promptsUserIfNeeded = false
    NSWorkspace.shared.openApplication(at: bundle.url, configuration: configuration, completionHandler: nil)
    return await ProbeBundles.listed(bundle, within: .seconds(5))
}
