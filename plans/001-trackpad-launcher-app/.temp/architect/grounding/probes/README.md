# Probes

Each directory holds one probe, its source, and what it printed on this machine (macOS 26.6.2, Mac15,6, 2026-10-09). Compile with `swiftc` from the Command Line Tools (SDK 15.4); the facts probed are runtime behaviour of macOS 26, not SDK surface. Every probe leaves the machine as it found it.

| Probe | Question | How to run | Output |
|---|---|---|---|
| `mt-probe/` | MultitouchSupport via `dlopen`: symbols, device list, device ID vs IORegistry, IOKit matching notification, `MTDeviceStart`, contact-frame callbacks, `CGEventSource.buttonState`, `MTActuator*` haptics, TCC | `swiftc -O -o mt-probe main.swift && ./mt-probe` | `output.txt` (12 s listen), `output-run2.txt` (25 s listen) |
| `kvo-probe/` | KVO on `UserDefaults(suiteName: "com.apple.AppleMultitouchTrackpad")` when another process writes the domain via cfprefsd | `swiftc -O -o kvo-probe main.swift && ./kvo-probe` | `output.txt` |
| `activate-probe/` | `NSWorkspace.openApplication(at:configuration:)` from a background process on a target app in each state: not running, hidden, minimised, no windows, already active, double-open | `./run.sh` (builds a throwaway `TLProbeTarget.app` in `/tmp`, unregisters and deletes it afterwards) | `output.txt` |
| `svg-probe/` | `NSImage(contentsOf:)` loads the SVG assets and draws them as template images | `swiftc -O -o svg-probe main.swift && ./svg-probe <assets dir>` | `output.txt` |
| `swift-testing-probe/` | `swift test` runs Swift Testing (`@Test`) on this toolchain with library + executable + test targets | `swift test` | `output.txt` |

Not probed (no touch happened during either listen window; the user was idle for 9 minutes): the shape of delivered frames (MTTouch layout, state values, normalized coordinate origin, callback thread). See `index.md`, Q1.
