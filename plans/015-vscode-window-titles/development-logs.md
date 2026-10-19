# Development logs: VS Code window titles lead with the project

## Specify
- Scenarios checked only what a row reads, not that lifting still acts on the right window → added "Lifting on a reworded row" to R1.
- Single-window GIVENs could not show a window switcher → added a preamble that every scenario's frontmost app has two or more windows; the minimised scenario now has a window in front too.
- R4 and R5 overlapped on the empty title, and the order of rewording vs fallback was unstated → R4 covers non-empty titles only; R5 says rewording never applies to the fallback text.
- "N its row" and "its second window" were ambiguous → reworded to the row's position in the switcher.
- Names containing " — " and a customised `window.titleSeparator` were not covered → added both as accepted limitations in Non-goals.
- Rejected: dropping the extensibility sentence (the user asked for it), dropping VS Code Insiders (the user confirmed it), moving bundle identifiers out of R1 (they make the app identity precise, as assignments do).

## Plan
- The VS Code and Insiders scenarios were two separate tests with different assertions, so the next app would have been a new test function, against the user's ask → T1 is one parametrised test over apps (name, bundle identifier, raw titles, rows expected) with VS Code, Insiders and Safari as its argument rows, all making the same assertions; the next app is one more argument row, and the recipe in Further Notes says so.
- The extra windows beside each scenario's window had expected rows worked out by the rule, not quoted from a requirement → every extra window is R1's `how-explorer.md — skills`, whose row `skills — how-explorer.md` R1 quotes; T5 also asserts that row so the same switcher shows the rule on and the single-part title untouched.
- R5's literal `Visual Studio Code — Window 2` names the bundle's file name, which macOS never reports (VS Code's `CFBundleName` and `CFBundleDisplayName` are "Code") → R5's scenario reads `Code — Window 2`, with the reason in brackets, and T6 names the frontmost app "Code".
- The plan promised an undefined World helper that installed VS Code as a fake bundle → no helper: the tests set the fake system's frontmost app to an `AppEntry` built as the running-app adapter builds one; the window swipe never looks the frontmost app up in the catalog.
- `WindowTitleRule` was described as a value type plus a separate rewording enum, with unstated access and a "non-empty" condition on its one function → one internal `Sendable` enum: the cases are the rewordings, the table and `displayTitle(_:of:)` are static members, and `displayTitle` is total over any title; the fallback-before-rule order lives in the rows, guarded by T6.
- `Equatable` was justified by a test of the table that no scenario runs → dropped; `Sendable` stays for the static table.
- The R7 acceptance criterion half-consisted of greps that already pass today and cannot fail → the criterion is the manual step alone; the greps stay as evidence under Verified without a test.
- `docs/architecture.md` said windows without a number are matched to the window list "by their frames" while the adapter matches by frame and title → corrected to "and by their titles where the list names windows" (a pre-existing inaccuracy, no decision changed).

## Implement
- VS Code's rule was spelled out twice in the table → one `vsCode` rule value shared by both bundle identifiers.
- Tests took `AppEntry` apart into name, identifier and path, and T1's Safari row rebuilt World's `com.test.safari` entry by hand → file-private `vsCode` and `vsCodeInsiders` entries; T1's rows carry an optional frontmost entry, `nil` leaving `windowWorld`'s installed Safari in front.
- T1 mapped row titles inline beside the suite's `titles` helper → uses the helper.
- Rejected: collapsing the one-case enum into a plain function (the user asked that the next app, and the next shape, be a small self-contained change); renaming `leadWithSecondPart` to the domain's "leads with the project" (the case is reusable for other apps' shapes, its separator a parameter); dropping T1's selection and T3's haptic assertions (the plan's T1 and T3 name them); moving the `docs/architecture.md` correction out (recorded under Plan as a pre-existing inaccuracy fixed with this plan).
- Not done by agents: Further Notes step 3, the on-screen check that a long reworded title ends in "…" (R7), is the user's manual check.
