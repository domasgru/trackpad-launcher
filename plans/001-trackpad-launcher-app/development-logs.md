# Development logs: Trackpad Launcher

## Specify
- Physical click with the thumb anchored was unspecified → R11 lists it as not a gesture; scenario "Click is not a tap".
- Finger count for staggered taps and thumb-lift order were unspecified → R11 defines N as the peak non-thumb finger count and requires the thumb to stay anchored until the last finger lifts; scenarios added for both.
- Anchor corner size was untestable → R11 states roughly the leftmost 20% × topmost 25% of the surface; scenario with 1 cm inside / 4 cm outside.
- R12 "restore its windows" was ambiguous, had no other-desktop case, and could conflict with R20 (no permissions) → R12 restated as "exactly what clicking the Dock icon does", R20 wins on conflict; scenarios for another desktop and a second tap during launch.
- R7 did not say whether an assignment is a path or an app identity → identity; moved apps keep working, reinstalled apps recover; two scenarios added.
- R4 "match the design" contradicted R9/R15/Non-goals → R4 names the three deviations (hand toggle, no Learn more, notice replaces hint). R9 places the toggle above the divider.
- R15 "notice disappears live" was unreachable because the window closes on click outside → scenario now reopens the window; requirement says the next showing has the hint.
- Window behaviour when a gesture fires or the icon is clicked while open was unspecified → R3: both close the window.
- No trackpad connected had no defined state → R2/R14/R15: inactive icon and a "No trackpad connected" notice.
- Look-up-only notice case missing → R15 names only the current causes; scenario added.
- Smart zoom might also fire on a tap → R14 states the rule (any tap-bound system action) and makes Smart zoom conditional on testing.
- R5 folder list vague and Finder not pickable → explicit folders plus Finder; list refreshes each time the picker opens.
- R21 log scenario would fail on framework messages → scoped to the app's own messages and own files.
- "Within a few seconds" / "infrequent blips" vague → 5 seconds everywhere; at most one blip per minute.
- Problem statement did not motivate privacy, permissions, idle cost → paragraph added.
- Non-goals: added "maximising/zooming" (overview wording) and "manual on/off switch"; trimmed technology justifications; sound bullet now records the user's deferral.
- R8/R21 persisted-data lists aligned; R13 "No haptic MUST" → "MUST NOT"; R2 icon states defined (symbol vs slashed symbol).
- Own follow-up: R14 heading broadened; external-trackpad scenario given an observable THEN.

