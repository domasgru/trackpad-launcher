# Development logs: In-app updates

## Specify
- Install failure without a restart had no scenario → R12 gains "Replacing the app fails": /Applications keeps a whole old copy.
- The card's state between download end and relaunch was unspecified → R7 adds the installing state ("Installing version <version>…", no *Cancel*).
- R4's macOS floor relied on release data R14 never required → R14 requires each release to declare its minimum macOS and carry a signed, notarised app; R4 ignores a release without them.
- A copy outside /Applications was unaddressed → R1 and R2 limit the check to a release build in /Applications; R2 scenario covers a copy in ~/Applications.
- "Opened by hand" vs every opening vs the post-update reopening disagreed → every opening checks, including the one an update opens.
- Release and development builds were not defined → R1 defines them by Developer ID signature, matching the glossary.
- Highest-offer, numeric ordering and wrong-version download had no scenarios → added to R4 and R8.
- Download clean-up, a check in flight at window close, the request's privacy, quit/close during install, a stall bound (30 s) and when the admin prompt appears were unstated → stated in R1, R3, R11, R12 and R13.
- R9 bundled two requirements → split into R9 (replace and reopen) and R10 (settings and permissions carry over).
- Solution named a glossary in the wrong file and left out the overview's "only Quit stops it" sentence → points to docs/domain-model.md and includes both overview changes.
- Non-goals gained a *Check for updates* button and showing the installed version.

## Plan
- Red-flag screen: candidate 2 carried a downloaded file's path through the model between two ports, and split deleting it across three places (information leakage, temporal decomposition) → the base keeps the archive inside one install port, in memory.
- Red-flag screen: candidate 2 put the asset-name wire format in Core and made `Launcher.updater` public only so the view could reach it → the format stays in the network adapter; the shell gets the `Updater` from the composition root.
- Cross-judge recommended candidate 1 as base, 27 to 19, matching my criterion-by-criterion pick → candidate 1 is the base; both candidates converged on the same overall shape, which ships as the consensus.
- Cross-judge: candidate 1's old copy waited to be stopped by the new one, leaving Quit disabled forever if the new version died at start (plan 021 rejected the same for the mover) → grafted candidate 2's end-on-launch (`onReplaced` → `Lifecycle.end()`).
- Cross-judge: grafted candidate 2's scan additions (`Data(contentsOf:` confined to `Apps.swift`; `URLSession.shared`, `URLSessionConfiguration.default`, `.background(withIdentifier`, `String(contentsOf:` banned).
- Cross-judge and verification: candidate 2's `Process(` ban matches `hasProcess(` and `buildOfThisProcess(` and would fail the build; its team-presence gate passes Debug and perf builds (Apple Development, same team); its `.idle`-only `windowOpened` skips the check after an outcome that arrived while the window was closed → all rejected.
- Cross-judge: candidate 1's refit key `card?.layout` was never defined → `UpdateCard.Layout`, the card with its progress erased.
- Cross-judge flagged candidate 1's in-memory AppleArchive stream and `-exclude-field xat` as unprobed → checked after fan-out: extraction from `Data` through a custom byte stream works, the selection hook's `.cancel` stops it, and the unpacked app verifies with clean attributes (`checks/checks.out`).
- Verification: `notarized` with `kSecCSNoNetworkAccess` passes on a stapled app, and also on an unstapled app with a cached ticket (`checks/nonetwork-notarized.out`) → candidate 1's test "an unstapled notarised app fails offline" dropped as unreliable.
- Verification: the self-relaunch probe showed that a running app opening its own replaced bundle with the default configuration only reopens itself (grounding R-3) → `createsNewApplicationInstance = true` is load-bearing; both candidates use it.
- Test planner: the R1/R2 gate lived in the untested app target → the whole gate is the pure `InstalledRelease.init?(placement:developerIDSigned:version:macOS:)`, which the composition root and the harness both call; `CodeSignature.developerIDSigner(of:)` added for a cross-check against `codesign`.
- Test planner: R1 said every opening checks, but an opening while an update installs makes none → R1 amended with that exemption (human to confirm).
- Test planner: R12 said the running version stays installed, but an open macOS refuses after the swap leaves the new version in place → R12 amended to name that case and its *Try again* (human to confirm).
- Test planner: the cancel-versus-arrival race could only be placed with a guessed delay → `ApplicationsUpdater`'s internal init takes the download as a function value.
- Test planner: R8's positive case and the install rows depended on a third-party notarised app being in /Applications → committed fixtures made once by one script: a notarised Developer ID copy, and an Apple Development copy for R2's development-build signature.
- Test planner: R3's "the only things the server learns" could not hold for the TLS handshake, and the first amendment then bound transport headers the system adds → R3 amended to treat the handshake and system-added transport headers as inherent, and to fix the address, the app's own headers and the body (human to confirm); T19, T24 and C3 aligned.
- Test planner: R12's "keeps working until it ends" after a refused open was unobservable → checked after fan-out (`checks/after-swap/after-swap.out`): the old process keeps running and reads resources afresh from the new bundle → accepted as a named risk (open question 7).
- No runner dropped out.

