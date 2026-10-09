# Rubric: click blocking and forgiving taps

Success looks like this: a future maintainer reads one `Launcher`, one recognizer and two small new ports and can say, for any press on any trackpad, whether it is dropped and whether the tap still fires, and can prove it with synchronous tests that never wait on a permission, a timer or hardware. The design keeps plan 001's shape (one model, ports with two adapters, pure policy in core, frame clock only, rules as structure) and adds exactly what R1–R11 ask for.

Score each criterion 0–3 (0 missing, 1 partial or contradicted elsewhere in the package, 2 met, 3 met with the invariant encoded in types or structure rather than prose).

## C1. Requirement trace

Every R1–R11 is carried by a named mechanism in the sketch, and every scenario can be traced through the usage and the signatures to the seam it runs at (recognizer, `Launcher`, a pure decision function, a platform adapter test, or manual). Nothing in the sketch serves no requirement. The non-goals (no pointer/scroll blocking, no grace delay, no setting, no feedback on a blocked click, fixed 3 s) are respected.

## C2. Interface depth and seam placement

The public surfaces are small and hide the complexity: the tap, the permission and the blocking decision sit behind ports or pure functions whose interfaces a caller learns in a sentence. No framework or wire type (`CGEvent`, `CFMachPort`, notify tokens, AX calls) crosses a port; `LauncherCore` still imports only Foundation and Observation. Each new port has a real adapter and an in-memory one. No pass-through layer, no temporal decomposition (install/arm/decide/tear-down split by time instead of by knowledge), no information leakage (the 3-second rule and the finger-set rule live in one place). The existing `Launcher`, `reconcile()`, `fire()` and the port pattern are extended, not bypassed.

## C3. Correct under concurrency and time, with zero idle cost

The blocking decision is derived on the frame clock with no timer and no polling; the state shared between the frame thread and the tap callback has one writer behind a `Mutex`, is combined across trackpads, and is reset on `run`. The callback's run loop is named and the `tapDisabledBy...` notices are handled. The whole-press rule uses the event number. R8 holds whichever way `buttonState` reports a dropped press. Trust changes arrive by push (the Darwin notification) and the tap is torn down by the app on revoke. The package states what happens on reconcile mid-anchor, on wake, and on repeated reconciles (idempotent).

## C4. Testable at a high seam, synchronously

A test can drive every non-hardware scenario at the `Launcher` seam or the recognizer seam with authored frame timestamps, set the permission state through an in-memory port whose setter fires the callback, observe the per-frame blocking decision and the tap's pass/drop decision, assert the prompt was requested once, and exercise the real permission adapter's push with `notify_post`. Which scenarios are manual is stated and minimal. The fixtures named exist or are sketched (`TouchScript`, `HandFrames`, `World`, the in-memory adapters).

## C5. Robust to the open questions and consistent with the rules

The design degrades correctly if the grant notification does not fire (no timer; trust re-read at existing pushes), if a bouncing finger gets a new ID, if Force Click needs the pressure type dropped (mask extensible in one place), if a dropped press reads as down. `SourcePolicyTests` is revised precisely (only the Accessibility and tap tokens the design uses are unbanned; IOHID, Input Monitoring, timer and polling tokens stay; a self-check guards the list) and the `docs/architecture.md` sentence that changes is named. The design records its own risks (the landing-frame vs click race, Debug/Release TCC clients) rather than hiding them.

## C6. Usage first, sketch agrees, reader load low

The usage section was written first and the type sketch agrees with it (every call in the usage exists in the sketch with the same shape). Tricky logic (the predicate, the whole-press rule, the recognizer's new counting) is shown as pseudocode. Tracing a press from the tap to the recognizer and a trust change to the hint takes no more than three modules each.