## Plan
- Red-flag screen: candidate-2's `installedApps()` was a pass-through called from a view body, its preference keys and domains were public core API, and it kept a `resolution` map in sync with settings by hand → base chosen from candidate-1; `activity` made a computed derivation; enumeration kept in `openWindow()` off the main actor.
- Red-flag screen: candidate-1's `SystemActions` is shallow by design (two effects, two real adapters) → kept as the recording seam; candidate-2's seven one-method protocols plus `openURL`/`terminate` closures in the hub rejected as a larger surface with no added policy.
- Cross-judge (candidate-1 18/18 vs candidate-2 11/18, agreeing with the orchestrator's 17 vs 11): candidate-2 treated every multitouch device as a trackpad (a Magic Mouse would read the external trackpad domain and could fire gestures) → trackpad classification by the IORegistry `Product` string kept from candidate-1 and made explicit.
- Cross-judge: candidate-2 saved the "launched before" flag before registering the login item (a crash in between loses the login item for good) and treated an unreadable settings blob as a fresh install (would re-enrol a login item the user turned off) → first launch derived from the absence of a record; register before the first save; undecodable data loads as defaults.
- Cross-judge: candidate-2's hub-owned `Task { @MainActor }` hop made its own negative test unable to fail → the main-actor hop lives in the hardware adapter so the in-memory adapter delivers gestures synchronously.
- Cross-judge: candidate-2 ignored fingers already down when the thumb landed, so two resting fingers plus one tap would fire the 1-finger gesture (R11 "tap that began before the thumb") → candidate-1's voiding kept, encoded as the `spoiled` state.
- Cross-judge: candidate-1's recognizer state was `anchor?` beside `phase` (an anchorless tap representable) and its settings list was hand-edited → grafted candidate-2's `State` sum type carrying the anchor and the `ConflictingSetting` enum-as-table with exhaustive switches, wrapped in the non-empty `ConflictingSettings`.
- Cross-judge: candidate-1's usage called `recognizer.run`, absent from the sketch, and passed untyped fixtures → usage folds over `step`; `Trackpad.macBook14` / `.magicTrackpad` fixtures added.
- Cross-judge: candidate-1's `run` released devices before clearing the callback registry → registry cleared first so in-flight frames are dropped.
- Cross-judge: candidate-2 assumed touch IDs are never reused on the next frame → grafted `Touch.Phase.landing` from MT state 3.
- Verification: `NSStatusItemExpandedInterfaceSession` (the modern status-item API the macOS skill recommends) is absent from SDK 26.5 → classic button action + `NSPanel` with resign-key guard and a mouse-down monitor while open; recorded in `checks/`.
- Verification: `Observations`, `Mutex`, `@concurrent` compile at the macOS 26 target on the Xcode 26 toolchain → kept in the sketch.
- Verification: domain-model said an assignment is missing when the app is "no longer on disk", R7 says "no copy outside the Trash" → domain model corrected; *Trackpad* and *Conflicting setting* added to the glossary.
- Rejected grafts, recorded in the Synthesis decision: corner-agnostic recognizer (splits the anchor-corner rule across two modules), gating only at `fire` (contradicts "nothing is recognised"), URL write-back on fire, schema version field, fast-user-switching handling (unrequested; now an open question).
- No runner dropout; both candidates produced output on the first dispatch.
- Test planner: the recognizer sketch could not pass its own ID-reuse script (a tracked contact reappearing with `.landing` never left `down`, so the first tap never fired and its landing point was overwritten) → `step` evaluates lifts before landings; a reused ID lifts and lands anew in one frame.
- Test planner: `InMemoryTrackpads.wake()` only posted the event, so R16 "After sleep" passed with reconcile-on-wake deleted → `sleep()` added (running devices drop frames until the next `run`).
- Test planner: the "gesture already in flight when activity flips" guard in `Launcher.fire` had no driver (`touch` drops frames on a stopped device) → `InMemoryTrackpads.inject(_:)` added.
- Test planner: register-before-save order (decision 7) was unobservable through `RecordingSystemActions` → `onRegisterLoginItem` hook added; the World snapshots `store.load()` inside it.
- Test planner: R5 says the picker list refreshes "each time the picker opens" while the design refreshed it on window open → design changed, not the requirement: `AppPicker` over `NSPopUpButton` enumerates the catalog in `menuNeedsUpdate`; `Launcher.installedApps` property, the `@concurrent` enumeration and the async `openWindow()`/`start()` removed; `MenuBarShell` takes the catalog.
- Test planner: R10's hint wording had no seam below the view → `HandMode.cornerName`.
- Test planner: `TouchScript.tap(clickMidway:)` could not express a click on the landing frame (R11 "physical click … with any number of fingers" enters at two transitions) → `click: ClickTiming` (`.onLanding`, `.midway`).
- Test planner (risk, no change): KVO on a cfprefs domain the test creates may differ from the probed existing-domain case; the platform test creates the domain with a non-table key first if needed.
- Test planner (round 2): the `thumbRollsWithinMargin` script was in the design's list but `TouchScript` had no way to move the anchored thumb → `rollThumb(toMM:)` added to the fixture sketch.
- Test planner (round 2): the tradeoff's "cache the enumeration per window open" fallback would reintroduce the R5 staleness just removed → reworded to "make the enumeration cheaper, never cache it".
- Test planner (round 3, rejected): four names in the R11 script list cannot be sequenced by the `TouchScript` builder → no row is undrivable (T4, T5, T13, T20 hand-build frames through the public initialisers); extending the builder with negative offsets and ID-reuse options would cost more reader load than four hand-built frame lists. One clarifying sentence added to the script list; no signature changed.

## Implement
