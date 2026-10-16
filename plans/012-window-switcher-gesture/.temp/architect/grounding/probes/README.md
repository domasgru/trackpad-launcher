# Probes

Run on this machine on 2026-10-16: macOS 26.6.2 (25G83), Xcode SDK 26.5, Swift 6.3.3. The shell that ran them is
Accessibility-trusted and has Screen Recording, so the AX and capture probes ran for real. Each `*.output.txt` is the
verbatim output. TextEdit was not running before any probe; each probe that uses it launches it on temp files, quits it,
re-activates the previous front app and deletes the files.

| Probe | What it settles | Output |
|---|---|---|
| `probe-1-environment.swift` | Trust, Screen Recording preflight, TextEdit state, OS version | inline in index |
| `probe-2-ax-windows.swift` | AX window list and attributes, `_AXUIElementGetWindow`, CGWindowList order, AXRaise, focus, minimise/restore, re-stacking, a closed window's element | `probe-2-ax-windows.output.txt` |
| `probe-3-capture.swift` | CGWindowList cost cold/warm, `SCShareableContent` cost and contents, single-window capture cost and size, occluded and minimised capture, SC order vs CG order | `probe-3-capture.output.txt` |
| `probe-4-sdk-symbols.swift` | Which capture and glass symbols the SDK offers (typecheck only) | `probe-4-sdk-symbols.output.txt` |
| `probe-5-spaces.swift` | What AX and CG say about a window on another Space and a full-screen front window | `probe-5-spaces.output.txt` |
| `probe-6-tcc-notification.swift` | Whether `com.apple.tcc.access.changed` fires for a Screen Capture change (a no-op `tccutil reset` of the app's own, never-granted entry) | `probe-6-tcc-notification.output.txt` |

Machine state afterwards: as found. The only side effect was probe 6's `tccutil reset ScreenCapture
com.domasgru.TrackpadLauncherApp`, which removed nothing because the app has never asked for Screen Capture (tccd
reported one reset per built copy of the bundle it knows of).
