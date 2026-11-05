# Development logs: Opening the app by hand brings its window to the front

## Specify
- No review round recorded: the requirements arrived with the reproduction.

## Plan
- R1's "key" clause had no proof: the harness reads the frontmost app and the window order, not the key window → one hand step added to R1's entry (⌘W closes the cold-opened window), and the Strategy names key among what the harness misses.
- R2 had never been reproduced, and its acceptance dropped the focus clause; an alert run modally sits at the modal panel level and may float above other windows without focus → S1 starts by rebuilding the unchanged source (`build/dev` held the investigation's instrumented build) and running R2's sequence as its first reproduction; the expected result names the focus (the default button filled, Calculator inactive).
- The plan said the call is deprecated and would add one warning; the SDK marks it `API_TO_BE_DEPRECATED`, so the compiler is silent → the decision rewritten: marked for a future deprecation, no warning, called directly.
- The `NSApp.activate(` token let `NSApplication.shared.activate()` through → token changed to `.activate()`, confined to the tuner's file alone; the same two hits today, so still red first.
- R3 cited login-start rows that do not all read `moveDialog` → cites `aLoginStartRunsSilentlyWhereverItLies` (every placement, both states).
- The non-goal said the harness checks R1 to R3 while the Strategy gave R2 a hand sequence, which the harness cannot run (it opens the app with no arguments) → the non-goal reworded; flagged for the human, since the harness-as-check was their constraint.
- Wording: "0 bad today" overstated the table (now "on top"); "neither token appears in any other file" could not pass beside the tuner's call (now "outside the files its entry allows"); `swift test` fails at the repository root (now `make test`); a speculative closing note deleted; T1 and T2 said to prove R4's confinement, with the comment checked by S1's review criterion.

## Implement
- <what implementation-reviewer found> → <what changed>
- S1 step 1, unchanged source, R2 (1 trial): Trackpad Launcher's layer 8 window above Calculator's, but `frontmost=Calculator`, `active=false`. The dialog floats without focus.
- S1 step 2: the `.activate()` entry reported its two hits (`MoveDialogPresenter.swift:37`, `SettingsShell.swift:159`) before the change.
- S1 step 5, changed build, harness `base` 4 trials: cold-finder, cold-other, reopen-finder, reopen-other, behind-other all `0/4 bad`, every line `front=Trackpad Launcher`, `order=["Trackpad Launcher", …]`.
- S1 step 6, R1 on the changed build (Calculator in front, plain `open`): `frontmost=Trackpad Launcher`, `active=true`, windows: Trackpad Launcher layer 3, Trackpad Launcher layer 0, Calculator. The key window itself is **not verified** (needs ⌘W).
- S1 step 7, R2 on the changed build, 2 trials: both FAILED. `frontmost=Calculator`, `active=false`, Trackpad Launcher's layer 8 window above Calculator's. Same read as before the change; the activation did not take for the move dialog. Default button fill **not verified**. Not retried further; reported.
- S1 step 8: Calculator quit, target not running, no dev copy in pgrep.
