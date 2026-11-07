# Development logs: Window stacks, a stable window order and the "no other windows" card

## Specify
- Overview ordering clause would go stale → Documentation section now rewrites it to the app's window order.
- One-window card text was false for full screen → second line reads "‹App› has no other windows on this desktop."; text styles stated.
- R11 card motion ambiguous → offset tracks movement since the last change of direction, damped, clamped at ±6 pt.
- "Does not answer" undefined → 0.2 s deadline in R4 and R13; slow, never-answering and closing-window scenarios added; "blocking window" jargon replaced.
- R7 listed causes instead of an invariant → only open, close, app quit or Trackpad Launcher stop change the order; off-Space windows keep their place.
- R2 full-screen rule ambiguous for other apps → applies to the frontmost app only; helper-panel scenario added.
- R3 heading and justification fixed; R4 "exactly as soon" → "MUST NOT wait for any window count".
- Added middle-row, restored-minimised and narrow-display scenarios.
- Non-goals gained "Stable rows above ten windows" and "Window previews on the card".
- Rejected: making stacks follow the window swipe setting (user chose always), splitting R5/R7.

## Plan
- Arena: two candidates (Opus, Fable), no dropout; they converged on one whole shape (three-case read, one count rule, URL-keyed order with no quit push, rows-or-card sum, per-swipe serial, GCD per app with per-element budgets, slot containers) → shipped that shape with candidate 1 as base. Candidate 1's runner reported reading the rubric → noted; the judge's independent score and factual differences decided the pick.
- Red-flag screen: candidate 2 split the order's update across `Body.init?(…, orders: inout)`, `reconcile` and a side-effecting `runningApps()` wrapper (leakage, temporal coupling) → one writer, `WindowOrders.list`.
- Cross-judge: candidate 1 at 29/30 against 25/30 → base candidate 1.
- Cross-judge: candidate 1's copy rise formula halved the 6 pt peek → candidate 2's `peek × layer × scale + (icon − side) / 2`.
- Cross-judge: candidate 2's single `optionAll` copy for order was falsified by check C2 (order differed in 20/20 samples) → order from the on-screen copy only.
- Cross-judge: candidate 2's `retain(running)` forgot menu-bar apps' orders → rejected.
- Cross-judge: candidate 2's budget started inside each block with no end check → one `ReadBudget` stamped at the call, with `admits(endedAt:)`.
- Cross-judge: per-slot `[Int?]` counts left "fixed once answered" to convention → grafted `WindowStack` and `SlotStack`; grafted the fake's `Answering` (`.now`, `.held`, `.never`).
- Cross-judge: candidate 1 declined a whole read on any error → today's rules: a per-window failure other than `cannotComplete` skips the window; no value on `kAXWindows` is no windows.
- Verify: both candidates copied the full window list in every read (2.4 ms, main actor, ten times per swipe) to tell closed from off-Space → check C3 showed a targeted `CGWindowListCreateDescriptionFromArray` costs 0.19 ms → `openWindows(among:)`, asked only when a remembered window is missing; `elsewhere` removed.
- Verify: per-element timeouts on GCD threads were assumed → check C1 probed them working.
- Verify: `NSRunningApplication` thread safety unprobed → processes resolved on the main actor before dispatch.
- Verify: R10's "two lines" cannot hold its own copy in a row's 200 pt column → default: the message wraps when it must; flagged as an open question.
- Test planner (pass 1): presenters needed a `Launcher` that `LauncherUITests` cannot build → `init(reduceMotion:)`, `observe(_:)`, `render(_:)`.
- Test planner (pass 1): the read's deadline was untestable → internal `WindowCalls` seam with a scripted double; `readEach` takes `readOne`.
- Test planner (pass 1): `ReadBudget.timeout` at the deadline was ambiguous, and a zero timeout means the global 0.2 s → nil at or past the deadline, never zero.
- Test planner (pass 1): the whole-read 0.2 s also declines a cold frontmost app's first slide → recorded under Tradeoffs.
- Test planner (pass 1): resetting an empty order to today's list broke R7 (no windows, or all closed, then new ones) → orders keyed by an opaque `AppLaunch`; new windows always join at the end.
- Test planner (pass 2): `WindowCalls` lacked the frame fallback → `listedWindows(of:)`; a non-`cannotComplete` number failure falls back to the frame match; T14 gained the clause.
- Test planner (pass 2): `launchDate` is nil for apps launched outside LaunchServices → `AppLaunch` from pid plus `sysctl`'s process start time.
- Phase D: the requirements' Documentation section was orphaned when docs moved out of the slices → `docs/product-overview.md`, `docs/domain-model.md` and `docs/architecture.md` (Concurrency, Privacy) written in Phase D.
