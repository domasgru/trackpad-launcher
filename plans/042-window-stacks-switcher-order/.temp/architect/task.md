# Task: design plan 042 (window stacks, a stable window order, the no-windows card)

## The artifact

One candidate **design package**, shaped per the Design package template in
`/Users/dominykasgrubys/code/skills/plugins/dev-workflow/references/design-reference.md`: Problem, Usage (caller's view),
Shape with the type sketch (Swift, `not implemented` / `fatalError("not implemented")` bodies and `// TODO` pseudocode),
an empty Synthesis decision, Tradeoffs accepted, Alternatives considered, Open questions and risks, Next implementation
step. Prose about one page; the type sketch may be as long as it needs to be. Name modules (`LauncherCore`,
`LauncherPlatform`, `LauncherUI`, the app target) and types, not file paths. Write it to your output path and nothing else.

## Inputs

- Requirements: `plans/042-window-stacks-switcher-order/plan.md` (R1 to R13 with scenarios, Non-goals). The design must
  carry every requirement and let every scenario be driven through its signatures.
- Grounding: start from `grounding/index.md` (facts with their standing, sources, test realities, open questions), then
  `grounding/how.md`, `grounding/why.md` (its Preserve / Change / Avoid / Risk set is a constraint set), the four
  `grounding/how-*.md` explorer files, and the probe outputs in `grounding/probes/`. Read the code they cite wherever a
  decision rests on it.
- `docs/architecture.md` and `docs/domain-model.md`: the design must keep every architecture rule (three models own every
  decision; ports with exactly two adapters, real and in-memory; framework and wire types never cross a port; `LauncherCore`
  imports Foundation and Observation only; no timers, polling or display links; time passes on Core Animation's clock;
  AX and the window list confined by the source-scan test; off-main work in explicitly concurrent functions; async
  adapters behind ports so model tests stay synchronous), or name the rule it changes and why, as a doc change.

## What the design must address

1. **Window counts for the stacks (R1 to R4).** How, when a swipe begins, the window counts of the row's apps (up to 10,
   the frontmost app included) are read without the switcher waiting (R4), each app independently so one slow or hung app
   delays no other, each within a 0.2 s per-app deadline after which that app shows its icon alone for the whole swipe,
   read once per swipe and fixed for it. Counts must equal what the window switcher would list for that app (R2: current
   Space, minimised included, full-screen front of the frontmost app counts as one, panels excluded), by construction, not
   by a second copy of the rule. Stacks show with the window swipe setting off; without Accessibility nothing is read (R3).
   Settle grounding open question 1 (hidden apps, F12): with *Hide background apps* on, most row apps are hidden.
   Name the port and its in-memory twin, where the deadline lives, and the handle a test uses to deliver an answer late,
   never, or within the deadline.
2. **Stacks on screen (R5, R6).** How counts reach the switcher view mid-swipe without rebuilding the row or replaying
   anything; the per-swipe identity the view keys on (grounding F33, F37); the stack geometry as a pure Core value beside
   `SwitcherRowLayout` (front icon unchanged, copies about 92/84/76 % peeking about 6 pt per layer, growing with the
   selected icon's 1.12 and shrinking with the row's scale); the rise (copies start exactly behind the front icon, rise
   about 0.3 s with a soft ease-out, about 40 ms stagger, once per swipe, when the count arrives, never replayed by
   selection moves, in place at once with Reduce motion) and how it coexists with the per-render implicit grow.
3. **A stable window order (R7 to R9).** The data structure and its owner; how an order is set by the first window swipe
   into an app, how a new window joins at the end, a closed one leaves, an off-Space window keeps its place and returns to
   it, a minimised one keeps its place, and the app quitting or Trackpad Launcher stopping forgets it (never saved);
   settle grounding open question 2 (F19, F21, F22). The R9 pick of ten. The selection starting on the front window's row
   (R8). The lift rules restated against the order: the selected window in front, restored if minimised, the window that
   was in front just behind it, the others as before; the gesture haptic only when the window in front changed or a
   minimised window was restored; never raise an id the latest read did not list (why Preserve 1).
4. **When a slide is a window swipe, and the card (R10 to R13).** The read result's cases (grounding open question 5), how
   the start's verdict is reached inside the `onEvent` call with the read held to 0.2 s, and what each case does: rows,
   the card (zero windows; one window; full-screen front), or a decline that is exactly the setting-off slide (no frontmost
   app, no answer within 0.2 s, a partial read). Settle open question 4 (Trackpad Launcher frontmost). The card's model
   case and copy (the exact strings are in R10), its silent lift with no side effect (no raise, no haptic, no hide),
   its silent cancel, and no preview capture. The card's offset (R11) as a pure Core mapping from the slide's travel:
   tracks the movement since the last change of direction, damped, clamped at 6 pt either way, turning at once; how the
   view holds it per frame and settles it back as the switcher goes; still with Reduce motion; no haptic.
5. **Tests.** Name the one high seam each requirement group's scenarios run at, and give tests a handle on everything
   they cannot wait for or provoke: the deadline's clock, the count answers (late, never, partial), app quit, window
   open/close/minimise/Space moves in the fake. Say which existing tests the design inverts (grounding F24, F27 and
   `G/why.md` Change 2).
6. **Docs.** What `docs/domain-model.md` and `docs/architecture.md` must say once this lands (the Accessibility use
   statement, off-main AX, the AX confinement, model-held window order).

## What the human asked for (verbatim, for intent)

"i want you to implement few things related to our apps switcher and window switcher:
- app switcher line should indicate the apps with multiple windows. If app has multiple windows, that stack of icons should
  be shown, amount of icons in the stack shows how many windows.
- then window switcher dropdown shown in the top left part of the screen should persist the apps order. For example if i
  swipe to the last item, and open the last app, when i go to window switcher again, the last item should be selected
  (currently the first item is selected, because the selected item goes to top).
- if app does not have windows, the dropdown should still show card, telling that app doesn't have multiple window (think
  of the best copy yourself) and it should slightly and subtly react to swips app and down, like slightly move to that
  direction, but it should be capped"
"also, the icon stack should animate slightly, specifically the items that are behind the main item should animate from
bottom (same height as first item) to go up, with clean, subtle easing."
"after plan go ahead without my input"

The human will not answer questions before implementation: where the requirements or grounding leave a choice open, make
it, state it in Open questions and risks as the default taken, and design so it is cheap to reverse.
