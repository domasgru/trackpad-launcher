# Architecture

The decisions that hold across the whole codebase. Feature-level decisions live in their plan under `plans/` and then in the code.

## Language, platform, toolchain
- Swift 6 language mode with complete strict concurrency, on the Xcode 26 toolchain (macOS 26 SDK). Deployment target macOS 26, universal binary (arm64 + x86_64).
- Build: a local SwiftPM package holds every library and test target; an xcodegen-generated Xcode project builds only the app bundle (Info.plist, resources, hardened runtime, signing, archiving). `swift test` runs the whole behavioural suite; `xcodebuild` is used only for the bundle.
- Tests use Swift Testing.

## Shape
- One `@MainActor @Observable` model owns every decision. Platform adapters sense and act behind small ports; the AppKit/SwiftUI shell renders the model's state and forwards user intents. Policy lives in pure functions and value types; the shell stays thin.
- Modules by ownership, not by execution order: `LauncherCore` (domain types, pure policy, ports, the model; imports Foundation and Observation only), `LauncherPlatform` (the real adapters over AppKit, IOKit, CoreGraphics, CoreServices (FSEvents, MDItem), ServiceManagement and the private MultitouchSupport framework), `LauncherUI` (menu bar shell and SwiftUI views), and the app target (composition root only).
- Framework and wire types never cross a port: `MTTouch`, `CFTypeRef`, `CGEvent`, `CFMachPort`, `UserDefaults` keys, `NSRunningApplication`, `NSImage` stay inside adapters and views. External data is parsed into domain types at the adapter.
- Every port has exactly two adapters: the real one in `LauncherPlatform` and an in-memory one in the tests. Concrete types that can be pointed at a temp directory or a throwaway `UserDefaults` suite are not put behind a port, unless they deliver asynchronously: those sit behind a port so the model's tests stay synchronous.

## Concurrency
- `LauncherCore` and `LauncherPlatform` are nonisolated by default; the model, the ports and the public surface of every real adapter are `@MainActor`. `LauncherUI` and the app target use main-actor default isolation.
- Multitouch frames are recognised on the framework's own thread; only completed gestures hop to the main actor. State shared with that thread lives behind a `Mutex` with one writer.
- Work that would delay a click (folder scans, Spotlight reads, icon drawing) runs off the main actor in explicitly concurrent functions, including inside `LauncherUI`; only its results hop back. The first scan and the first icon pass are the exception: they run, and are waited for, before the run loop starts, so no click can arrive before their results exist. The other exception is `AppIcons.iconDrawingIfMissing(for:)`, which draws a missing icon on the main actor, but only for the closed button showing a row app outside the list that was just picked through Other….
- No timers, no polling, no background loops: every input is a push (frames, cfprefs KVO, IOKit notifications, workspace notifications, the TCC Darwin notification, FSEvents for the app folders, user events). This is what keeps idle CPU at zero. The one extra thread is the click tap's run loop, which exists only while click blocking is armed and sleeps until an event arrives.

## Privacy and permissions
- The app asks for one permission, Accessibility, and uses it only to block trackpad clicks during gestures. It never asks for Input Monitoring or any other permission, never reads keyboard events, and works fully without it except click blocking. The Accessibility APIs and the event tap are each confined to one adapter file by the source-scan test.
- Trackpad touches come from `MultitouchSupport.framework` via `dlopen` (no link flags, no entitlements, no permission); it is Apple-signed, so the hardened runtime needs no library-validation exception.
- No network code of any kind, no logging of any kind (`print`, `NSLog`, `os_log`, `Logger`), no files written other than settings in `UserDefaults`. A source-scan test in `LauncherCoreTests` fails the build on any banned API; add to its list rather than adding prose.

## Distribution
- Direct download only, signed with Developer ID, hardened runtime, notarized with `notarytool` and stapled. Never sign with `--deep`; the main executable is signed last.
