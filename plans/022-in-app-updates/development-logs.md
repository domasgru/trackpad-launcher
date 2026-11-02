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
