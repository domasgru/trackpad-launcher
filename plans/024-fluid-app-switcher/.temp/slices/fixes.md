# Fixes after review: plan 024, the liquid app switcher

The branch `feature/024-fluid-app-switcher` is complete and green: `Scripts/test.sh` runs 595 core, 149 platform and 10 UI tests, and the Debug app builds. An implementation review against `main` found the items below. Fix each one as decided. Paths are under the worktree root `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/024-fluid-app-switcher`. Work test-first wherever a test can show the problem: reproduce it in a test, watch it fail, then fix.

Every fix must keep these rules:

- `docs/architecture.md`, Concurrency: "No code of ours runs per display frame, and display links are banned along with timers." No timers or polling anywhere in `Sources`.
- `docs/architecture.md`, Shape: "`LauncherCore` … imports Foundation and Observation only".
- `docs/architecture.md`, Privacy: the glass mirror is "found by class name and matched to the views by frame, then given only public Core Animation animations, confined to one file by the source-scan test". `CASDFElementLayer` stays in `GlassMirror.swift` only.

## F1 (serious): rows of three apps or fewer get no motion, and every hide re-runs the pre-warm

- **Where:**
  - `LauncherKit/Sources/LauncherUI/SwitcherPanel.swift`: `checkMirror()` about lines 66 to 71, `emptied()` about lines 159 to 169, and `prewarm()`;
  - `LauncherKit/Sources/LauncherUI/GlassMirror.swift`: `matched`, `match` and `isLive`.
- **What happens:** S3 found that laying out the band narrow, at 200 pt or less (a row of three apps or fewer), makes AppKit rebuild all twelve `CASDFElementLayer`s as new objects. The match from the pre-warm then goes stale, and `checkMirror()` returns false. The swipe falls back to the jump look, and `emptied()` re-runs the pre-warm on every hide. Rows that short are common, because apps with gestures are left out of the row.
- **Rules it breaks:**
  - R5, R6, R8, R9 and R10 all go unmet for these rows ("When the selection changes, the swell MUST flow …", and so on).
  - R16: "While the liquid is settled and while the switcher is hidden, the liquid MUST NOT redraw or run animation work." The pre-warm orders the window front while it is hidden.
  - Plan D2 states the mirror's identity holds for the fixed set of views.
- **Fix decided: re-match per swipe when stale, and require a unique match only for the views that animate.**
  1. **Reproduce first.** In `Tests/LauncherUITests/SwitcherPanelWindowTests.swift`, add a real-window row. Lay out, present and check the panel for rows of 3, 2 and 1 icons, each after a swipe of five icons. Apply a flowing frame from a real `Liquid(.flowing)` that steps to icon 1 (for one icon, use a move that stages swell tracks, such as an end pull). Expect `checkMirror()` to be true and the swell's element, found by the test's own walk, to carry the swell tracks. It should fail today on 3 and 2.
  2. **Match only what animates.** `GlassMirror` gets a match where only the views that animate must each match exactly one element within 0.5 pt: the swell and the real beads 0 ..< `iconCount`. The band and the spares never animate, so they need no layer. They may coincide with each other, or with bead 0 in a one-icon row. Whether to keep the twelve-element count check is your call; all twelve elements still exist. With one icon, bead 0 coincides with the band and spares, so it may be left unmapped. A track on an unmapped channel is then skipped in `apply`. Keep the pure function testable, and extend T19 (`GlassMirrorMatchTests.swift`) with cases for coincident non-animating views and an unmapped bead 0.
  3. **`checkMirror()`:** flush. If the kept mirror is live for this layout, use it. Otherwise re-match against the current layout's views (`GlassMirror.matched` with this swipe's required views), keep the result as the mirror, and use it if it is non-nil. That is one layer-tree walk, only on a swipe whose mirror went stale.
  4. **`emptied()`:** remove every `liquid.` animation, and put the swell at its rest. Do **not** re-run the pre-warm any more: the next `checkMirror()` re-matches. The pre-warm in `init()` stays, for the first window's cost and the first swipe's match.
  5. **T21** (`aRebuiltElementCostsOneSwipeItsMotionAndTheNextSwipeGetsItBack`) changes meaning. After a bead is hidden and shown again (K4), the next swipe's `checkMirror()` re-matches and returns true, and its tracks land on the new element. `emptied()` never re-runs the pre-warm, so the glass views keep that swipe's layout. Rename the test to say so. T20's "no pre-warm ran" assertions stay.
  6. **Find out whether a re-match can come back false right after a rebuild,** because AppKit builds the new elements lazily (K5). If it can, add one extra `CATransaction.flush()` before the walk, and say what you saw. The swipe must never wait or poll: if the match still fails, that swipe is `.still`, which is the designed fallback.
