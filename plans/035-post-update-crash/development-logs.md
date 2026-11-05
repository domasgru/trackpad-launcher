# Development logs: A new copy survives stopping the copy before it

## Specify
- (none logged)

## Plan
- T1 stopped one copy, which cannot tell a correct release order from a wrong one: the main-queue block that completes the stop captures the last application, so an application-first watch survives a one-copy stop and crashes only on the first copy of two → T1 stops two copies. Launching one bundle twice, or two bundles under one identifier, from one `NSWorkspace` client was measured to queue the second launch behind the first's 30 s completion, so the pair is a release copy and a Debug copy (the fixture's identifier and its `.debug` twin, the one family), each launched by its own `open -g` process; an acceptance criterion flips the watch to application-first and expects the crash at completion, which the prototype confirmed.
- `repro.sh` counted any surviving pid as alive, so it observed neither the old copy's exit nor the new copy's resident → the slice extends it: a round passes only when the old pid is gone and the new pid's `lsappinfo info -pid` type is `Foreground`; the plan says the run confirms T1 at the whole-app level and is not a second proof of R1.
- The strategy said the bounded-await helper "lets the run loop spin", which it does not; it only suspends → verified in a throwaway Swift Testing package that a main-actor test runs on the main thread, that a run-loop timer fires while it awaits and that the LaunchServices exit push arrives on the main thread under `swift test`; the plan now rests on the harness and records the evidence.
- The bound on `exited` was unstated, so a bound longer than the fixture's life would let a `stop` that never force-terminates pass on the script's own exit → the helper's default 30 s is named and the fixture lives about two minutes.
- "Exactly once" and "on the main actor" were not observable through the helper, which wakes the test once → `exited` records its call count and thread inside itself.
- `kill(pid, 0)` succeeds on a zombie and launchd reaps the fixture, so a check straight after the push could flake → re-read for up to 2 s.
- T2's "macOS already lists it as gone" was unproven → the prototype showed a fresh `NSRunningApplication(processIdentifier:)` nil and the family's list empty right after the push, and T2 now requires `others()` to be empty before calling `stop`, so a miss reads as a failed precondition.
- The leftover check used `pgrep -f` on the script's sleep, which after `exec` matches any process's sleep and never the fixture → the script loops over `sleep 1` without `exec`, so its argv names the bundle and `pgrep -f` on the bundle's path is the independent pid read; the leftover check goes through `lsappinfo list` by identifier.
- The red check named a stack ending in `removeObserver:forKeyPath:`, which rejects the SIGABRT form, where the thread ends in the exception throw → the check names AppKit's dealloc-with-observers line and `NSKVODeallocate` with `removeObserver:forKeyPath:` in the thread's stack or the exception backtrace.
- Two mechanisms for one invariant (explicit invalidation at completion plus the deinit), with an optional and a flag → the optional and the flag went (`let observation`, Foundation's `invalidate()` is idempotent); both the explicit invalidation and the deinit stay, the explicit one as the mechanism the reader sees and the deinit as the guarantee on the one path completion does not cover, a later `stop` replacing the set.
- Not taken: splitting the end-to-end run into a requirement of its own under Verified without a test. It confirms R1's route at the whole-app level and is kept as a slice acceptance criterion; T1 remains R1's proof.
- Found while fixing the above, not by the review: `NSWorkspace.openApplication`'s completion for a script app arrives only after LaunchServices' 30 s launch timeout → the test does not await it at all; it launches with `open -g`, waits briefly for `others()` to list the pair, and takes the pids from the process table.

## Implement
- (none yet)
