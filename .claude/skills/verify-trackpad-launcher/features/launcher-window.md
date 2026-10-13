# Launcher window

The only UI is a glass panel under the menu bar icon. Clicking the icon toggles it, Escape and any outside click close it, and Quit in its bottom bar ends the app. The app never shows a Dock icon.

Last proven live: 2026-10-13, `/tmp/tlv-evidence/20261013-120421` (`window-*`). Not run: outside click (human).

## Sub-features

- `window-open` opens the panel under the icon from a click on the menu bar icon.
- `window-toggle` closes the panel from a second click on the icon.
- `window-escape` closes the panel from Escape.
- `window-outside-click` closes the panel from a mouse-down anywhere outside it.
- `window-quit` terminates the app from the Quit button.
- `window-no-dock` keeps the app out of the Dock and app switcher.

## How to get to it (user POV)

- Click the `hand.tap` icon in the menu bar.
- With the panel open, press Escape.
- With the panel open, click anywhere else.
- With the panel open, click `Quit`.

## Driving it with tlv

Preconditions:

- Baseline from `README.md`. Run `$T close` so the window starts closed.

- **Closed state.** Run `$T record window-closed status`. The output has `"windowOpen":false`.
- **Open.** Click the icon. Run `$T click-icon`, then `$T record window-open status`. The output has `"windowOpen":true,` and `"windowFocused":true`.
- **Toggle closed.** Click the icon again. Run `$T click-icon`, then `$T record window-toggled status`. The output has `"windowOpen":false`.
- **Escape.** Run `$T open`, then `$T record window-escape escape`. The output is `closed`.
- **No Dock presence.** Any `status` record above has `"activationPolicy":"accessory"`, so the app has no Dock icon and no app-switcher entry.
- **Outside click (human).** Run `$T open`, ask the user to click on their desktop, then run `$T record window-outside-click status`. The output has `"windowOpen":false`.
- **Proof.** Run `$T open`, then `$T capture window-open`. The PNG shows four rows, the hand toggle, the hint, the Accessibility notice and Quit.
- **Quit.** Run `$T quit`. It prints `quit: pid <pid> exited`, and `$T doctor` reports `instance: NOT RUNNING`.

## Gotchas

- Outside-click dismissal can only be proven by a person clicking. AX actions and posted events don't produce the global mouse-down the app listens for. Don't fake it.
- Any real click by the user while you drive closes the window. A surprise `"windowOpen":false` is usually that, not a bug. Repeat the step before reporting a regression.
- `$T escape` refuses with `window is open but not key` when the panel lost focus without closing. That itself is unexpected (the app closes the panel on resign-key), so capture `status` and investigate.
- `$T quit` ends the instance. Relaunch with `$T launch --seed keep` to continue with the same settings and evidence dir.
- `$T open`/`$T close` click only when needed. Use `$T click-icon` when the proof is about the toggle itself.