- **Docs:** `docs/architecture.md`'s sentence still holds ("found by class name and matched to the views by frame"). Leave it.

## F2: the window shadow is invalidated on every move event

- **Where:** `LauncherKit/Sources/LauncherUI/SwitcherPanel.swift`, about line 140, in `apply`: `if !frame.isEmpty { invalidateShadow() }`.
- **Rule it breaks:** plan D3, which sets the per-event budget: "One `.moved` event runs `Observations`, then `render`, `follow` and `apply`: one Core Animation commit with at most three swell tracks." A per-event shadow recompute is unplanned work that nobody has measured (R15, R16).
- **Fix decided:** invalidate the shadow only when a view frame changed, that is when `frame.swell != nil`. The shadow during track-driven motion stays a hand check (risk A9).

## F3: docs out of step with the code

- **`docs/architecture.md:23`** reads: "Today that is the launch animation tuner in `LauncherPlatform`: a SwiftUI window over `LaunchTuning`, whose defaults are the shipped launch animation and launch bounce." Change it to name the app switcher's liquid look too. For example: "… whose defaults are the shipped launch animation, launch bounce and app switcher look; `LiquidLook`'s DEBUG-only `Codable` conformance in `LauncherCore` serves it."
- **`docs/architecture.md:13`** (the module list). Add to `LauncherUI`'s list: "the app switcher's liquid glass, which reaches AppKit's mirrored glass layers in one file". Keep the sentence style.
- **`docs/performance.md:84`:** the decision "Fewer redraws in `SwitcherPanel.show`: rejected" names code that no longer exists. Add after it: "(Superseded by plan 024: `show` and the highlight are gone.)" Do not delete the decision.
- **Stale comments:**
  - `LauncherKit/Sources/LauncherCore/PointerCurve.swift:141` ("80 pt icons with 20 pt between … its highlight") and `LauncherKit/Sources/LauncherCore/SwitcherSelection.swift:44` (the highlight). Reword both to the glossary's words: the swell, icons 100 pt apart (centre to centre).
  - The "panel" wording in `LiquidLook.swift` and `SwitcherRowLayout.swift`, and the tuner hint "panel margin" in `AnimationTuner.swift`, are about the window's frame, not a visible panel. Make that explicit: say "the window" or "the switcher's window", so it does not contradict `docs/domain-model.md`'s "with no panel around it". Only comments and hint strings change; no identifiers.

## F4: tests weaker than the plan's table

All in `LauncherKit/Tests/LauncherCoreTests/`. If a row tightened to the plan's text fails, do not loosen it again. Report the failure and its cause; it may be a real bug.

