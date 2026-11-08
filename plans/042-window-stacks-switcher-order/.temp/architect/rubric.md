# Rubric for plan 042's candidates (the picker's tool; runners do not see it)

Success for this task: a maintainer can add the three behaviours without the switchers' existing invariants loosening
(nothing off-Space raised, a declined slide equals the setting-off slide, no timers, nothing waits on another app on the
main actor or the frame thread), each new rule lives in one place, and every R1 to R13 scenario can be driven in
`swift test` except what only real AX or real pixels can show.

Score each criterion 1 to 5 with one line of evidence.

1. **Requirement fidelity.** Every R1 to R13 and each scenario is carried by the usage and the signatures, including the
   edges: two copies of one bundle in the row; the frontmost app's full-screen front counting as one; a partial or late
   frontmost read declining (R13); Trackpad Launcher frontmost; hidden apps; the R9 pick ordered by the app's order; the
   restored-minimised scenario of R8; a window opened mid-swipe; lift and cancel on the card silent with no hide.
2. **Interface depth and seam placement.** Small public surfaces that hide real policy: one count rule shared by the stacks
   and the window switcher (R2 by construction), one order type owning the order's whole lifecycle, the card's offset and
   the stack geometry as pure Core values. No pass-through layers, no AX, pid or framework types across a port, no shallow
   port with several calls a caller must sequence. The model still owns every decision; the shell renders.
3. **Concurrency and failure behaviour.** The switcher never waits; one hung or slow app delays no other; the 0.2 s per-app
   deadline is enforced without a timer and cannot let a late answer through; answers for a swipe that ended, was
   cancelled, was replaced by a reconcile, or for the next swipe are dropped; the window swipe's start stays synchronous
   and bounded; nothing shares mutable state across threads without one writer.
4. **Order invariants and state economy.** The window order's invariants hold under open, close, minimise, restore, Space
   moves, app relaunch and Trackpad Launcher restart, with memory bounded; raises still name only ids from the latest read;
   the lift's rules and haptic are restated against the order without breaking 012's lift-from-a-second-read; the least
   new model state that carries R7 to R9.
5. **Testability.** Each requirement group has one named high seam; tests hold a handle on the deadline's clock, on late,
   never and partial answers, on app quit and on window changes in the fake; pure values are unit-testable; the rise and
   the card's motion are checkable at the layer level with Reduce motion injected; inverted existing tests are named.
6. **Rendering fit.** Stacks change neither the row's spacing, the highlight nor the panel's size; the rise plays once per
   swipe at the count's arrival and survives the per-render 1.12 implicit grow; the card holds its capped offset while
   the fingers hold and settles as the switcher goes; Reduce motion handled; no per-display-frame code; the card's text
   fits.
