# Task: design plan 021, Trackpad Launcher as a background app with a settings window

## The artifact

One design package for plan 021, shaped per the **Design package template** in the shared design reference
(`/Users/dominykasgrubys/code/skills/plugins/dev-workflow/references/design-reference.md`): Problem, Usage (caller's
view, written first), Shape (data structures first, then the type sketch in Swift with `fatalError("not implemented")`
bodies, `// TODO` pseudocode for tricky logic, doc comments stating intent and invariants, and a module map), an empty
Synthesis decision section, Tradeoffs accepted, Alternatives considered, Open questions and risks, Next implementation
step. Prose about one page; the type sketch can be as long as the design needs. Write it to your output path and
nothing else.

## Inputs

- Requirements: `plans/021-background-agent-lifecycle/plan.md` (R1-R25 with scenarios, non-goals). The requirements
  are fixed; do not redesign the product.
- `docs/architecture.md`, `docs/domain-model.md`, `docs/performance.md`, `docs/product-overview.md`.
- Grounding: `plans/021-background-agent-lifecycle/.temp/architect/grounding/`. Start from `index.md`: it lists every
  fact with its standing (probed / sourced / disputed) and the open questions. `how.md` is the traced model of today's
  code; `why.md` ends with the Preserve / Change / Avoid / Risk constraint set your design must answer. Read the
  sources and probe outputs the index cites where a decision of yours rests on them, and the current code the design
  touches.

## What the design must address

Cover every requirement R1-R25. These are the decisions where the shape is not obvious; your package must take a clear
position on each and show it in the types and signatures, not only in prose:

1. **What a process does when it starts and when it is opened again.** Login start, opened by hand from /Applications,
   opened by hand from elsewhere, a development build, the first run, other running copies (the menu bar version
   included). Where this decision lives, what it reads, and how a test drives it.
2. **One Trackpad Launcher at a time** (R2, R3, R20): reopening the running copy, replacing a different build or a copy
   from another place, stopping the running copy before replacing it, the old menu bar version included. Waiting for a
   process to end without timers or polling.
3. **The settings window, the Dock and quitting** (R1, R6-R8, R10, R11): activation policy, the main menu (*Close
   Settings* ⌘Q), ⌘W, Escape, the Dock's Quit, logout/restart/shutdown never held up, the Quit button really quitting,
   the window centred on the pointer's display, minimised included.
4. **Starting at login** (R5, R9, R12-R14, R22, R25): silent start at login and after "Reopen windows", registering on
   the first run from /Applications, Quit turning it off only when it was on and turning it back on only when Quit did,
   never overriding the user's Login Items choice, upgrades keeping it as it was.
5. **The window no longer closes on effects, Other… and System Settings** (R15-R17), and **the frontmost app while
   Trackpad Launcher is active** (R15): the switcher's row and the swap work from the app that was in front before it.
6. **Moving into /Applications** (R18-R21): the dialog gate before anything else happens, copying or replacing,
   removing the original, the disk image ejected, the administrator prompt and its cancel, translocation, and what
   happens if any step fails or the process dies halfway (state must converge on the next run).
7. **Development builds** (R23): how a build knows it is one.
8. **The release disk image** (R24): one command from the repository to a signed, notarised, stapled disk image with
   the drag-to-Applications cue, within the distribution rules.
9. **What changes in the docs** (`docs/domain-model.md` glossary entries, `docs/architecture.md` only where a
   codebase-wide rule changes) and which source-scan rows change.

Name the seam the requirement scenarios run at and give tests a handle on every signal they cannot provoke for real
(see the index's "What a test can produce for real" section). Where the design rests on an open question from the
index (notably the login-launch marker, the Login Items status after a user's choice, and the logout signals), say so
and name the fallback.

## What the human asked for

The human's instruction was "proceed" with the plan as written. The project's standing guidance: give little weight to
development cost; prefer quality, simplicity, robustness, scalability and long-term maintainability.
