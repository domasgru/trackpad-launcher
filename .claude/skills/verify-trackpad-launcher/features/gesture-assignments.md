# Gesture assignments

Each of the four gesture rows has an app picker. Opening it lists every installed app (rebuilt on each open), then `Other…` and `None`. The row's current app is checked. A choice is saved immediately and survives relaunch. A saved app that is no longer installed shows greyed as `<name>  not found`.

Last proven live: 2026-10-13, `/tmp/tlv-evidence/20261013-120421` (`assign-*`). Not run: Other… (ask first, human).

## Sub-features

- `assign-list` opens the picker, lists installed apps plus `Other…` and `None`, and checks the current app.
- `assign-pick` sets a row's app from the picker.
- `assign-none` clears a row back to `Choose app…`.
- `assign-missing` shows a saved but uninstalled app as `<name>  not found`.
- `assign-other` picks any `.app` through a file chooser opened at `/Applications` (human).
- `assign-persist` keeps assignments across quit and relaunch.

## How to get to it (user POV)

- Open the launcher window and click the picker at the right of a gesture row.
- In that menu, choose an app, `Other…`, or `None`.

## Driving it with tlv

Preconditions:

- Baseline from `README.md` (default fixture), launched in this run.

- **Seeded rows.** Run `$T open`, then `$T capture assign-before`. `assign-before.rows.json` is `{"1":"TextEdit","2":"Ghost App  not found","3":"Choose app…","4":"Choose app…"}`.
- **List and check.** Open row 1's picker. Run `$T record assign-list menu 1`. The output lists installed apps, then `---`, `Other…` and `None`, with `✓ TextEdit` checked.
- **Pick.** Choose Calculator for gesture 3. Run `$T pick 3 Calculator`, then `$T record assign-pick-settings settings`. The record contains `com.apple.calculator` under `"3"`, and `$T rows` shows `"3":"Calculator"`.
- **None.** Clear gesture 1. Run `$T pick 1 None`, then `$T record assign-none rows`. Row `"1"` is `"Choose app…"`, and `$T settings` has no `"1"` key.
- **Missing app.** Run `$T record assign-missing menu 2`. Row 2 reads `Ghost App  not found`, and its menu has no `✓` line.
- **Persist.** Quit and relaunch. Run `$T quit`, `$T launch --seed keep`, `$T open`, then `$T capture assign-after-relaunch`. The rows show `"1":"Choose app…"` and `"3":"Calculator"`.
- **Other… (ask first, human).** With the user's OK, run `$T pick 4 "Other…"`. The window closes and an `Open` chooser appears at `/Applications`. Ask the user to choose an app and click Open. The window reopens. `$T record assign-other rows` shows that app in row 4, and `$T settings` has its bundle ID.

## Gotchas

- Titles must match the menu exactly, including the ellipsis character in `Other…`. Run `$T menu <n>` to see them.
- The missing-app title has two spaces before `not found`.
- **Open issue: the app may exit after Other….** Twice during skill creation, the verification build exited about two seconds after the Other… chooser came to the front, with no crash report. It was during agent-driven attempts while the user was at the Mac, so a person dismissing the chooser and clicking Quit isn't ruled out. Treat a repeat as a product regression: report it to the user with `/usr/bin/log show --last 5m --predicate 'processID == <pid>'`.
- The agent must not drive the Other… chooser itself. After an AX press, macOS cooperative activation can leave the chooser behind the user's frontmost app, and nothing short of a real click brings this `LSUIElement` app forward.
- The list comes from the machine's real `/Applications` and `/System/Applications`. Pick apps that ship with macOS (Calculator, TextEdit, Chess) so recipes work on any Mac.
- The same app on two gestures is allowed. It isn't a bug.
