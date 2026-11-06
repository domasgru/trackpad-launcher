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

## Implement
