import AppKit

/// The one place the app takes the front from whichever app holds it.
///
/// The app is `LSUIElement`, so opening it by hand while its process is not running starts it
/// without making it active. Since macOS 14 `activate()` is cooperative: the system grants it only
/// when the active app yielded, and on a cold launch nothing yielded, so the window or the move
/// dialog would stay under the app in front.
///
/// `activate(ignoringOtherApps: true)` is marked for a future deprecation but is the one call that
/// works: 3 of 3 in each cold mode of plan 034's harness, where `activate()`, a deferred
/// `activate()` and `NSRunningApplication.current.activate(options:)` (whose
/// `.activateIgnoringOtherApps` option the SDK says has had no effect since macOS 14) each failed
/// 3 of 3.
///
/// A reopen arrives already active, where the call changes nothing.
enum AppActivation {
    static func activateOverOtherApps() {
        NSApp.activate(ignoringOtherApps: true)
    }
}
