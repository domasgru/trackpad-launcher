# Why the swipe switcher looks and moves as it does, and why per-display-frame code is forbidden

### The Question

Why do the app switcher's visuals have their current shape: a Liquid Glass panel, a separate `.clear` glass highlight moved on every trackpad frame, an enlarged selected icon, `roundedClip` (GlassClip), the shared `OverlayPanel`, a 150 ms fade-out, and a row that scales down on narrow displays? And why does `docs/architecture.md` forbid code that runs per display frame and ban display links, while allowing code per input event? This is groundwork for plan 024, which turns the switcher into one continuous liquid Liquid Glass shape. The shape has a swell that stretches with finger travel, flows to a new selection within 200 ms with a wobble, and carries a wave driven by finger speed. It must stay smooth at 120 Hz and cost nothing at rest (`plans/024-fluid-app-switcher/plan.md` R5–R8, R15, R16).

### The Code in Question

- `LauncherKit/Sources/LauncherUI/SwitcherPanel.swift`. An `OverlayPanel` subclass that holds a `.clear` `NSGlassEffectView` highlight (radius 24) under one `CALayer` per icon. `show(position:selected:animatesSize:)` moves the highlight's frame with actions disabled and scales the selected icon to 1.12× through an implicit 0.12 s action. `springHighlight(from:)` adds a keyed additive `CASpringAnimation` (stiffness 420, damping 22).
- `OverlayPanel.swift` is the borderless, non-activating, click-through, screen-saver-level window shared by both switchers. Its content is a `.regular` glass view inside `roundedClip`. It closes with a 0.15 s `CABasicAnimation` opacity fade guarded by a generation counter. `GlassClip.swift` holds `roundedClip`. `SwitcherPresenter.swift` renders `Observations({ launcher.switcher })`. `SwitcherRowLayout.swift` holds the geometry (80/20/92 pt, padding 22, `selectedIconScale` 1.12, `centreX(at:)`, scale-to-fit).
- `docs/architecture.md:20–21` (Concurrency) and `LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift:30–35`. The source scan bans `Timer`, `asyncAfter`, `Task.sleep`, `makeTimerSource`, `displayLink` and `DisplayLink` as raw substrings in every shipped Swift file (`noSourceUses`, :164–168).

---

### What We Found

**The resource rules (root cause of the ban)**

