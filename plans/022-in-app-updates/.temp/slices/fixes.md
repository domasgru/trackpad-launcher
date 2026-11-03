# Fixes after review: plan 022, in-app updates

Worktree: `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/022-in-app-updates` (branch `feature/022-in-app-updates`). Do not commit; the orchestrator commits your work. Do not switch branches. Use absolute paths. Package root: `LauncherKit/`.

Fix every item below, in this order. Item 1 is a red gate and comes first.

## How to run tests in this task (mandatory)

macOS has no `timeout`. **Never start a test run without a wall-clock cap.** Use perl's alarm, which kills the run after N seconds:

```sh
cd /Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/022-in-app-updates/LauncherKit
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer perl -e 'alarm shift; exec @ARGV' 600 swift test --filter <Suite> 2>&1 | tail -40
```
A whole-package run should take about 1-2 minutes (the slowest suites take ~35 s and ~20 s); cap it at 600 s. If a run is idle for more than a few minutes, treat it as a hang, not as slowness. Run Bash commands in the foreground with that cap (the Bash tool's own limit is 10 min).

## 1. The full gate hangs (red gate)

**What happened.** A clean `Scripts/test.sh` (which runs `swift test` in `LauncherKit`) hung for 8.5 hours at 0% CPU: the main thread was idle in its run loop, waiting on something that never fired, until it was killed. The same hang appeared intermittently during S4 (three runs hung, then later runs passed unchanged). Tests that had started and never finished, nearly all from this branch:
`aBodyOfTheWrongLengthFailsWithoutEverReportingTheDownloaded`, `aCompleteArchiveIsDownloadedWhetherItComesAtOnceOrSlowerInTotalThanTheStallButNeverIdleThatLong`, `aDownloadReportsEveryWholePercentAsItsQuartersArriveThenFailsOnAnArchiveThatHoldsSomethingElse`, `aDownloadThatMakesNoProgressFailsAfterThirtySeconds`, `aFailedRequestAnswersNothingAtOnce`, `anArchiveHoldingAnythingButTheAppIsRefusedAndNothingIsWrittenOutsideTheStagingFolder`, `anArchiveThatIsNotGenuineIsRefusedBeforeAnyPromptEvenWhereThePromptWouldBeNeeded`, `aServerThatNeverAnswersGivesUpAfterTheStall`, `aServerThatStopsSendingFailsAfterTheStall`, `aStatusOrBodyThatIsNotTheListAnswersNothing`, `cancellingAtFortyPercentClosesTheConnectionAndLeavesNothingAndTheNextUpdateWorks`, `cancellingFromInsideTheDownloadedEventChangesNothingAndOneOutcomeFollows`, `cancellingTheMomentTheArchiveArrivesStopsBeforeTheDownloadedIsReported`, `everyCheckSendsTheSameConstantRequestAndStoresNothingTheServerOffers`, `killingTheRealScriptAtAnyMomentLeavesAWholeCopyAndTheNewOneOnceItExitedZero`, `onlyAPublishedFullReleaseWithAWellNamedUploadedArchiveFromThisRepositoryCounts`, and three older ones (`broadcastReachesOnChangeOnlyWhenTrustOrScreenCaptureChanged`, `scansOnRequestAndAfterEveryInstallAndRemovalWithoutARequest`, `writesInsideAnInstalledBundleCauseNoScan`). The log of that run is `/tmp/tl-022-gate-test.log`.

**Rule it breaks.** The repo's gate (`swift test` passes; plan C10: "`swift test` passes, including the unchanged lifecycle, move and source-scan suites") must finish, and a test must fail rather than wait forever.

**A hypothesis to test first, not a conclusion.** Swift Testing runs tests in parallel on Swift concurrency's cooperative thread pool (about one thread per core). Several new tests and helpers **block** a thread while they wait: `ScriptRun.finish` (`PrivilegedInstallTests.swift`, `waitpid`/`usleep` loops, T32), `DestinationObserver` (a `DispatchSemaphore`, T33), `TestAdministrator.run` (`process.waitUntilExit()`, called from the `@concurrent` install), and perhaps blocking reads in `LocalReleaseServer`, `BundleFixture.run` or the ~30 s T29 suite. If enough of these run at once, every pool thread is blocked, and continuations that other tests (and the main actor's work) wait on are never scheduled, so the whole process stalls at 0% CPU. A continuation that is never resumed (for example a `withCheckedContinuation` around a server or URLSession callback that does not fire on some path) would show the same symptom. Find out which it is.

