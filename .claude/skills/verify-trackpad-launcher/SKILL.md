---
name: verify-trackpad-launcher
description: Build, launch and drive an isolated copy of Trackpad Launcher (the macOS menu bar app) through its real menu bar icon and launcher window via Accessibility, and capture proof (AX tree, stored settings, screenshots). Use when you need to prove a user-facing behavior of the app live — gesture assignments, hand mode, window open/close, settings notices, quit — after a change or when reproducing a bug.
---

# Verify Trackpad Launcher

Trackpad Launcher is a menu-bar-only macOS app (`LSUIElement`, no Dock icon). The user clicks the `hand.tap` icon in the menu bar, a glass panel drops down with four gesture rows (an app picker per row), a Left/Right hand toggle, a hint or settings notices, and Quit. The real feature, launching apps by a thumb-anchored tap on the trackpad, needs a physical hand: an agent cannot synthesize MultitouchSupport frames (see `features/gesture-launch.md`).

Everything goes through one helper, `scripts/tlv` (bash). It drives the UI with `tlv-ax`, a small Swift program compiled from `scripts/ax.swift` by `tlv build`, which talks to the AX API by PID. Run `tlv` from the repo root:

```bash
T=.claude/skills/verify-trackpad-launcher/scripts/tlv
$T help
```

## Isolation (read first)

- The verification build has its own bundle ID, `com.domasgru.TrackpadLauncherApp.verify`, so its settings live in their own defaults domain. The user's real settings in `com.domasgru.TrackpadLauncherApp` are never read or written. Do not run `defaults` commands against the real domain.
- `tlv build` compiles a mirror of the sources in `/tmp/tlv/src`, never the repo itself. The repo's `TrackpadLauncher.xcodeproj` (which the user may have open in Xcode) is never regenerated.
- `tlv launch` always writes a settings record before starting, or with `--seed keep` refuses when none exists. A stored record makes the app skip first-launch behavior, so it never registers a login item and never shows the system Accessibility prompt.
- **One verification instance per machine.** The bundle ID and defaults domain are shared, so `tlv launch` refuses while any `TrackpadLauncherVerify` process runs, whatever its `TLV_STATE`. That instance may belong to another agent or worktree. Don't kill it unless you started it.
- `tlv-ax` addresses our process by PID and checks its bundle ID first. Never use System Events for this app. It resolves processes by *name*, and with the user's copy or an Xcode run open, its commands went to the wrong process (observed during skill creation).
- The app runs on the user's real desktop. A real mouse click anywhere closes the launcher window (by design), so commands that act inside the window reopen it when needed. Never click screen coordinates or type keystrokes into the system. The one key `tlv` sends, Escape, is posted to our PID only, and only when our window is key.
- If the user's own copy is running (`doctor` lists it under `others`), a real gesture fires in both copies. That's harmless for window and settings work. For gesture proofs, ask the user to quit their copy.
- To verify a worktree's code, export `TLV_REPO=/path/to/worktree` for every `tlv` command.

## Launch

```bash
$T build                     # mirror sources, xcodegen + xcodebuild Debug into /tmp/tlv/dd, compile tlv-ax (~15 s)
$T launch                    # seed "default" fixture, open -n -g the app, wait for its menu bar icon
$T launch --seed empty       # all four rows unassigned, right hand
$T launch --seed keep        # keep the stored settings and evidence dir (relaunch after `tlv quit` to prove persistence)
```

The `default` fixture: gesture 1 → TextEdit, gesture 2 → "Ghost App" (bundle `com.example.verify.Ghost`, not installed, so the row shows *not found*), gestures 3 and 4 unassigned, right hand.

`launch` refuses a stale build: if any source file in the working tree differs from what was built (committed or not), it names the files and tells you to run `tlv build`.

**Ready** is the line `ready: pid <pid>, run <run-id>, evidence <dir>`. It prints only after the AX API sees the process's menu bar icon. The process alone existing doesn't count. Requires Xcode 26 at `/Applications/Xcode.app` and `xcodegen`. The shell running `tlv` needs Accessibility and Screen Recording permission (both already granted to this terminal).

## Doctor

```bash
$T doctor
```

This is read-only. It checks:
- the build exists and matches the working tree file for file,
- the recorded PID is alive and runs exactly our executable,
- the menu bar icon is present, and whether the window is open and key.

It also lists other Trackpad Launcher processes and prints the stored settings and the evidence dir. It ends with `doctor: OK` or `doctor: NOT READY` (exit 1). Run it first whenever anything looks off.

## Drive