- **[Direct]** The product mandate is minimum resources and Liquid Glass. Source: `docs/product-overview.md:7`, "Trackpad launcher should be as performant as possible, consuming the least possible resources as it's technically possible", and `:10`, "We should use the latest liquid glass human interface design." Both lines first appear in commit fe0e0d7 and are unchanged today.
- **[Direct]** Zero idle CPU is a hard requirement from the first plan. Source: `plans/001-trackpad-launcher-app/plan.md` R22 (l.419–425), "While no finger is touching any trackpad, Trackpad Launcher MUST show 0% CPU in Activity Monitor". The problem statement adds "A launcher only earns a place in the menu bar if it costs nothing to keep" (l.9).
- **[Direct]** The timer ban exists to keep idle CPU at zero. Source: `docs/architecture.md:20` (first committed in 1cf9c4b, PR #1), "No timers, no polling, no background loops: every input is a push … This is what keeps idle CPU at zero."
- **[Direct]** Display links were banned in plan 004 (launch animation) as the tempting per-frame alternative to keyframes, and filed under the "timer" rule. Sources:
  - `plans/004-launch-icon-animation/plan.md` "Source policy" (l.347): "A per-frame callback is the tempting alternative to keyframes, and it would run code of ours on every frame."
  - Commit ee9a3f0 (PR #3): "Display links are banned in shipped sources."
  - SourcePolicyTests (still at :34–35): `Entry(token: "displayLink", rule: "timer")`.
- **[Direct]** The animation bullet was written alongside that ban. Source: ee9a3f0, `docs/architecture.md`: "Animation is Core Animation keyframes, which the render server plays … No code of ours runs per frame, and display links are banned along with timers." Plan 004 "Lifetime" (l.339) gives the intent: "Core Animation renders the frames in the render server. Once the last panel has closed, no code of ours runs."
- **[Direct]** The current wording ("per display frame", plus the per-input-event allowance naming "the switchers' highlight on trackpad frames") came from plan 017 (launch bounce), and the user accepted it for later features. Sources:
  - `plans/017-launch-wait-bounce/plan.md` l.478 ("D1 reading … This is the switcher's per-trackpad-frame precedent (plan 006 F27, `docs/performance.md`)").
  - l.1196 (open question D1: "the rule you want written into `docs/architecture.md` for later features too?").
  - l.1192, "D1 accepted as the rule for later features too."
  - `017/development-logs.md` l.51.
  - Diff in a068ed5 (PR #21, first on branch commit 28f5a6f) replaced "per frame" with "per display frame … Code may run per input event while the effect it serves is on screen: the switchers' highlight on trackpad frames, the launch bounce's row on pointer moves."
- **[Direct]** In the same change, time was confined to Core Animation's clock. Source: `docs/architecture.md:20`, "Time passes only on Core Animation's clock: a deadline … is an animation on a layer of the effect it belongs to, its completion is the push, and it cannot outlive that effect." Plan 017 rejected a dispatch-source deadline port because it "needs `asyncAfter` or `makeTimerSource` unbanned and the architecture rewritten" (017 plan.md Alternatives, l.1175–1178).

**The switcher's visual shape (plan 006, then 008/012/013)**

- **[Direct]** The look is a product requirement, not an implementation choice. Source: `plans/006-five-finger-tap-and-corner-swipe/plan.md` R10 (l.241), "The switcher MUST be a Liquid Glass panel … a glass selection highlight slightly larger than an icon that slides under the icons, the selected icon drawn slightly larger than the others … MUST be gone within 200 ms of the swipe ending … MUST never take focus … With Reduce motion on, the highlight MUST still follow the fingers … but nothing springs, fades or animates its size." R6 (l.135) adds that the highlight "MUST move continuously with the fingers: between two icons it sits between them in proportion to the travel."
- **[Direct]** The rendering design comes from 006 design decision 8 (l.646). That decision sets:
  - the launch overlay's window configuration, "around an `NSGlassEffectView` in a rounded clip";
  - "a glass highlight view 92 pt square";
  - "*Per update, with actions disabled:* highlight x = `position × 100 pt`, so it follows the fingers one to one; the selected icon layer at 1.12×";
  - an additive keyed `CASpringAnimation` for the stretch, "with no code of ours per display frame";
  - "*On close:* opacity to 0 over 150 ms, `orderOut` from the completion".
- **[Direct]** SwiftUI was rejected for the switcher because of the animation rule. Source: 006 plan.md Alternatives (l.1350), "its springs and scale animations are not Core Animation keyframes, the architecture's animation rule, and the overlay precedent is Core Animation." The Tradeoffs section (l.1338) says: "more imperative than SwiftUI, in exchange for springs and fades played by the render server with no code of ours per display frame, as in the launch overlay."
- **[Direct]** Moving the highlight on every trackpad frame was justified as input-driven work, not a display loop. Sources:
  - 006 grounding `.temp/architect/grounding/index.md` F27 (l.55): "A switcher highlight driven by finger frames is input-driven work (~100 Hz while the fingers move), not a per-display-frame loop".
  - 006 Tradeoffs (l.1332): "The work is input-driven and stops when the fingers stop."
- **[Direct]** The fade is a Core Animation opacity animation because a review applied the animation rule to it. Sources:
  - `006/development-logs.md` l.39: "switcher close fade used `panel.animator().alphaValue`, not Core Animation (architecture's animation rule) → now a Core Animation opacity fade on the content layer with `orderOut` from its completion, guarded by a generation counter".
  - Commit b15701e makes that change on top of cb7b432.
- **[Direct]** `roundedClip` fixes a visual defect. Source: commit 85ea6f2 (PR #1 branch), "The glass left faint full-rectangle content behind its rounded corners and the window shadow traced it as a square outline. Clip the panel content to the glass shape so the shadow follows the rounded edge." The text is carried into `GlassClip.swift:3–5`. It was moved to a shared file in b15701e (`006/development-logs.md` l.43: "`roundedClip` shared in `GlassClip.swift`").
- **[Direct]** `OverlayPanel` was extracted in plan 012 as the shared base for both switchers. Sources:
  - `plans/012-window-switcher-gesture/plan.md` l.1183–1186 ("Both switchers' window … Liquid Glass under `roundedClip` … dismisses with a 150 ms fade (at once with Reduce motion) unless presented again meanwhile").
  - Module map l.701.
  - Commit f4590b1 (PR #15 prefactor).
- **[Direct]** The row scales on narrow displays because of a requirement. Source: `plans/008-recent-apps-switcher/plan.md` R6 (l.119–120): "the icons and the gaps between them MUST scale by the same factor … The finger travel per icon MUST NOT change with the icon size." Decision 10 (l.288) puts both icons and highlight on one `centreX(at:)` "so the two cannot drift apart". The dev log (l.25) calls drift the "real risk".
- **[Direct]** Plan 013 set padding to 22 pt to the highlight's edge and moved 1.12× into `SwitcherRowLayout` "so every size that must agree with another … is one tested value". It explicitly froze the look. Sources: `plans/013-simplify-switchers/plan.md` l.99–103, and l.105: "The panel's corner radius (34) and the highlight's (24), the transform's 0.12 s animation and the spring are untouched: the look and motion are non-goals." R2 (l.26): the selected icon "MUST stay inside the highlight."
- **[Direct]** The per-trackpad-frame `show` is the most expensive swipe path, and optimising it was rejected so the icon-grow animation would stay. Sources:
  - `docs/performance.md:65`: "During swipes, about a quarter of the CPU was the switcher panels' per-frame `show` (Core Animation commits and `NSView.setFrame` on the glass highlight)."
  - `:50`: app switcher swipes cost 1.08 ms per frame, the highest row in the table.
  - `:78`, and `plans/014-gate-event-tap/plan.md` l.49: "skipping unchanged transforms would likely change the icon-grow animation, which plan 013 keeps unchanged."
- **[Direct]** Clear glass highlights can nearly vanish over some backdrops. Source: PR #24 body (820192a), "The switcher's clear-glass row highlight could nearly vanish over some backdrops. It now carries a faint label-colour tint". The fix covered only the window switcher (`WindowSwitcherPanel.swift:11–12, :37`). The app switcher's highlight (`SwitcherPanel.swift:23`) is still untinted.
- **[Direct]** The idle baseline was measured. Source: `docs/performance.md:47`, "Hands off, 60 s … 0.77 ms in total (0.001%) … 0 idle wakeups".

### What We Can Reasonably Infer

- **[Inferred]** The display-link ban appears to be a design rule rather than a reaction to an incident. Reasoning: neither commit messages nor plans record a hitch, CPU spike or removed display link. Plan 004 gives the reason as a principle ("would run code of ours on every frame"). A prior investigator's note in `plans/017/.temp/.../why.md` says `git log -G` found no timer or display link ever added and then removed. That is second-hand and was not re-verified here.
- **[Inferred]** The real concern is CPU spent by our process while something is on screen and while idle, not visual smoothness. Reasoning: every stated reason (R22, the "keeps idle CPU at zero" line, 004's "code of ours on every frame", 017's "nothing runs once the last bounce ends") is about our own CPU and idle cost. No plan or commit mentions frame pacing, 120 Hz or jank as a reason (see gaps). In 006, candidate-1's sharper wording ("springs and fades are interpolated in-process per display frame") suggests the per-frame CPU worry was in mind there too.
- **[Inferred]** The separate glass highlight moved by frame seems to be the first implementation's natural shape, not the winner over recorded alternatives. Reasoning: decision 8 sets it directly. The pickaxe traces 92 pt, radius 24, `.clear`, 1.12× and the spring constants to S3 (cb7b432) with no rationale. No commit or plan mentions masks, a single shape, `NSGlassEffectContainerView` merging or morphing for the app switcher. The repo has no PR reviews, so missing discussion does not prove alternatives were never considered.
- **[Inferred]** 150 ms seems to have been chosen to fit under R10's 200 ms "gone within" bound, with headroom. Reasoning: it first appears in 006's candidates as "fade ≤ 150 ms", and the 006 manual check says "fully gone within 12 frames (200 ms)" (l.1500). No source names 150 for its own sake.
- **[Inferred]** The 0.12 s icon-grow looks like an implementer choice that was later protected. Reasoning: decision 8 specifies 1.12× but no duration. The 0.12 s first appears in plans as a description of shipped code (012 `how-shell.md` l.83) and was then frozen by 013 l.105 and 014 l.49.
- **[Inferred]** Visual feel in this codebase is settled by the user on hardware through the Debug-only tuner, not by numbers written in plans. Reasoning: 004's shipped animation is "Preset 2" picked by feel (`004/development-logs.md` l.51–52). 017 made post-implementation feel changes (017 dev log l.68–72). 012's `WindowSwitcherLook` is "modelled on `LaunchTuning`" so it can be "refined later together" (012 plan.md l.1225–1227). Plan 024 R17 continues the same pattern.

### Competing Hypotheses

**What the original "No code of ours runs per frame" forbade (2026-10-10 to 2026-10-19)**

- **Hypothesis A:** From the start, the rule only ever meant display frames. The switcher's per-trackpad-frame updates were always compliant.
  - Evidence for: 006 F27 (2026-10-11) already read it this way. 006 Tradeoffs l.1338 speaks of "no code of ours per display frame". The 006 review (b15701e) applied the rule to the fade but did not flag `show`.
  - Evidence against or missing: the text said "per frame" with no qualifier. Plan 004 l.339 reads more strictly: "Once the last panel has closed, no code of ours runs." Plan 017's own grounding listed this as "Disputed D1", and its why.md notes "F27 is a grounding note, not a recorded decision."
- **Hypothesis B:** The switcher's per-trackpad-frame `show` (shipped in #5, 10b0e91) stretched the rule, and plan 017 legalised it after the fact.
  - Evidence for: the wording stayed "per frame" through PRs #5, #11, #15, #16 and #18, and changed only in 28f5a6f/a068ed5, which names the switcher highlight as an allowed case.
  - Evidence against or missing: no record calls the switcher a violation.
- **Settled today:** either way, the current text and the user's D1 acceptance (017 plan.md l.1192) make the per-input-event allowance the rule for later features. The historical reading does not change what plan 024 is bound by.

**Why SwiftUI was rejected (006)**

- **Hypothesis A:** For CPU cost. Candidate-1 says SwiftUI's springs and fades "are interpolated in-process per display frame" (006 `.temp/architect/candidate-1.md` l.940–941).
- **Hypothesis B:** For conformance with the rule and the overlay precedent. The final plan says "not Core Animation keyframes, the architecture's animation rule, and the overlay precedent is Core Animation" (l.1350).
- These two framings do not exclude each other. The final plan only commits to B.

**Trackpad input rate versus the display rate (relevant to R15)**

- The plans say "~100 Hz" frames (001 l.457, 006 decision 8). The 006 dev log (l.47) records "a 120 Hz report rate" from IOHIDFamily's acceleration model. Source control has no measured trackpad frame rate. Whether trackpad updates line up with a 120 Hz display's frames is unrecorded.

### What We Don't Know

- **Whether Liquid Glass can take an arbitrary, animating, non-rounded-rect outline.** No plan or commit used `NSGlassEffectContainerView`, glass merging/morphing, `effectIsInteractive`, or a shape-layer mask on glass. The only recorded facts are second-hand Apple guidance in `plans/012/.temp/architect/grounding/index.md` F39 ("merges nearby glass views and cuts render passes; 'limit the number of glass effects'; only `contentView` is guaranteed inside the glass") and an F25 typecheck. Searched with: `grep -rniE 'material capsule|NSVisualEffectView|glass on glass|NSGlassEffectContainerView|effectIsInteractive|morph|liquid'` over plans, and `git log --all -i --grep=glass`.
- **Whether glass-on-glass (the highlight over the panel) was ever checked on hardware.** 006 open question l.1367 (fallback: "a translucent material capsule") was never recorded as resolved. `006/development-logs.md` l.38 says those checks stayed unticked.
- **Any frame-pacing, 120 Hz or render-server/WindowServer cost measurement of the switcher.** Searched with: `promotion|120 ?hz|60 ?hz|refresh|frame rate` and `stutter|jank|smooth|choppy|flicker|hitch|dropped frame` over plans, commit messages, docs and Sources. The only hits are about the trackpad report rate, launch keyframe sampling and the launch bounce. 017 P6 calls compositing cost "unmeasured".
- **The reason for specific numbers:** 150 ms, 0.12 s, 1.12×, 92 pt, radius 34/24, spring stiffness 420 / damping 22, and `.clear` versus `.regular` for the highlight. No commit message, PR body or plan states one beyond "slightly larger" (R10) and feel-check open questions (006 l.1368).
- **Why the window shadow tracked a rectangle, and how it would treat a non-rectangular, changing outline.** 85ea6f2 records the symptom and fix only. Nothing records the cost of `invalidateShadow()` per change, or whether the shadow follows a masked or animated shape.
- **Whether the app switcher's untinted `.clear` highlight shows the PR #24 "nearly vanish" problem.** Nothing records why the tint went only to the window switcher. Plan 019's directory was not separately found in plans.
- **Review discussion.** All 28 PRs have 0 reviews. `gh api pulls/{5,15,16,21}/comments` returned nothing. Any reasoning the author had but did not write down is only available from the author (Dominykas Grubys).
- **Tests.** No LauncherUI test target exists. Panel visuals, the fade, `roundedClip` and the spring have never been under test. Only `SwitcherRowLayout`/`Switcher` geometry is tested.

### Sources Consulted

- **Source control history:**
  - The full main history (31 commits), plus `origin/feature/*` pre-squash branches.
  - `git show` on ee9a3f0, 10b0e91, cb7b432, b15701e, b67a5ca, f4590b1, 92914eb, 18acef7, 66b3ff6, 820192a, a068ed5, 28f5a6f, d024645, 5e36ee2, 85ea6f2, 36c3803, c9125b6, fe0e0d7 and 1cf9c4b.
  - Pickaxe searches for the ban wording, `roundedClip`, `1.12`, `setAnimationDuration(0.12)`, `stiffness = 420` and `.clear`.
  - `--grep` searches for highlight/glass/fade/spring/display link/120 Hz/jank.
  - `gh` PR bodies for #1, #5, #15, #16, #18, #21 and #24, and inline comments on #5, #15, #16 and #21.
  - `docs/architecture.md`, `docs/performance.md`, `docs/product-overview.md`, SourcePolicyTests, and code comments in the anchor files.
  - Spot-checked for this synthesis: the commit messages of 85ea6f2, ee9a3f0 and a068ed5; `docs/architecture.md:20–21`; `docs/performance.md:47–78`; `SourcePolicyTests.swift:30–35, 164–168`; `SwitcherPanel.swift`; `GlassClip.swift`; `OverlayPanel.swift` (fade 0.15, generation, Reduce motion); `SwitcherRowLayout.swift`.
- **Plans:**
  - Plans 001–021 (`plan.md`, `development-logs.md`, committed `.temp/` grounding, candidates and slices).
  - Greps for glass/GlassClip/display link/per display frame/120 Hz/keyframe/fade/150 ms, clip/shadow terms, icon-grow terms, glass API terms, frame-rate terms and smoothness terms.
  - Spot-checked: 004 l.336–347; 006 l.241, l.646, l.1338, l.1350, l.1367–1368, dev log l.39, l.43, l.46–47, grounding F27; 008 R6; 013 l.105; 014 l.49 and dev log l.40; 017 l.478, l.1154, l.1186, l.1192, l.1196, dev log l.51, grounding F21; 012 grounding F39; 001 R22.
  - Read `plans/024-fluid-app-switcher/plan.md` and `development-logs.md` to frame the constraints.
  - `research/` was not read.

### Confidence Summary

The documents say directly, with citations, why the code forbids per-display-frame code: zero idle CPU and least resources, with display links banned as "code of ours on every frame". The same holds for the per-input-event allowance (plan 017 D1, accepted by the user for later features). Most of the switcher's visual structure (Liquid Glass, glass highlight following the fingers, enlarged icon, ≤200 ms disappearance, Reduce motion, row scaling, shared overlay, Core Animation fade, `roundedClip`) is likewise documented by requirements, decisions or commit messages. The specific numbers (150 ms, 1.12×, 0.12 s, radii, spring constants) and the choice of a separate moving glass view over any alternative have no recorded rationale. Nothing in the record says whether Liquid Glass can form one continuous animated liquid shape, or what that would cost at 120 Hz.

---

## Constraint set for planning plan 024

### Preserve

- **No code of ours per display frame. No display links, timers, `asyncAfter`, `Task.sleep` or `makeTimerSource`.** Animation is played by the render server (`docs/architecture.md:21`; SourcePolicyTests :30–35). The flow, wobble, wave decay and stretch spring-back must be Core Animation animations (keyframe, basic or spring, including on path or shape properties) that the render server plays.
- **Code per input event only while the switcher is on screen** (D1, 017 plan.md l.1192). Per-trackpad-frame work may retarget or add animations, but must stop when the fingers stop. Nothing may run once the switcher is hidden or the liquid has settled (024 R16 matches 001 R22).
- **Deadlines and settling run on Core Animation's clock**, through animation completions on layers of the effect itself (`docs/architecture.md:20`). Cleanup of what an animation leaves happens in its completion callback.
- **The 150 ms render-server opacity fade with `orderOut` from completion and the generation guard** (`OverlayPanel.dismiss`; 006 dev log l.39; 024 R11), and instant close under Reduce motion.
- **`OverlayPanel`'s window configuration and its behaviour for the window switcher.** It is shared, and 024's non-goals keep the window switcher's look. That means borderless, non-activating, click-through, screen-saver level, never key, created ahead of the first swipe.
- **One geometry source in `SwitcherRowLayout`.** Icons and the liquid shape must both derive from `centreX(at:)` and the same scale factor, so they cannot drift (008 decision 10). Uniform scale-to-fit, with finger travel per icon unchanged (008 R6, 024 R14). The 1.12× selected icon stays inside the swell (013 R2, 024 R4).
- **The Reduce motion path** (006 R10, 024 R13): no wave, stretch, flow, wobble or size animation.
- **Tuning in one value type whose defaults are the shipped look**, Debug-only tuner (`LaunchTuning`/`WindowSwitcherLook` pattern, `architecture.md:22`, 024 R17).
- **Pure, testable motion builders**: build `CAAnimation`s in pure code and test their bounds, not their formulas (004 dev log l.21, l.539). This is the only precedent for putting motion under test, and LauncherUI has no tests.

### Change

- **The separate `.clear` `NSGlassEffectView` highlight moved by `setFrame` per trackpad frame**, plus the rounded-rect panel. Plan 024 replaces both with one continuous shape. 013 l.105 and 014 l.49 froze this look as a non-goal for those plans only, so plan 024 is free to change it.
- **The 0.12 s implicit icon-grow and the additive spring on `position.x`.** These may be replaced by the flow/wobble animations, provided 1.12× and Reduce motion behaviour are kept. 014's reason for not optimising `show` (protecting the icon-grow) no longer applies once that animation is redesigned.
- **`roundedClip` for the app switcher.** It handles only rounded rectangles. A non-rectangular outline needs another way to stop the window shadow tracing the content rectangle (85ea6f2's defect).
- **`architecture.md`'s animation bullet text**, if the new design needs any wording change. Plan 017 set the precedent: wording changes go to the user as an explicit open question.

### Avoid

- **Generating the liquid outline on the CPU for every display frame** (display link, timer, or a per-frame `CATransaction` loop). This is banned (above), and the source scan fails on the substring even in comments or `#if DEBUG` code (017 plan.md l.238, F23).
- **SwiftUI-driven springs or `glassEffect` animations for the shape** unless it can be shown that they play on the render server. 006 rejected them on exactly this rule (l.1350).
- **Moving windows (`setFrame` on the panel) per input event.** Moving layers inside one panel is preferred. 017 rejected per-event window moves because frame and layer changes "may not land in the same frame" (l.1186). The existing per-frame `NSView.setFrame` on the glass highlight is already the named swipe cost (`performance.md:65`).
- **Queuing animations.** 024 R6 requires retargeting. Start new animations from `presentation()` values, as the fade already does (`fromValue = layer.presentation()?.opacity`).
- **Changing `OverlayPanel` in a way that changes the window switcher's appearance or fade.**
- **Shipping tuned values that exist only in the Debug tuner's saved state.** The 014 incident shows Debug playing tuned values while Release played the shipped defaults (`014/development-logs.md` l.40).

### Risk

- **Liquid Glass may not support an arbitrary animated outline.** Nothing in the record shows `NSGlassEffectView` taking a non-rounded-rect shape, a mask, or merging through `NSGlassEffectContainerView` into one continuous shape that animates. This is the biggest unknown, and it needs a probe before design. 012 F39 is the only lead, and it is second-hand.
- **Render-server or WindowServer cost of Liquid Glass with a changing shape is unmeasured** (017 P6: compositing "unmeasured"). "Smooth at 120 Hz with ten apps" (024 R15) has no baseline. `Scripts/perf/` measures our CPU, not compositor frame pacing.
- **Trackpad updates versus the display rate.** The record says "~100 Hz" frames in plans and "120 Hz report rate" in 006's acceleration model, and has no measurement. If shape changes are set directly per input event, a 120 Hz display may show repeated frames. Render-server interpolation between input events may be needed to meet R15 without per-display-frame code.
- **Per-input-event CPU.** The current per-frame `show` already costs 1.08 ms per frame during swipes (`performance.md:50, :65`). Rebuilding a shape path and re-adding animations on every trackpad frame could raise this. Re-measure against the `performance.md` baseline.
- **"Costs nothing at rest" (R16) versus long or repeating animations.** A settled wobble or wave must end. Animations that loop or never finish would break R16 and the idle rule. Completion callbacks are 1–19 ms late on visible windows (004 l.338, 017 F24), and later still off screen (017 P5).
- **Window shadow on a non-rectangular, changing outline.** The square-outline defect (85ea6f2) may return, and `invalidateShadow()` per change has unknown cost.
- **Legibility of untinted glass.** PR #24 recorded clear glass "nearly vanishing". 024 R2 forbids a tint and sends the decision back to the user if the light-over-white scenario fails.
- **No UI test target.** Shape, wave bounds (024 R8: never break the band) and Reduce motion behaviour will rely on pure-builder tests plus manual hardware checks. 006's glass-on-glass check shows that hardware checks can stay unticked.
- **First-show latency.** A new layer or shape structure must not add first-swipe cost. The switcher appears "with no perceptible delay" only because the panel and window-server warm-up are paid ahead of time (006 F32's 27 ms; 012 `how-shell.md`, where LaunchOverlay's warm-up absorbs it).
