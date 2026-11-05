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
