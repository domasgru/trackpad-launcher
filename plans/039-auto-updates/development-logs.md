# Development logs: Automatic updates

## Specify
- A failed check at login would wait 24 hours, so a Mac shut down nightly might never update → R1 retries when a connection arrives, and checks on wake past the mark.
- A waiting update at shutdown was undefined → R8 states the system is never delayed, and the update installs then or under the same conditions later, with a scenario.
- "Update signature" and "notarised" were unclear → R6 names what the app checks, and new R7 makes notarisation a release requirement.
- A standard account would download forever → R12: such a copy makes no check and no download.
- Vague terms sharpened → "any finger contact on any trackpad", 1 minute after the later of last touch and window close, gestures back within 10 seconds, requests including the download.
- Quit requirement split into R13 (the app's own quit is final) and R14 (updates never block logout, restart or shutdown).
- R16 no longer names a fixed version, and states its permanent cost on release assets.
- Non-goals gained rollback and fast user switching.
- Not taken: moving the Sparkle choice out of the Solution, because the user chose it and planning needs it.

Revision 2, after the user's change of rules:
- A window opened during a login update was undefined → a new requirement: no check, no card, and the new version opens with its window if one was open.
- A login download failure had no rule → it waits for the next login or the card.
- Every window opening starts blank, so the card appears only after that opening's check.
- A late failure on the card path had no rule → a working copy runs within 10 seconds, with its window.
- "No trackpad cost" is verified by review and a source check, because the user does not want it measured.
- Not taken: moving Sparkle out of the Solution, and cutting the arrow, because the user asked for both.

## Plan
- Both runners finished, no dropout. They converged on the core alone: automatic path, always held, a one-shot job, `--after-update`, `Updater` kept in Core, one home for Sparkle's private facts.
- Base: candidate 1. Rubric and cross-judge agreed, 26 to 17, on every criterion.
- Grounding probe: Sparkle does not enforce R6's same Developer ID or bundle identifier, and restarts nothing after a failed swap → a check of ours inside `willInstallUpdateOnQuit`, and a job that outlives the old process.
- Grounding probe: Sparkle's session keeps cookies, and `/releases/latest/download/` sets a year-long `_octo` → cookies refused by policy, and a feed address that sets none.
- Red-flag screen: nothing rejected. Candidate 2's always-on contact edges and its reimplementation of R4 were the nearest to leakage, and both lost on their own.
- Cross-judge: candidate 2's `Timer`, `http` and `/bin/sh` scan rows fail on arrival, and `SCNetworkReachability` is deprecated → candidate 1's rows and `NWPathMonitor` kept.
- Cross-judge: candidate 1's job gave up after 10 s, so a late end installed and nothing reopened it → the job waits on the old pid with no bound.
- Cross-judge: candidate 1's R3 limit was wrong, because its feed sat behind the same redirect as a download → fixed by moving the feed.
- Cross-judge: `import Network` is in `theNetworkBansAreAllStillListed` too, and `CardContract` needs a `removeItem(` row → both in the design's table.
- Cross-judge, ported: `alwaysDeclared` and the wider `neverDeclared`, the previous-tag build check, the fuller doc list. Its failure marker was replaced by the public `SUDownloadError`, which needs neither a marker nor a walk through nested errors and closes L3.
- Cross-judge overruled, feed: a committed file on `raw.githubusercontent.com`, not a release asset. R3's scenario says a check has no query string, the task lets a requirement override Preserve 13, and a feed in an immutable release cannot be corrected.
- Cross-judge overruled, cache: `URLCache.shared` at zero stays. Redundant for validators, as it said, but it removes `Cache.db` from disk (`textplain.out`).
- Cross-judge agreed with, on evidence: the signature check stays synchronous, 18 to 31 ms on the stapled app (`genuine.out`).
- Verification: a public `SPUUpdaterDelegate` conformance on `SparkleEngine` would put a Sparkle type on `LauncherPlatform`'s surface → a private delegate object, and `internal import Sparkle`.
- Verification: `--after-update` had no parser named, `--feed-only` had no `$APP`, the first feed file and `TLUpdateDownloads` were unstated → all four in the design.
- Verification: the coverage script found R10 nowhere in the design → stated in section 4, with L2 as its by-hand check.
- Test planner: a drop during a retry lost the return, because the bit was set on failure → `retrySpent` is set as the retry is made.
- Test planner: a retry could be swallowed in Sparkle's end-of-cycle window, which `pendingcheck.out` hit on the first try → `check()` remembers it and fires from `willScheduleUpdateCheckAfterDelay`, and a held update clears it.
- Test planner: `isPinned` demanded `https`, against a local server → prefix, `.aar` and no `..`; the scan holds `https://` and a final `/`.
- Test planner: `contactSensed` was global and the veto took nothing, so tests could not drive them → `DeviceSession` takes a `sensesContact` closure, and `SparkleInternals.veto(job:extracted:)` takes what it acts on.
- Test planner: the in-call veto had never run → probed, `vetonow.out`.
- Test planner: `card-contract` could not pass on `--archive-only` → it reports and does not fail there.
- Test planner: the job's budget ran 4 to 5 s, not 5 → `-le`, at least 5 and at most 6, and the proof uses 5 s, because a budget of 1 s cannot show C2's drift.
- Test planner: "gestures within 10 seconds" has no signal outside the app → a person's tap, and the design says so. `provenOn`'s test sits in `LauncherPlatformTests`, which can see it.
- `docs/architecture.md` and `docs/domain-model.md` rewritten with this plan, so S12 confirms them against what shipped rather than writing them.

Revision 2:
- Sparkle built from source with `SPARKLE_BUILD_UI_BITS=0` and the legacy parts off, in this session: the framework links neither WebKit nor AppKit (2.2 MB against 20 MB), so the human's stop-and-report condition did not arise. Its two signing tools build from the same clone.
- Reviewer: on a standard account Sparkle's installer runs as root and extracts under root's caches, so a check at the hold point reads nothing there and every card update would be refused → the genuineness check moved to Sparkle's download-finished callback, on the engine's own expansion of the user-owned download, which also refuses an archive before any installer exists.
- Reviewer: a *dismiss* at the ready-to-install hold refuses nothing (Sparkle's header: the update may still install at the application's end), and the old veto's job layer cannot reach the system domain → a refused archive is removed at the download, and a discard replies *skip*, which cancels the installer in either domain without skipping the version.
- Reviewer: with the installer launcher service left out, the launcher runs the administrator prompt synchronously on the main queue, freezing gestures, Quit and a logout while it is up → the launcher service is kept and enabled, in its own process; the downloader service stays out. Reported to the human as a departure from "least memory", since the process exists only while the installer is launched.
- Reviewer: a dropped probe followed by a returned connection could start a login cycle beside the still-running probe → the model keeps a `droppedProbe` phase until the probe answers, asks the engine for nothing meanwhile, and the in-memory engine counts overlapping cycles; `dropProbe` left the port.
- Reviewer: a card update failing with the window closed reached the card phase, so the next opening would show a stale card and make no check → it rests instead when the window is closed.
- Reviewer: a drop and return during a login retry that then failed was lost → the retry phase records the drop and re-arms a fresh retry; the retry's spent bit is carried through the window's check.
- Reviewer: `showUpdateFound` for an update whose installer already runs would send Sparkle's own relaunch → the driver replies by stage, *skip* for that one.
- Reviewer: R17 had both a test row and a by-hand check; R24's press of the old card needs a published release → T6 proves R3 only; R24's press is a post-publish step.
- Reviewer: *Update now* reads the feed again, which R7 does not list → stated in the plan and the docs, counted by the E2E row, flagged for the human.
- Reviewer: the design's path data was outside the repo → both subpaths are in the plan.
- Reviewer: the quit-during-update sentence misstated when Sparkle's installer commits (it commits when it starts, before stage 1) → corrected, and the gap it implied is closed by the earlier check.
- Reviewer: rows that could not fail or lacked a source (the trackpad sentence in T4, "the same version" in T13, T28's 2 s and 1 s), R13's grey-out and R21's real logout without rows, S3 naming rows whose phases arrive in S4, R9 and R10 unnamed in S3 → fixed, with T38 to T41 added and the slices' lists split.
- Reviewer, not taken: measuring the extraction's time on main (the human asked for no measurements; it is a fraction of a second once per release and named in the architecture).

## Implement
- Rebased onto `origin/main` (1.0.15) before S1. The settings redesign conflicted in `docs/architecture.md` and `docs/domain-model.md` → kept main's layout and the gear, without the update card.
- S1: the cold path did not stall: with a scratch `--cache-path` and `--disable-keychain`, `resolve` took about 19 s and `swift build` about 31 s. The vendored fallback was not taken.
- S3: `isGenuine` needed a type once `Release` went → `ExpectedUpdate` arrived here, not in S8, comparing the sealed strings.
- S3: R15's grep cannot find nothing as written, because `updateNSView`, `menuNeedsUpdate` and drawing helpers hold the word → checked by hand: 14 lines, none about the app's updates. `Copy` holds no update string.
- S5, while writing the brief: with no `v*` tag `preflight_build_number` would end the script; a failed feed push left a local commit that made `--feed-only` refuse; a same-second rerun had nothing to commit → all three fixed, each with a test.
- S8: `LaunchdJob` arrived here, not in S9, because the veto needs `remove`.
- S9: `SMJobRemove` answers true for a label never loaded → `remove` looks the job up first, so "false when absent" is true.
- Step 6: this repo has no verification skill, so nothing ran.
- Review, fixed: the architecture text understated what runs on main (the lookup, and a refused update's veto) and called the whole job's wait bounded → reworded; the code is the plan's. `release.sh` claimed a rerun publishes nothing → a rerun replaces the item, and only a byte-identical feed publishes nothing.
- Review, fixed: T18 recomputed its table → literal rows. T36 compared two sessions that both carry the contact code → a literal read count, shown to fail against a planted clock read. T1 and T28 did not test what their rows say; one assertion in `LaunchdJobTests` could not fail.
- Review, not taken: "restart" in `armRestart`, and `public nonisolated canReplace`, are the plan's own names and signature. `sessionInProgress` and the relaunch flag are public Sparkle, so they stay out of `SparkleInternals`. `#expect(!…)` and bare `@Suite` are this repo's existing style. An empty `SUPublicEDKey` is planned, and `release.sh` refuses until it is set.
- Still open, for a person: `Scripts/update-e2e.sh` has only run as `--check`, so T56 to T72 have never run and every row's helper assumption is unproven; the update key; the performance baseline; every by-hand check under Verified without a test; D-3 and L2 before the first automatic release. `SUPublicEDKey` stays empty until then, so no copy can update and no release can be made.
