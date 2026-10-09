# Check: a test process may post `com.apple.tcc.access.changed`

Gathered after fan-out (so recorded here, not in the frozen grounding). Probe: `checks/notify-post-probe/main.swift`, output `checks/notify-post-probe/output.txt`, run 2026-10-09 on the development machine from an untrusted process.

- **probed:** `notify_register_dispatch("com.apple.tcc.access.changed", ..., DispatchQueue.main)` returned 0; `notify_post("com.apple.tcc.access.changed")` from the same ordinary process returned 0 (`NOTIFY_STATUS_OK`, not 12 `NOTIFY_STATUS_NOT_AUTHORIZED`); the registration received the notification 6 ms later on the main thread.
- **conclusion:** the Darwin name is not restricted. A `LauncherPlatformTests` test can drive the real permission adapter's push path by calling `notify_post` itself, with no `tccutil`, no TCC change and no permission, and assert the adapter's main-actor callback arrives within the bound. It cannot change the trust value; the adapter under test will re-read `AXIsProcessTrusted()` and see no change, so the test asserts the push arrived (or that the adapter reports "no change"), not a flip. This is the handle the test planner needs for R7's platform-level test; the flip itself stays manual.
- **side effect noted:** posting the name wakes every listener on the Mac (any app observing TCC changes re-reads its trust). Harmless; the test posts it once.
