# Rubric: gating the event tap (plan 014)

Success looks like this: a design in which the process is sent none of the high-volume event types while nothing may need blocking and nothing is in flight, every verdict the shipped build gives is given the same way (including the fingers-first-then-thumb scroll and the accepted landing races), nothing ever reaches apps half-blocked, the lifecycle paths (run, revoke, hot-plug, wake, settings, system timeout) behave as today, the gate's choreography across the frame threads and the tap thread is serialized structurally with every field's writer named, the policy is a pure core type the behavioural suite can model, and the diff is the smallest that delivers all of that.

Score each criterion 0-3 (0 fails it, 1 partially, 2 meets it, 3 meets it and makes a future change easier), with one line of evidence from the candidate.

## C1. The gate is exact: R1 and R3 hold by construction

The gate's predicate is stated as a pure function of named inputs (which recognizer states, which filter memories) and the candidate shows, case by case, that: no 6/7/27/34/22/29/30 event is delivered while every recognizer is outside the may-block states and every filter holds nothing withheld or altered (R1); a withheld press's drags, pressure and release, a dropped or stilled scroll's remaining events and momentum, and a dropped Dock swipe's remaining events keep reaching the filters until each ends, however long after the recognizer went idle (R3); and the window in which an event can pass unseen at a gate opening is named and bounded, with what the filters do with the events that follow it.

## C2. Verdicts are unchanged: R2 including its races

Every outcome the shipped build gives is shown to be given the same way, or the candidate names the exact case that differs and why it is unobservable. The cases that must be covered explicitly: the press sampling rule (`.nothing` + button down reads nil), so a press the filter never saw cannot leave "a click and a gesture"; the fingers-resting-then-thumb-lands-then-fingers-move scroll (today stilled, since the `mayBegin` was seen as passed); the thumb and a finger landing on the same frame; a thumb under resting fingers; a scroll suppressed before the 3 s mark that coasts past it; the system's own disable (timeout) recovery under-blocking as today.

## C3. Threads and shared state are disciplined

Every piece of shared mutable state is listed with its one writer and its readers, or, where the gate genuinely needs two inputs from two threads, the serialization is structural (one lock, one owner of `tapEnable`, or a signal to a single owner) and the candidate answers "what happens if both change at once" for the verdict-drops/filter-commits race. `tapEnable` is never called in a way the probes showed to be slow or unsafe; our own disable's `tapDisabledByUserInput` echo cannot re-enable a tap the gate wants off; per-frame work on the frame thread is a compare, not a call; no timer, polling or display link.

## C4. Depth: a small interface over the whole choreography

The gate's policy is a pure, clock-free value type in `LauncherCore` with an interface of a few members, and the platform adapter hides the two-thread choreography, the port, the echo handling and the enabling behind the existing `TrackpadHardware.run` contract, so the model and the composition root change not at all or by one flag. No framework type crosses a port; no pass-through methods; no second copy of a rule (the may-block predicate, the in-flight predicate) outside its owner. Judged by what callers no longer need to know, not by line counts.

## C5. Testable at the behavioural seam, with the gating modelled

The candidate names the handle the in-memory adapter gets so the existing suite runs unchanged with the gate modelled (events reach the filters only while the gate is open) and a test can tell "never delivered" from "passed", gives the pure gate its own unit seam, keeps `TapEventTests` able to pin the mask(s), and names honestly what remains manual (the Release-build CPU measurement, the hardware checks on real scroll, Dock swipe and timeout behaviour) and what a fake must stand in for.

## C6. Lifecycle parity and minimal change (R4, R5, laziness)

`run`/reconcile, Accessibility revoke, hot-plug, wake, hand-mode and setting changes leave exactly the taps and in-flight state the shipped build would; transitions are idempotent (running twice converges); the `docs/architecture.md` sentence to replace is identified (R5) and any architecture rule the design bends (one writer per Mutex, nothing on the frame thread enables or disables the tap) is named with the reason rather than silently broken. The diff is the smallest that delivers R1-R5: no new ports unless two adapters exist, no new threads unless justified by a measured need, nothing specified that no requirement asked for.
