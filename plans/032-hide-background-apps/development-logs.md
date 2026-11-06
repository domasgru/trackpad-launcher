# Development logs: Hide background apps

## Specify
- Solution's "changes what is in front" contradicted R5 and R8 → rewrote it as the actual rule; R5 now says why a tap on the app in front still hides.
- The swap cannot "list" anything → Solution says the swap reaches hidden apps.
- No scenario for lifting a swipe on a hidden app → added "Lift on a hidden app" under R20.
- R12 read as an instant-in-time check, and asserted Mail stays in front → rephrased around the user bringing another app forward; dropped the assertion.
- R9 missed silent cases → added "Lift on the window already in front" and "Thumb tap with nothing to swap to".
- R13 named Spaces with no scenario and left full screen open → added "App on another Space" and a sentence that full-screen apps follow ⌘⌥H.
- R2 and R3 named cases with no scenario → added "Fresh install" and "Login start".
- R14 and R16 held several behaviours each → split into R14–R16 and R18–R20; "as the user left it" became position and switch state.
- R17's scenario could not be set up and hinted at implementation → now R21, phrased as no new permission prompt.
- R11 named an unstated limit → states 10 seconds, or 2 seconds after finishing launching.
- R5's "missing" and R10's "no process" were vague or implementation language → "no longer installed" and "not running".
- Non-goals lacked the settings window opening → added.
- Own check after applying: R9's "only one app is running" is impossible with Finder → reworded; R14's frontmost exception had no scenario → added "Settings window in front".
- Rejected: dropping "third group" (the user's wording); dropping the launch animation off scenario (the setting exists, the overview omits it); an ordering requirement for R5/R6 (the probe showed hiding at gesture time ends with the target in front).

## Plan
- R7's same-turn hide rested on a probe that waited 0.6 s between the open and the hide, with a filtered order → re-probed same-turn with the whole ⌘-Tab order: a third visible app landed second in three series steps of four. The adapter now hides the app that was frontmost only on the kept app's activation push (the earlier probe's order held in every step that way) and the rest at once; R7 gained a probe-and-manual entry and T5 a rapid-tap clause.
- R5 with the launch animation off was untested → T3 gained the clause, plus a no-process tap that hides nothing, since `fire` must read `hasProcess` with the switch on in S2.
- R4's "only later actions" was not pinned for a launch under way → T11 gained two clauses that flip the switch with no second tap; the launch record decides, not the live setting.
- The unseen watch's time limits had no proof above `LaunchClock` → T14 now drives `LaunchWatch` directly (cap, limit, stop), lower bounds only, serialized; the `LaunchClock` host-closed clause went; S4's manual checks a menu bar app past 2 s with the animation off.
- T13 and the "shows again" clauses of T4 and T5 read back the fake's own hidden set → T13 deleted, R18 moved to a manual check, T4 and T5 reworded to the model's target, "shows again" added to S2's manual criteria.
- T4's first clause assigned Safari to a gesture, which the switcher leaves out → the clause clears the assignment; the row is Notes, Safari, Mail.
- T1 tapped with the thumb top left on a top-right record; T7 asserted no pulse where slides tick, and a `raised` literal missing the lift's empty raise → fixed with the existing rows' literals.
- Hide order was observed only in T8 → the fake gains an `onHideOtherApps` hook, asserted in T3.
- The plan read R12 generously (a user who came back gets the hide) without saying so was a deviation → stated as needing the human's ruling before S4 merges, with the activation-observer alternative and its noise.
- `.windowShown` can be a hidden Electron startup window (plan 017's D3/O4) → S4's manual covers Slack, Figma and Chrome, with the window-list confirmation as the contingency.
- No probe ordered a panel in while the app was hidden → re-probed: such panels show whatever `canHide`; the closed-window branch now unhides without activation after ordering out (probed).
- The S2/S3 boundary needed the `hasProcess` read S3 claimed → the read moved to S2 with its row.
- S2 held 18 requirements → split: S2 the other apps' hides, S3 the settings window and overlays, S4 the launches.
- R13's manual lacked an ordinary window on another desktop and the ⌘⌥H comparison's contingency → added.
- The *Settings window* entry omitted the switch → added.
- Port comments were said to keep their contracts though their texts name the bounce → rewritten in the slices that change each behaviour.
- A repeat gesture on an unseen watch after turning the animation on → stated: the watch keeps its kind; the entry says so.
- Plan 017 misquoted ("ruled out") → the suite was removed for 6 s → 92 s.
- "The AX observer fires for a hidden window" was unprobed → reworded as the watch's two ends, the observer case unmeasured.
- `WatchedLaunch.showsBounce` was never read → dropped.
- Hide cost unmeasured → probed: 0.75 ms visible, 0.25 ms hidden, `isHidden` as dear as the call; the immediate hides go out on the next main-actor turn.
- App Nap on the unseen watch was uninferred → S4's manual times the 2 s limit on an idle bundled build, with a `ProcessInfo` activity as the contingency.
- Rejected: moving R18 back into a World row (it cannot fail); a window-list check before every hide (only if an app hides early); skipping already hidden apps (the read costs as much as the call).
- R12's "came back" reading needed a decision → amended R12: the frontmost read at window time decides, so a user who came back gets the hide; no activation observer. Decided by the orchestrating session under `/do`; flagged to the human in the final report.

## Implement
- No repo `AGENTS.md` → the gate is `make test` (three bundles); the app bundle was also built with `xcodebuild`, never opened. No verification skill exists, so that step did not apply.
- S1: T14's 3 s bound failed one run in four: in the parallel run other tests hold the main actor for seconds; alone a 200 ms limit passed in 217 ms → `awaiting`'s default bound, and the limit row's cap raised from 5 s to 120 s so only the limit can answer in time; lower bounds only, as the plan's strategy says.
- S1: `LaunchWatch` read `ContinuousClock` to skip later limits → removed: the first deadline to pass reports, and time stays on Core Animation's clock.
- S1: the watch made its clock in `init`, before the open → made in `start(cap:)`, so the panel never delays the app.
- S2: T1 used a record from the current code → uses the released fixture, `PersistenceTests.savedSettings`, as the row says.
- S4: the fake's `bounceEndings` became `launchEndings`, since unseen watches end too; expected values unchanged.
- R12: built on the amended reading, the frontmost read at window time; the plan's R12 text and its S4 criterion still carry the earlier wording.
- `ApplicationsUpdaterTests.swift:675`, an existing 35 s upper bound, failed twice at load averages up to 236 and passed alone 3 of 3 → machine load, not this branch; left as it is, reported.
- Review fixed: the *Running apps* entry names the new read; the *Bring to front* entry no longer contradicts *Launch watch*; the architecture's "launch bounce's launch watch"; T3 asserts `launches`, not the derived `bounces`; `hidesOthers` folded into the other two `nothingHappened` helpers; redundant `if hides`; `hasRanOut` → `hasRunOut`; `BundleID` in the pending hide; `#require` and `== false` in the new tests; `LaunchBounceTests` → `WatchedLaunchTests`.
- Review rejected: the bare `@Suite` (96 existing suites do the same); the negative `Task.sleep` waits (nothing pushes an absence, and the render server's time cannot be advanced); several scenarios in one row's test (each is a plan row); moving the fixture to its own file; a new file for the hide (the plan confines `.hide(` to the adapter's file); extracting the regular-app filter, the bring-to-front sequence or `Bounce`/`Launch` (small, and each differs in what it reads or its purpose); `B(_:)`, a test-local shorthand.
- Manual checks needing a human or real apps were not run (S1, S2, S3, S4 lists); the Electron window-list and `ProcessInfo` contingencies stay unbuilt pending them.

## Fix: hiding not reliable
- Reported: "sometimes the app is not hidden", randomly. Reproduced with `.temp/hide-stress.swift`: 6 of 25 rounds failed on the shipped algorithm, on scratch apps.
- Root cause 1: macOS activates a hidden app before it unhides it. A hide in that gap leaves nothing visible in front, so macOS activates a third app. The race is timing-only, so it looked random: 4 of 30 single gestures with hides already deferred to the activation.
- Root cause 2: the first activation of any app used up the pending hide, so a helper or an earlier gesture's activation lost it for good.
- Root cause 3: apps other than the frontmost one hid at once, racing a target still arriving, in rapid gestures.
- Fix: `BackgroundHider` holds one goal, hides nothing until the goal is active and not hidden, ignores other activations, and passes twice more to catch a hide that did not land (one repair seen in 90 rounds). Result: 0 of 90 in the script, 0 of 40 with the real class, scoped to scratch apps. Added R22.
- Review finding: `.windowShown` fired on an Accessibility window that may be hidden, which plan 017's D3/O4 had accepted for the bounce and plan 032 then used for a hide. Accepted: only a visible window-list entry counts; an Accessibility window now only triggers a look, and the watch re-looks until the time limit. Added R23. Not run against Slack, Figma or Chrome.

## Fix: switch row height and a suite that needed a quiet machine
- The Hide background apps row was 38 pt against 47 pt for its neighbours (measured with `.temp/row-height.swift`): the row predates #39's `formRowContent()`, and the merge raised no conflict because the lines differ. Fixed with the same label form as Animate app launch.
- `make test` failed under load, passed quiet (949 tests in about 39 s). Three bounds were the cause, none in this feature's code: the stall test's 35 s against about 34 s quiet, now 50 s and still under URLSession's 60 s; the install kill test's 50 s and its suite's 1 minute, now 150 s and 3 minutes; the scanner's 5 s waits, now 20 s. Each only changes how long a failing test waits. Proven with `.temp/gate-under-load.py`: 66 CPU hogs on 11 cores, load about 137.
