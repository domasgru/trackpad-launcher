# Checks gathered after fan-out

## NSStatusItem expanded-interface sessions are not available at deployment target 26

- Checked: `grep -i expandedInterface` in `/Applications/Xcode.app/.../MacOSX.sdk/.../AppKit.framework/Headers/NSStatusItem.h` (SDK 26.5) returns nothing; the newest availability annotation in that header is `macos(10.12)`.
- The `axiom-macos` skill's `appkit-modernization.md` ("Status Item Expanded Interface Sessions", tagged `OS27`) describes `expandedInterfaceDelegate` / `expandedInterfaceSession?.cancel()` as the modern way to show a custom window from a status item. It is a macOS 27 API.
- Consequence for the design: at deployment target macOS 26 the status item uses the classic `button.target/action` toggle plus an `NSPanel`; close-on-click-outside comes from key-window resignation, Escape from the panel's `cancelOperation(_:)`. Keyboard navigation to the status item still fires the button action with Return (same reference, "Keyboard Navigation").

## Hardened runtime and `dlopen` of MultitouchSupport

- `direct-distribution.md` lines 211–224: hardened runtime is mandatory for notarization; the `com.apple.security.cs.disable-library-validation` exception is for loading *third-party* frameworks/plugins. Library validation allows libraries signed by Apple, so `dlopen` of `/System/Library/PrivateFrameworks/MultitouchSupport.framework` needs no exception and no entitlement. Do not add `--deep` when signing; sign the main executable last with `-o runtime`.

## Swift 6.3 / macOS 26 APIs the candidates lean on (compile-checked)

- `swiftc -swift-version 6 -target arm64-apple-macos26.0` with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`:
  - `@concurrent func f() async` compiles and runs (SE-0461).
  - `Observations({ model.n })` (Observation, Swift 6.2 async sequence over `@Observable` state) compiles and runs.
  - `Mutex<Int>` from `Synchronization` compiles and runs.

## Multitouch device classification input available on this machine

- `ioreg -c AppleMultitouchDevice -r -l`: the built-in reports `"Product" = "Apple Internal Keyboard / Trackpad"`, `"Family ID" = 109`, `"Transport" = "FIFO"`. A Magic Mouse is also an `AppleMultitouchDevice` (not present here), so the device list needs a trackpad filter; the `Product` string (contains "Trackpad") is the simplest discriminator available from IORegistry via `MTDeviceGetService`/`IORegistryEntryCreateCFProperty`. Not probed against a Magic Mouse or Magic Trackpad.
