# Fixes after review

Worktree: `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/027-tap-to-click-gestures` (branch `feature/027-tap-to-click-gestures`). Use absolute paths. Do not commit. Source paths are under `LauncherKit/` unless they start with `docs/`. The full gate (`make test` from the worktree root) is green before these fixes and must be green after. Also rebuild the app target afterwards (`xcodegen generate`, then `xcodebuild build -project TrackpadLauncher.xcodeproj -scheme TrackpadLauncher -configuration Debug -derivedDataPath build/dev -quiet` with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`), since `SettingsView` changes.

Do only these fixes. Change no behaviour except where a fix says so. Skills: `macos-dev-workflow:swift-concurrency` (fix 1), `macos-dev-workflow:swift-testing-pro` (fixes 5–8), `macos-dev-workflow:axiom-swiftui` (fix 3).

## 1. Two locks held at once on the frame thread

- **Where:** `Sources/LauncherPlatform/FrameStream.swift:69`: `let flipped = state.withLock { $0.take(recognition, now: clock) }`. This calls the injected `clock` while holding `state`'s Mutex. The test clock has its own Mutex, so that is two locks at once.
- **Rule broken:** the same file, `mergedBlocking`'s doc: "Copies the sessions out first: never two locks at once". Also architecture.md, Concurrency: "State shared with that thread lives behind a `Mutex` with one writer."
- **Fix:** read the clock outside the lock. `TrackpadTapState` (`Sources/LauncherCore/TrackpadTapState.swift`) gets a pure query saying whether taking this recognition needs the clock: it opens a lift window, or a window end is pending. `take` then takes the time as a value, not a closure: an `Uptime?` that is nil exactly when the query said no. The session asks the query under one lock and reads `clock()` (only if needed) with no lock held. It then calls `take` under a second, separate lock. This is race-free because the frame callback is the state's only writer.
- **Keep:** "an ordinary touch reads no clock" and "at most one clock read per frame".
- **Callers:** update the fake (`Tests/LauncherCoreTests/InMemoryAdapters.swift`) the same way.
- **Name:** the review also found `take`'s name hides that it returns "wantsTap flipped". Name the method and its result so a reader can tell (e.g. `mutating func take(_:at:) -> WantsTapFlipped` with a `Bool` alias, or `@discardableResult … -> (wantsTapFlipped: Bool)`; your choice, keep it simple), and keep its doc comment.

## 2. Wrong glossary word in `SettingsNotice`'s doc

- **Where:** `Sources/LauncherUI/SettingsView.swift:268`: "A hint plus a button, in a group of its own. The trackpad settings notice, the Accessibility hint and the screen recording hint share it."
- **Rule broken:** domain-model.md opens with "Use these words, with these meanings, everywhere: docs, plans, code, UI". The *Trackpad settings notice* no longer exists; the entries are *No trackpad notice* and *Tap-bound settings notice*. The button is now optional.
- **Fix:** "A message and, optionally, a button, in a group of its own. The no trackpad notice, the tap-bound settings notice, the Accessibility hint and the screen recording hint share it."

## 3. `SettingsNotice` keeps the button title and its action as separate parameters, with a dummy closure

- **Where:** `Sources/LauncherUI/SettingsView.swift:275`: `init(message: String, button: String? = nil, open: @escaping () -> Void = {})`. Also lines ~43 and ~51, which repeat `button: Copy.accessibilityButton, open: { actions.openSettings(.accessibility) }`.
- **Fix:** take one optional button value that holds the title and its action together (e.g. a small `NoticeAction` struct with `title` and `perform`, or a `(title: String, action: () -> Void)?`). With no button there is no closure. The view shows the button only when the value is present. Build the Accessibility button once in the view (a computed property or a local) and use it for both the tap-bound settings notice and the Accessibility hint. Nothing on screen changes.

## 4. architecture.md says the lift window is narrower than it is

- **Where:** `docs/architecture.md:25`, Privacy: "… block the system's tap actions (the click Tap to click makes, Look up, Smart zoom) under the anchored thumb and in the half second after a gesture, …".
- **Rule broken:** domain-model.md, *Lift window*: "A tap's fingers, a swipe's or a window swipe's fingers that lift quickly, and a finger that loses contact for a moment open it."
- **Fix:** replace "in the half second after a gesture" with "in the half second after fingers lift under the thumb". This matches the Concurrency paragraph's "(the 0.5 s after fingers lift under the thumb, …)". Change nothing else in the docs.

## 5. Compound `#expect` with unguarded indexes

- **Where:** `Tests/LauncherPlatformTests/DeviceSessionAnswerTests.swift:162-163`: `#expect(windowOpen[0] == (false, false) && windowOpen[1] == (false, false))` and the same for `[2]`/`[3]`.
- **Rule broken:** swift-testing-pro: one condition per `#expect`, so a failure says which part broke, and `#require` guards an index.
- **Fix:** `try #require(windowOpen.count == 5)`, or the frame count the row plays. Then compare the whole array against one expected literal (e.g. map the tuples to a small Equatable struct or to `[Bool]` pairs), or write one `#expect` per frame. Same assertions, same values.

## 6. `TapEventTests` hides the phase and the raw field numbers

- **Where:** `Tests/LauncherPlatformTests/TapEventTests.swift:95`: `phase: hidType == 24 ? 5 : 0`. Lines ~103-104: `CGEventField(rawValue: 123)` and `CGEventField(rawValue: 165)`, unexplained.
- **Fix:**
  - Make the phase a third parameterised argument: `(24, .lookUp, 5)` and `(22, .smartZoom, 0)`, as S1 measured.
  - Name the two fields in the test with a one-line comment: "fields 123 and 165 are 1 on the first event of the Look up pair only (measured in S1)", using two `let`s with descriptive names.

## 7. T5's grant half does not match its row

- **Where:** `Tests/LauncherCoreTests/LiftWindowTests.swift:40`, `aTapMakesNoClickOnceAccessIsGrantedWithoutARelaunch`.
- **Rule broken:** the plan's T5: "And given the five-app world started without the permission (inactive), then granted: the same for n = 1", where "the same" is "the gesture's app is brought to front, `feedback == [macBook14]`, the click is dropped".
- **Fix:** use the five-app world (Arc, Figma, Notion, Spotify, Slack), started without the permission, and `#expect` that `activity` is inactive (`.settingsNeedAccessibility(TapBoundSettings([.tapToClick])!)`) before the grant. Then grant, play `thumb.tap(fingers: 1)`, and `#expect` Arc brought to front, `feedback == [Trackpad.macBook14.id]`, and the click dropped.

## 8. T16 checks the gated port only at the end

- **Where:** `Tests/LauncherCoreTests/LiftWindowTests.swift:~158`, `aTapWithNoThumbMakesItsClickAsMacOSMakesIt`.
- **Rule broken:** the plan's T16: "`isGatedPortOn` is false throughout".
- **Fix:** play each no-thumb tap frame by frame (the World has `playFrameByFrame`, see `Tests/LauncherCoreTests/World.swift:351-358`). Observe `hardware.isGatedPortOn` on every frame and `#expect` that it was never true. Keep the click assertions.

## Not to fix (decided; do not touch)

- The `blockClicks`/`blockTapClicks` pair, the `Run` unpacking, `showsAccessibilityHint` derived from the notice's button, and `DeviceSession.liftWindowIsOpen(at:)`: these are the plan's design (T33 needs the last one).
- Negated `#expect(!…)` and plain `@Suite`: these are the repo's style.
- The `GestureEventFields` rename, T14 at L+440, and the two `TapGateTests` rows left unedited: accepted, and logged by the orchestrator.