## Implement
- No `AGENTS.md` in the repo → the full gate is a clean `Scripts/test.sh` plus `xcodegen generate` and a Debug `xcodebuild` of the app, as in plans 012 and 021. No `.claude/skills/verify-*` → the verification-skill step was skipped.
- Pre-existing worktree changes (`Config/Version.xcconfig`, its include, the version keys in `project.yml`, `AppIcon.icon`) were committed on their own before S1; the plan builds on `Config/Version.xcconfig`.
- Genuine-release fixtures not generated: notarising needs the human's notary profile. `Scripts/make-update-fixtures.sh` is written, and the rows that need its output skip with `UpdateFixtures.arePresent` (T21 genuine install, T25 (b)-(f), T27, T31's committed archive, T35's fixture part, `isGenuine`'s positive and negative fixture rows). No update has yet run `.installed` through a real swap.
- S1: the test administrator restores write access before the real script runs, to stand in for root; the kill-anywhere and atomicity rows run in their own nonisolated suite.
- S2: CFNetwork adds `Cache-Control: no-cache` because of the reload-ignoring cache policy. It is constant on every Mac, so T19 and T24 allow it as a system-added header (a deviation from their header list). The Figma node was unavailable, so the card copies the window's existing groups (open question 6 stands).
- S3: `admits` is stricter than the plan: a symlink must resolve strictly inside the bundle. Progress follows `countOfBytesReceived` by KVO, counting only a 200 body. The shell refits only when the card's layout changes, not on a progress push.
- S5: `release.sh` gained `--archive-only <app>` so the archive and its self-check can be tried without credentials.
- Full gate after S5: red. The test run hung (8.5 h at 0% CPU, until it was killed). Cause: a download row raced its 1 s idle timeout under parallel load, then waited without a deadline for progress that never came → every test wait is now bounded and fails on expiry (`BoundedWait`), the rig's idle timeout is 10 s outside the stall rows, every waiting suite has a time limit, and blocking loops run on their own threads.
- Review: the running version was parsed in core, against "external data is parsed into domain types at the adapter" → `ThisCopy.version()` returns `Version?`.
- Review: R14's preflight let through a version equal to an earlier one (a same-version draft, or 1.1.0 after 1.1), and accepted parts longer than `Version` parses → strict comparison with trailing zeros dropped, drafts included, and parts of 1-9 digits.
- Review: T25(f) would have thrown once the fixtures exist (the fixture app had no resource); T14 did not compare the seeded record; T21's fixture row did not release quarter by quarter; a test name claimed "after verified" → fixed.
- Review: duplicated request setup in `GitHubReleases` and a repeated signing-information read in `CodeSignature` → one helper each.
- Review, not fixed: the network-ban self-check (a literal list, as designed), T8's verbatim strings and long body (the plan's scenario row), `--archive-only` (asked for by the brief), and the plan's own choices (`developerIDSigned: Bool`, `UpdateCard.Layout`, the `aa archive` line in two scripts).
- Open: the plan's `@concurrent` install blocks a pool thread while the administrator prompt shows, as the move already does. A body held mid-stream is counted only when the next byte arrives, which matters only for tiny archives.
- Full gate after fixes: green (189 + 603 tests, 62 s from clean; 7 skipped pending fixtures; app builds with no warnings from the branch).
- Not run (manual: need a Developer ID build in /Applications, a published release, a standard account, or the notary profile): C1, C3-C8, and generating the fixtures. C2, C9 and C10 pass.