- **T34** (`LiquidWaveTests.swift`, about line 317) defines the far edge as `minX` when the selection moves right, which is the trailing edge. The plan says: "The **far edge** is the swell edge on the side the selection or the fingers last moved toward." Fix it to the leading side: `maxX` when moving right, `minX` when moving left. Keep the 4 ms sampling for the bounds checks. That is an accepted speed trade-off, logged.
- **T24** (`LiquidStretchTests.swift`, about lines 102 to 105) checks stillness from `run.last + 1`. The plan says: "From 1 s after the last event the played shape is exactly T1's." The last event is the last moving event, not the last resting feed. Check from 1 s after that.
- **T25** checks stillness from the end of the push + 1.06 s. The plan says: "is still from 1 s after the last move on". Check from 1 s after the last moving event. `pullHold` (60 ms) plus the spring-back must fit, because every curve is windowed to end at most `settleBound` after its own call, which is the last move.
- **T28** (`LiquidStretchTests.swift`, about lines 258 to 298) changed the hand to a ±5 mm rock inside one selection. Keep that variant, and add the plan's hand as a second case: "ten apps; the fingers slide 30 mm right and back, 300 ms each way, four times, then rest". Use the same filter that skips calls inside a running flow's window (a flow is allowed 200 ms, R6), and the same check: "for every event, in the played history of the frames up to that event alone, the swell's leading edge is within `wobble` of where it would settle, one 60 Hz frame (1/60 s) after the event". Require at least one checked event in that case, not the 100 minimum.
- **T10** (`behind < pitch + wobble`): accepted as is. At a change instant the swell starts exactly one pitch behind by construction. No change.

## F5: small code-quality fixes

`docs/` names no coding-standard rule for these. They are the review's smells, and they are worth fixing for long-term maintainability. Behaviour must stay identical: the whole suite is the guard.

- **Duplicated code across `Liquid.swift` and `LiquidWave.swift`.** Give each repeated constant one definition, in LauncherCore:
  - the smoothstep window `1 - (3 - 2 * x) * x * x` (`Liquid.swift:135`, `LiquidWave.swift:64`);
  - the damping clamp `min(max(damping, 0), 0.95)` (`Liquid.swift:157`, `LiquidWave.swift:54`);
  - the 0.008 s floor (`velocityFloor` and `speedFloor`);
  - the 4 pt icon margin (`Liquid.swift:416`, `SwitcherRowLayout.swift:110`);
  - the 0.2 end-pull cap (`Liquid.swift:230` and `SwitcherRowLayout.swift:57`). Make `SwitcherRowLayout` use `Liquid.endPullBound`, or the reverse. Leave `GestureRules.switcherMaxStretch` alone: it belongs to the window switcher.
- **The data clump in `Liquid.swift:219-226`.** `left`/`right`, `leftTarget`/`rightTarget`, `leftPulled`/`rightPulled` and `leftDue`/`rightDue` always travel together, and `lean()` (about lines 369 to 378) and the end pull (about lines 400 to 408) repeat per side. Introduce a private per-edge struct (its curve, target, pulled flag and due time) held twice, and collapse the per-side duplication where it reads cleanly. This is a refactor only. Keep `EdgeCurve` as the motion primitive.
- **Speculative defaults.** `liquidLook: @escaping () -> LiquidLook = { .shipped }` in `SettingsShell.swift:22` and `SwitcherPresenter.swift:24` is never used: the app passes the closure. Remove both defaults, and keep the parameter required.

## Not fixed (decided)

These are logged, so leave them:

- the test-style judgement calls (multi-assert real-window rows, and asserting animation keys and fill modes, since the render server's state is observable no other way);
- the `checkMirror()` and `lay(out:)` names;
- the two switches in `LiquidKeyframes`;
- the overshoot recomputed from `SwitcherSelection` (`SwitcherSelection` stays untouched by plan);
- `GestureRules.switcherMaxApps` becoming `package`;
- the dated perf results: these need hardware and the human.

## Done when

- [ ] F1's new real-window row fails before the fix and passes after it, for 3, 2 and 1 icons. T19 to T22 and T36 pass, and the real-window suite ran, not skipped. Report its test names.
- [ ] F2 to F5 are done as decided, and every tightened row in F4 is green. Report any tightened row that failed, with its cause.
- [ ] `Scripts/test.sh` from the worktree root is green.
- [ ] The app builds: `xcodegen generate` in the worktree root, then `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project TrackpadLauncher.xcodeproj -scheme TrackpadLauncher -configuration Debug build CODE_SIGNING_ALLOWED=NO`.
- [ ] Do not commit. Report the files changed and every departure from this file.
