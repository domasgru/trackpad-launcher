# Settings notices

Below the divider, the window explains what limits the app. Without Accessibility access it says clicks aren't blocked during gestures and offers `Grant access…`. When a conflicting trackpad setting is on (Tap to click, or Look up: Tap with three fingers) or no trackpad is connected, the gesture hint is replaced by a notice with `Trackpad settings…`. Each button closes the window and opens the matching System Settings pane.

Last proven live: 2026-10-13, `/tmp/tlv-evidence/20261013-120421` (`notices`). Not run: both buttons (ask first), trackpad conflict (human), no trackpad (not reproducible on this Mac).

## Sub-features

- `notice-accessibility` shows `Clicks aren't blocked during gestures. Allow Accessibility access to block them.` while the app is not trusted.
- `notice-grant-button` closes the window from `Grant access…` and opens Privacy & Security › Accessibility.
- `notice-trackpad-conflict` shows `Gestures are off while these trackpad settings are on: …` instead of the hint, and the menu bar icon gets a slash.
- `notice-no-trackpad` shows `No trackpad connected. Connect a trackpad to use gestures.`
- `notice-trackpad-button` closes the window from `Trackpad settings…` and opens the Trackpad pane.

## How to get to it (user POV)

- Open the launcher window and read below the divider.
- Click `Grant access…` or `Trackpad settings…`.

## Driving it with tlv

Preconditions:

- Baseline from `README.md`. `tlv launch` starts the app with `open`, so it is its own TCC client and normally *not* trusted for Accessibility.

- **Accessibility notice.** Run `$T open`, then `$T capture notices`. `notices.ax.txt` has the `AXStaticText` `Clicks aren't blocked during gestures…` followed by `AXButton label="Grant access…"`.
- **Grant button (ask first).** With the user's OK, click `Grant access…`. Run `$T press grant-access`, `$T record notice-grant-status status`, and `$T record notice-grant-front frontmost`. The window is closed and the frontmost app is `System Settings (com.apple.systempreferences)`.
- **Trackpad conflict (human).** Ask the user to turn on Trackpad › Tap to click, then run `$T open` and `$T capture notice-conflict`. The hint is replaced by `Gestures are off while these trackpad settings are on: Tap to click.` followed by `AXButton label="Trackpad settings…"`. Have them turn it back off. The hint returns without a relaunch, which proves the push-based prefs observer.
- **Trackpad button (ask first).** With the conflict notice shown, run `$T press trackpad-settings`. The window closes and System Settings opens on Trackpad.
- **No trackpad.** Not drivable on a MacBook with a built-in trackpad. Report it as skipped.

## Gotchas

- Don't change the user's trackpad preferences (`com.apple.AppleMultitouchTrackpad`, `com.apple.driver.AppleBluetoothMultitouch.trackpad`) yourself. They're the user's real settings.
- Never grant Accessibility to the `.verify` bundle in System Settings. It adds a stale TCC entry for a `/tmp` build.
- If you start the binary directly from a terminal instead of through `tlv launch`, it inherits the terminal's Accessibility trust and the notice disappears. Always use `tlv launch`.
- The slashed versus plain menu bar icon has no AX label. Prove it with a screenshot of the menu bar around the icon, if at all.
