# Rubric: plan 021 design packages

Success for this task: a design a future maintainer can extend without breaking the lifecycle invariants, that carries
every requirement R1-R25 through concrete types and signatures, rests on what the grounding actually established, and
keeps the codebase's existing rules. Score each criterion 1-5 per candidate, with the evidence (section, type or
signature) behind the score.

## C1. Requirement coverage, traced through the sketch
Every R1-R25 and its scenarios can be followed through named types, functions and state in the sketch, not only
prose. The hard ones get explicit mechanisms: R3 (different build / other place, the menu bar version), R8 (Dock Quit
vs logout), R9 (silent login start and "Reopen windows"), R12/R13 (Quit's login state vs the user's choice), R15
(frontmost app while Trackpad Launcher is active), R18-R21 (gate, move, replace, eject, admin cancel), R23, R24.
- 5: every requirement traced; no scenario contradicted.
- 3: most traced; one or two hard ones hand-waved.
- 1: several requirements missing or contradicted.

## C2. Depth and a testable seam for lifecycle policy
The launch / reopen / quit / move decisions live behind a small interface that hides real policy; the scenarios run
synchronously at one named high seam (the model and `World` style harness, or an equally strong one), with an
in-memory adapter for every signal a test cannot provoke (how the process was started, other running copies and their
termination, login-item status, the dialog's and admin prompt's answers, activation). No shallow modules, pass-through
methods, or callers coordinating several calls to finish one operation.
- 5: one clear seam per concern, small public surface, each fake named; policy is pure or model state.
- 3: testable but the surface is wide or some policy sits in the untested shell.
- 1: key decisions only reachable through AppKit or untestable.

## C3. Fidelity to the grounding and robustness
Decisions agree with the probed and sourced facts (e.g. F1 Apple-event timing, F4-F6 LaunchServices routing, F15-F18
quit events and sudden termination, F22 SMAppService status, F31-F34 authorization and translocation). Where a decision
rests on an open question (login marker, Login Items status, logout signals, translocation), the design says so and
names its fallback. Multi-step operations (move, replace, Quit's login change, first run) converge if they run twice or
the process dies halfway.
- 5: no contradiction with a probe; every open dependency has a fallback; crash-convergence argued per operation.
- 3: minor reliance on an unverified claim without fallback, or one non-convergent step.
- 1: contradicts a probe or rests on an unworkable mechanism (e.g. a restricted entitlement, a timer).

## C4. Respect for the codebase's rules and history
`docs/architecture.md` (model owns decisions; LauncherCore imports Foundation and Observation only; every port has
exactly two adapters; pushes only, no timers or polling; source-scan bans and confinements) and the `why.md`
constraint set (first run stays derived from the absence of a record; no second "launched/prompted" flag; never
re-enrol a user who turned login off; window state stays model state; no `terminate`/`openURL` closures in the model).
Necessary changes to a rule are named and justified, with the doc and source-scan edits listed.
- 5: no silent violation; each deliberate rule change argued.
- 3: one silent violation or an unargued rule change.
- 1: several violations.

## C5. Ownership, locality and reader load
Each new concern has one owner (no temporal decomposition such as a "launch stage" split across files that repeat the
same rule); one source of truth per invariant (the frontmost memory, the login-state marker, "first run", "is a
release build", "where am I"); the composition root and the AppKit shell stay thin; tracing a scenario needs no more
than about three files; the existing `Launcher` does not absorb unrelated lifecycle concerns without a reason.
- 5: a newcomer can say where each rule lives and what can change it in under a minute.
- 3: one concern split or duplicated.
- 1: rules scattered across shell, model and adapters.

## C6. Release tooling
R24's one command builds a Developer-ID-signed, notarised, stapled disk image with the drag-to-Applications cue from a
clean checkout (including project generation), keeps the distribution rules (no `--deep`, main executable last,
hardened runtime), staples what users actually open, and needs no unvetted network dependency beyond notarisation.
- 5: complete, ordered, verifiable steps with the cue's production settled.
- 3: workable with a gap (e.g. the cue or the app's own ticket).
- 1: missing or not one command.