**Fix decided.**
1. Reproduce: run the platform suites (`--filter LauncherPlatformTests`) with the perl cap, repeatedly (e.g. 5-10 times), and also the whole package, until it hangs or you are confident it does not. If it hangs, sample the stuck process (`sample <pid> 5` or `lldb -p <pid> --batch -o 'thread backtrace all'`) to see which threads are blocked where. Record what you found.
2. Fix the root cause so it cannot recur. Blocking waits in tests must not run on the cooperative pool: move them onto their own threads (`Thread`, or `DispatchQueue.global()` work bridged by one continuation), or make them asynchronous. Every continuation a test awaits must be resumed on every path.
3. Bound every asynchronous wait in tests: a test that waits for an event, a callback, a server or a process must have a time limit that **fails the test** rather than hangs. Add a `.timeLimit(.minutes(1))` trait on each suite or test that waits (Swift Testing's minimum is one minute; T29 needs more, give it two), and where a wait is on a single callback, prefer a helper that awaits it with its own deadline and records an issue on expiry. Apply this to the existing suites that hung too (`SystemPermissionsTests`, `SystemAppScannerTests`), not only the new ones.
4. If the product code itself blocks a cooperative thread in a way that can starve the app (for example `ApplicationsUpdater`'s `@concurrent` install waiting on the administrator prompt), report it; fix it only if the fix is small and keeps the plan's design (the move already does the same and is out of scope).
5. Prove it: run the whole package with the cap at least 3 times in a row from clean (`rm -rf LauncherKit/.build` before the first), each finishing well inside the cap. Report each run's summary lines and duration.

## 2. The running version is parsed in core, not at the adapter

- Files: `LauncherKit/Sources/LauncherPlatform/ThisCopy.swift:21` (`public static func version() -> String?`) and `LauncherKit/Sources/LauncherCore/Update.swift:35` (`InstalledRelease.init?(placement:developerIDSigned:version: String?, macOS:)`).
- Rule: `docs/architecture.md`, Shape: "External data is parsed into domain types at the adapter."
- Fix: `ThisCopy.version()` returns `Version?` (it parses `CFBundleShortVersionString` with `Version.init?`), and `InstalledRelease.init?` takes `version: Version?`. The gate stays one pure initializer; the composition root (`makeUpdater`) and the test harness (`OneProcess`) pass `Version?`. Move T35's "the versions nil, "" and "1.0.0-beta"" cases accordingly: nil stays a gate row; "" and "1.0.0-beta" are covered by `Version` parsing rows (and a `ThisCopy`-level test if there is a seam for it). Update doc comments.

## 3. A test name claims verification its order cannot prove

- File: `LauncherKit/Tests/LauncherPlatformTests/ApplicationsUpdaterTests.swift:~584`, `theAdministratorIsAskedOnceAfterTheDownloadIsVerifiedAndCancellingDeclinesWhileApprovingInstalls`. It expects the order `["downloaded", "asked", …]`, but `.downloaded` is reported before the unpack and the genuineness check, so the same order holds if verification were removed.
- Rule: the tdd skill's tests.md: a test proves the behaviour its name states.
- Fix: rename it to what it proves (asked once, after `.downloaded`, per T27). "Verified before the prompt" is proven by T25 (a not-genuine archive with a read-only "Applications" never asks); make sure T25's committed-fixture variants (b)-(f) all assert that the administrator was never asked, so together they prove R11's "after the download finishes and is verified, never before".

## 4. T25(f) cannot run once the fixtures exist

- Files: `Scripts/make-update-fixtures.sh:31` creates an empty `Contents/Resources` (git does not keep empty folders either); `ApplicationsUpdaterTests.swift:473-486` (`changeOneByteOfAResource`) then finds no file and throws.
- Rule: plan T25(f): "the committed fixture, unpacked, one resource byte changed, and archived again with release.sh's line … Then the events end with `.downloaded`, then `.failed`."
- Fix: the fixture script writes a resource file (e.g. `Contents/Resources/fixture.txt` with fixed contents) into the app before signing, so it is sealed. The test changes a byte of that file. Make the test fail with a clear message, not a thrown error, if the resource is missing.

## 5. T14 does not check the seeded record

- File: `LauncherKit/Tests/LauncherCoreTests/UpdateInstallTests.swift:~266` checks only `freshStore().load() != nil`.
- Rule: plan T14: the restored Mac "keeps the seeded record and the login item on, makes no login-item call and asks for nothing."
- Fix: compare the loaded settings with the seeded record, as T8 does (~line 94).

## 6. T21's committed-fixture row does not check the quarters

- File: `ApplicationsUpdaterTests.swift:394-398` releases all four quarters at once and checks only `progress.last == 1.0`.
- Rule: plan T21: "progress rises in whole percents and reaches 0.25, 0.5, 0.75 and 1.0 as each quarter is released, followed by `.downloaded`, then `.installed`."
- Fix: release the quarters one at a time and assert, after each, that the progress reported so far reaches that quarter, as the ad-hoc row at ~line 126 does. Share the helper rather than copying it. (S4 found that a tiny body held mid-stream is not counted until the next byte; the committed fixture is large enough, but if the assertion needs it, wait for the expected progress with a bounded wait rather than weakening it.)

## 7. The release preflight lets an equal version through (R14)

- File: `Scripts/release.sh:60-81` (`preflight`).
- Rule: R14: "A release MUST carry a version higher than every earlier release." Plan: "VERSION … is above every v* tag (sort -V) and every release, drafts included (gh release list)."
- Fix:
  - Compare the way the app does (`Version`: dotted whole numbers, trailing zeros dropped, part by part): normalise each version by stripping trailing `.0` parts before comparing, so `1.1` and `1.1.0` are equal.
  - Require strictly greater: fail when any earlier tag or release (drafts included, from `gh release list`) normalises to a version greater than **or equal to** `$EXPECTED_VERSION`. Exclude nothing.
  - Restrict `NUMERIC` (`release.sh:36`) to what `Version.init?` accepts: each part 1-9 digits (`^[0-9]{1,9}(\.[0-9]{1,9})*$`), so a release the script accepts is always one the app can parse. Keep `Scripts/make-update-fixtures.sh` consistent if it has the same check.
  - `bash -n` both scripts. Exercise the comparison logic offline by factoring it into a function you can call with literal lists (e.g. a `--check-version <version> <earlier…>` mode is not wanted; instead test the function by sourcing it in a throwaway shell in `/tmp`, not committed), and report the cases: 1.1.0 vs [1.1] refused, 1.1.0 vs [1.0.9, v1.1.0 draft] refused, 1.10.0 vs [1.9.0] accepted, 1.1.0 vs [] accepted.

## 8. Small duplications in shipped code

- `LauncherKit/Sources/LauncherPlatform/GitHubReleases.swift:34-37` and `59-62` set the same request fields (`httpMethod`, `timeoutInterval`, `cachePolicy`, `httpShouldHandleCookies`) twice → one private `request(for:stall:)` helper used by both.
- `LauncherKit/Sources/LauncherPlatform/CodeSignature.swift:77` and `:88` repeat the `SecCodeCopySigningInformation` read → one private helper.
- Rule: the standards reviewer's baseline (Duplicated Code). Keep behaviour identical; the existing rows must still pass.

## Not fixed (decided; for your information only, do not change)

- `theNetworkBansAreAllStillListed` is a literal list, not a copy of `banned`; it is the plan's self-check as designed.
- `Copy.cancelButton == "Cancel"` and the long T8 body: T8 is a scenario row that the plan writes as one run, and the plan asserts the strings verbatim.
- `cache-control: no-cache` allowed in T19/T24: system-added by the cache policy, constant on every Mac; recorded as a deviation in the development log.
- `--archive-only` in `release.sh`: asked for by the slice brief, so the archive step can be checked without credentials.
- The vacuous pass in `CodeSignatureTests` on a Mac with no Developer ID app, `developerIDSigned: Bool`, `UpdateCard.Layout`, the updater travelling with the launcher, the `aa archive` line in two scripts, and the `ApplicationsUpdater` name: plan decisions or pre-existing patterns.

## Done when

- [ ] Item 1: root cause stated with evidence; fixed; every waiting test bounded; three capped full-package runs green in a row, each well inside the cap.
- [ ] Items 2-8 done; the rows they touch pass (fixture-dependent rows still skip clearly).
- [ ] `xcodegen generate` and `xcodebuild -project TrackpadLauncher.xcodeproj -scheme TrackpadLauncher -configuration Debug -derivedDataPath /tmp/tl-022-dd build CODE_SIGNING_ALLOWED=NO` succeed (from the worktree root), with no new warnings.

Report back: the hang's root cause and evidence, what you changed for each item, any departure and why, and the three runs' summary lines with durations.