| Command | User action it performs |
|---|---|
| `$T open` / `$T close` | click the menu bar icon (only if the window is in the other state) |
| `$T click-icon` | click the menu bar icon exactly once (toggle) |
| `$T rows` | read the four pickers: `{"1":"TextEdit","2":"Ghost App  not found","3":"Choose app…","4":"Choose app…"}` |
| `$T menu <n>` | open row n's picker, list items (`✓` = checked, `---` = separator), cancel the menu |
| `$T pick <n> "<title>"` | open row n's picker and choose an app exactly as listed, or `None` |
| `$T hand left\|right` | click the `Left hand` / `Right hand` segment |
| `$T press quit\|grant-access\|trackpad-settings` | click the button labelled `Quit` / `Grant access…` / `Trackpad settings…` |
| `$T escape` | press Escape in the window; prints `closed` / `still open` |
| `$T tree` | full AX tree of the window, with labels and values |
| `$T status` | `{"statusItem":true,"windowFocused":true,"windowOpen":true}` |
| `$T settings` | the stored settings record as JSON (the side effect of every mutation) |
| `$T frontmost` | frontmost app, e.g. `TextEdit (com.apple.TextEdit)` |
| `$T quit` | click Quit (opening the window first if needed); waits for the process to exit |

**Ask the user first** before `press grant-access` or `press trackpad-settings`, which bring System Settings to the front of their desktop, and before `pick <n> "Other…"`, which brings a file chooser forward (see `features/gesture-assignments.md`).

Stable handles in the AX tree (`$T tree`):
- The window is `AXWindow > AXGroup`.
- Each row is an `AXImage label="N-finger gesture"` followed by its `AXPopUpButton`, whose `AXValue` is the shown title.
- The hand toggle is `AXRadioGroup label="Hand mode"` with `AXRadioButton label="Left hand"` and `label="Right hand"` (value `1` = selected).
- The hint and notices are `AXStaticText`.
- The buttons are `AXButton label="Quit"`, `label="Grant access…"` and `label="Trackpad settings…"`.

SwiftUI exposes these labels as `AXDescription`/`AXAttributedDescription`, which System Events can't read. That's one more reason `tlv-ax` uses the AX API.

## Evidence

```bash
$T capture <name>               # <name>.ax.txt, <name>.settings.json, and if the window is open <name>.rows.json + <name>.png
$T record <name> <command...>   # e.g. `$T record assign-list menu 1`: command, output and exit code as <name>.txt
$T screenshot <name>            # PNG of the window frame only
$T evidence-dir                 # /tmp/tlv-evidence/<run-id>
```

Proof standards:
- Drive the real user path: the menu bar icon, the picker menus, the toggle, the buttons. Never write settings with `defaults` to fake a state the feature should produce. Seeding is only for preconditions.
- Capture before and after: `capture <id>-before`, act, then `capture <id>-after`. Every check whose result is command output (`menu`, `frontmost`, `status`) goes through `record`, so nothing is proven only in your scrollback.
- A visible change isn't enough. Check the side effect in `settings.json`, and for persistence, `quit` then `launch --seed keep` and read `rows` again.
- A behavior that needs a human (gestures, outside click, the Other… chooser, changing trackpad settings) is reported as **not verified by the agent** unless the user performed it and you captured the result.
- Evidence lives in `/tmp/tlv-evidence/<run-id>/` and survives `tlv cleanup`. `--seed keep` reuses the run id.
- Privacy: the panel is translucent glass, so screenshots show blurred fragments of whatever user windows sit behind it. Keep evidence local and don't attach the PNGs to anything shared without the user's OK.

## Cleanup

```bash
$T cleanup
```

This kills only processes whose command line is exactly our build's executable (`/private/tmp/tlv/dd/Build/Products/Debug/TrackpadLauncherVerify.app/Contents/MacOS/TrackpadLauncherVerify`), and waits up to 5 s for them to exit. It then deletes the `com.domasgru.TrackpadLauncherApp.verify` defaults domain and prints `evidence kept: <dir>`. The source mirror and build in `/tmp/tlv` stay as a cache (remove them with `rm -rf /tmp/tlv`). Run cleanup after every run, including failed ones. Never `pkill` by name: the user's own copy and Xcode runs are `TrackpadLauncher` processes too.

## Feature map

`features/README.md` indexes one recipe per user-facing feature. When proving a feature, cover every entry point its file lists, or report the ones you skipped. Each recipe records when it was last proven live.

## Keeping it honest

The map rots the moment the app changes. After any user-facing change:
1. Run `$T build`, then drive **every** mapped feature live, not just the one you touched.
2. When a recipe fails because the skill is wrong (a renamed label, a moved control, a missing driver command), fix the recipe, `tlv`, or `ax.swift` here in this directory, and update the recipe's "Last proven live" line.
3. When the app is wrong, report it to the user as a product regression, with the evidence dir. Never weaken a recipe or reword the map to make a broken behavior pass.
4. Add a feature file for every new user-facing feature, and list it in `features/README.md`.
