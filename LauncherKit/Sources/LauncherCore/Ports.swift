import Foundation

public enum TrackpadEvent: Sendable {
    case gesture(GestureEvent)
    /// Attached, detached, or the Mac woke.
    case trackpadsChanged
}

/// The multitouch hardware.
@MainActor public protocol TrackpadHardware: AnyObject {
    /// Always called on the main actor.
    var onEvent: (@MainActor (TrackpadEvent) -> Void)? { get set }
    /// Trackpads connected now. Excludes multitouch devices that are not trackpads (Magic Mouse, Touch Bar).
    func connected() -> [Trackpad]
    /// Forgets every session, removes the click tap, stops every device, then starts exactly `trackpads` with a fresh
    /// recognizer each and, if `blockClicks` and `trackpads` is not empty, a fresh click tap. Idempotent.
    /// The tap needs Accessibility. If the system refuses it, nothing is filtered, presses are sampled as before,
    /// and taps behave exactly as without access. [] = nothing runs.
    func run(_ trackpads: [Trackpad], handMode: HandMode, blockClicks: Bool)
    /// One haptic pulse on that trackpad. No-op if it is gone.
    func playFeedback(on trackpad: TrackpadID)
}

/// The two trackpad preference domains.
@MainActor public protocol TrackpadPreferences: AnyObject {
    /// Called on the main actor after any table key changes in either domain.
    var onChange: (@MainActor () -> Void)? { get set }
    /// Current raw values of every table key, per kind, read fresh. Reads only; never writes a system domain.
    func current() -> [TrackpadKind: TrackpadPreferenceValues]
}

/// Effects the core decides and macOS performs.
@MainActor public protocol SystemActions: AnyObject {
    /// Bring to front: launch, or unhide / restore / reopen / activate exactly like a Dock click.
    func bringToFront(_ app: AppEntry)
    /// Open at Login. Idempotent. Called only on first launch.
    func registerLoginItem()
}

/// The Accessibility permission. Real: SystemAccessibilityPermission. Test: InMemoryAccessibilityPermission.
@MainActor public protocol AccessibilityPermission: AnyObject {
    /// On the main actor after trust changed, and only then. Carries no data; re-read with `isGranted()`.
    var onChange: (@MainActor () -> Void)? { get set }
    /// Read fresh. Never prompts.
    func isGranted() -> Bool
    /// Shows the system's Accessibility prompt. Returns at once; the prompt belongs to another process.
    func prompt()
}

/// Reads the listed apps off the main actor and pushes the result. Real: SystemAppScanner. Test: InMemoryAppScanner.
@MainActor public protocol AppScanner: AnyObject {
    /// On the main actor with each finished scan.
    var onScan: (@MainActor (InstalledApps) -> Void)? { get set }
    /// Returns at once. Requests made while a scan runs coalesce into exactly one more scan after it.
    /// The scanner also scans by itself after an app is installed, removed or renamed, and at no other time.
    func scan()
}
