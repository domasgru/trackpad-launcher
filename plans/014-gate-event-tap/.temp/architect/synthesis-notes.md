# Synthesis notes (architect's own screen and scoring, written before the cross-judge reported)

## Convergence

Both candidates, independently: two active session taps on the one tap thread (a press port over 1, 2, 3, 4, 25, 26 always on; a gated port over 6, 7, 27, 34, 22, 29, 30); one ordered level per frame replacing the two Bools (`none < possible|watch < dockSwipes < clicks`), so the invariant is a construction; the tap thread as the sole caller of `tapEnable` on the gated port, woken by frame threads on a change of their level; a pure core predicate "some trackpad wants the tap, or a press is withheld, or a scroll is dropped/stilled through its momentum, or a Dock swipe is dropped"; an `.unseen` scroll stage at a reopening; the Dock filter kept at nil semantics pending D2; a fake that tells "never delivered" from "passed"; the same R5 sentence; the same accepted lingering coast. That is the consensus shape and it ships.

## Red-flag screen

- Candidate 2: `TapGate` is four Bools and an OR (shallow); the settle rule (read inputs, compare, forget at reopening, enable) lives in `ClickTap.applyGate` and again in the fake's `settleGate` (information leakage: one policy in two places, the real one untestable without trust). `GateLedger` is extra state standing in for a fact the port can be asked (`tapIsEnabled`).
- Candidate 1: `TapContext.init(need:)` hides the "a scroll may be under way when fingers are down beside the thumb" estimate in an initializer (make it a named constructor). `CFRunLoopPerformBlock` per transition allocates a block and does not coalesce (idempotent, so harmless; a version-0 source is cleaner). No shallow module, no temporal decomposition, no pass-through.

## Scores (0-3)

| | Candidate 1 | Candidate 2 |
|---|---|---|
| C1 exact gate | 3: `settle` predicate; `.watch` on thumb-alone and unconfirmed slides; the open-latency window named with the filters' rules for what follows | 3: `TapGate.isOpen`; `.possible`; window named |
| C2 verdicts unchanged | 3: press port keeps the press rule by construction; the three press races traced; C11 stilled on hardware via the estimate; `SwapTests:324` kept via the fake's exact knowledge; timeout keeps nil for R4 | 1: claims every existing test unchanged, but `.unseen` at every reopening answers `.passStill` where `SwapTests:324` expects `.drop`; moves the post-timeout `began` row from drop to still |
| C3 threads | 3: writers named; sole owner; wake carries no data; notices reconcile by reading both ports' state (converges whatever arrived); per-frame compare | 2: same ownership and wake; echo counted in a ledger (tolerant, but a second kind of state for a fact the port can be asked) |
| C4 depth | 3: `TapFilters` hides routing, the gate, the reopen rules and the echo-versus-system logic behind three mutations and two reads; `ClickTap` shrinks to parsing, reading, switching | 1: the gate's policy split between a trivial struct, `ClickTap.applyGate` and the fake's `settleGate` |
| C5 testable | 3: the fake wraps the real `TapFilters`; `offer -> .noTap/.notSent/.decided`; `withLateWakes` makes the open latency visible; `systemDisablesTheTaps`; both masks pinned | 2: handles exist (`isTapListening`, `unseenByTap`, `gateOpenings`) but the fake re-implements the settle; no latency model |
| C6 lifecycle, minimal | 2: parity and idempotence enumerated; policy label reworded; `TapEvent` moves to core and three small types are added (needed to keep `TapFilters` pure, but a larger diff) | 2: parity enumerated; adds the `tapEnable` confinement (good); bends R4's "as today" on the timeout path |
| Total | 17 | 11 |

## Pick

Base: candidate 1. More behaviour behind the core seam the suite can drive; the press rule, the recorded races and `SwapTests:324` kept by construction; notices reconciled from the ports' truth. A future maintainer extends `TapFilters` (one pure value with one invariant) rather than two copies of a settle rule.

## Grafts from candidate 2

1. Names: `Blocking` with `.none / .possible / .dockSwipes / .clicks`, `Recognition.blocking`, `wantsTap`; `ScrollFilter.isSuppressing` (the domain's word is "suppressed").
2. The wake-up as a version-0 `CFRunLoopSource` created with the tap and signalled by frame threads (coalesces, allocates nothing on the frame thread), replacing `CFRunLoopPerformBlock`.
3. `SourcePolicyTests`: confine `tapEnable` to `ClickTap.swift`, so plan 002's checklist line is a build rule.
4. The gated port's convergent start: rather than "created enabled until the thread's first turn", `install` disables it on main right after creation (main is already the ports' writer at install and remove), so a fresh `TapFilters` is closed and the first `follow` opens it only if a trackpad already wants it; nothing queues before the thread runs. (Candidate 2 applied the gate before `CFRunLoopRun`; this goes one step earlier.)

## Rejected

- Candidate 2's echo-debt `GateLedger`: reading `tapIsEnabled` on both ports at a notice (20-47 µs each, checks/README) converges whatever number of echoes arrived and needs no counter.
- Candidate 2's `.unseen` at every reopening and for the timeout path: fails `SwapTests:324` (R2) and bends R4; candidate 1's "unseen only when a scroll may be under way" keeps both.
- Candidate 2's separate `TapGate` struct: the predicate lives in `TapFilters.settle`, beside the memory it reads.
- Candidate 1's `TapContext.init(need:)`: replaced by a named constructor for the estimate.

## Added from the checks

- Two-port ordering: strict at trackpad rates; lost only once a backlog builds (a stalled tap thread). A withheld press's first drags could then pass as plain drags. Recorded as a tradeoff; the same stall today ends in a timeout disable that under-blocks far more.
- The lingering coast after a dropped scroll that ends without momentum (every swipe whose fingers stop before lifting): the gated port stays on until the next scroll gesture, so pointing after a swipe costs today's amount until then. Within R1's letter; flagged as an open question with the event-timestamp proposal.
