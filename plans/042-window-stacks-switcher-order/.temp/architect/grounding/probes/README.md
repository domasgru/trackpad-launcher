# Probes for plan 042

Run on 2026-11-07, Mac15,6 (M3 Pro), macOS 27.2 (26B123), from a shell that has the Accessibility permission
(`ax_trusted.swift` printed `AXIsProcessTrusted: true`). Every probe only reads AX attributes and CG window lists of other
apps. The one app they act on is `fixture`, built from `fixture.swift`, which they start and end themselves. After the
runs no fixture process was left running (`pgrep` found none).

Build: `swiftc -swift-version 5 -O -o build/<name> axread.swift <name>/main.swift` (the fixture: `swiftc ... fixture.swift`).
`axread.swift` mirrors `FrontmostAppWindows.read()`: `kAXWindows`, one `AXUIElementCopyMultipleAttributeValues` per window,
the private `_AXUIElementGetWindow`, the CG lists, and today's `sort` rule.

| Probe | Question | Output |
|---|---|---|
| `ax_trusted.swift` | Can AX probes run from this shell? | yes (printed inline in the index) |
| `probe_fixture` | What the read lists for an app we control: shown, hidden, after close and open; window-number reuse; per-call cost for a stopped app; other apps read concurrently while one read is stuck | `probe_fixture.output.txt` |
| `probe_real` | Every regular running app: cold and warm read cost on the main thread; concurrent reads on GCD and on a task group against the serial results; what today's sort drops | `probe_real.output.txt` |
| `probe_hidden` | Can a hidden app's document windows be told from its panels (subrole, buttons)? What do apps with no listed window have? | `probe_hidden.output.txt` |
| `probe_budget` | Does a per-element messaging timeout cap a call at a remaining budget? | `probe_budget.output.txt` |

`fixture` opens W1, W2, W3 (W3 minimised), a floating utility `NSPanel` and a plain titled `NSPanel` (both with
`hidesOnDeactivate = false`), never activates itself, and answers `hide`, `unhide`, `open`, `close <title>`,
`churn <k>` and `quit` on stdin.
