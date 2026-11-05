import AppKit

/// The one place the app becomes the active app, whichever app is active.
///
/// The app is `LSUIElement`, so opening it by hand while its process is not running starts it
/// without making it active. Since macOS 14 `activate()` is cooperative: the system grants it only
/// when the active app yielded, and on such an opening nothing yielded, so the settings window stays
/// under the active app and the move dialog floats above it without the keyboard focus.
///
/// `activate(ignoringOtherApps: true)` is marked for a future deprecation but is the one call that
/// works: 3 of 3 in each mode of plan 034's harness that starts the process, where `activate()`, a
/// deferred `activate()` and `NSRunningApplication.current.activate(options:)` (whose
/// `.activateIgnoringOtherApps` option the SDK says has had no effect since macOS 14) each failed
/// 3 of 3.
///
/// Call it with a window on screen: the system drops it while the app has none.
///
/// A reopen arrives already active, where the call changes nothing.
enum AppActivation {
    static func activateOverOtherApps() {
        NSApp.activate(ignoringOtherApps: true)
    }
}
