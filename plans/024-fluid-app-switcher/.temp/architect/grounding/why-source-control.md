# Why: source control findings (switcher visuals, no-per-display-frame rule)

### Source
Source control: git history (main, plus the remote `origin/feature/*` branches, which keep the pre-squash commits), PR bodies/comments via `gh`, code comments, tests, `docs/` files. Plans content was only grepped to map commits; plan reasoning is left to the Plans investigator.

### What I Searched
- `git log --oneline` (whole history, 31 commits on main), `git log --follow` on GlassClip.swift, OverlayPanel.swift; `git log` on SwitcherPanel/SwitcherPresenter/WindowSwitcherPanel/WindowSwitcherPresenter/GlassClip.
- `git log -p -G'Animation is|display link|per display frame|per input event' -- docs/architecture.md`
- `git log -S'display links are banned'`, `-S'No code of ours runs per display frame'`, `-S'idle CPU at zero'`, `-S'rule: "timer"'`, `-S'roundedClip'`, `-S'square outline'`, `-S'OverlayAppear'`, `-S'switcherMaxStretch'`, `-S'least resources'`, `-S'liquid glass'`, `-S'1.12'`, `-S'setAnimationDuration(0.12)'`, `-S'stiffness = 420'`, `-S'highlight.style = .clear'`, `-S'Fewer redraws'` (on origin/feature/014).
- `git log --all -i --grep` for: `highlight|glass|fade|spring|rubber|display link|per frame|idle`; `120 ?hz|promotion|frame rate|stutter|jank|smooth`; `150 ms|0\.15|reduce motion`.
- `git show` on: ee9a3f0, 10b0e91, cb7b432, b15701e, b67a5ca, f4590b1, 92914eb, 18acef7, 66b3ff6, 820192a, a068ed5, 28f5a6f, d024645, 5e36ee2, 85ea6f2, 36c3803, c9125b6, fe0e0d7, 1cf9c4b.
- `gh pr list --state all` (PRs 1–28, comment/review counts), `gh pr view` bodies for 1, 5, 15, 16, 18, 21, 24; `gh api .../pulls/{5,15,16,21}/comments` (inline review comments).
- `grep` of docs/ for idle/cpu/glass/per frame/120 Hz; read docs/performance.md, docs/product-overview.md, docs/architecture.md Concurrency; SourcePolicyTests.swift; test names mentioning fade/stretch/highlight/glass/reduce/spring.
- Code comments in SwitcherPanel, SwitcherPresenter, GlassClip, OverlayPanel, WindowSwitcherPanel, LaunchOverlay, BounceOverlay, LaunchTuning, AnimationTuner, SwitcherSelection, SwitcherRowLayout, GestureRules.

---

### Direct Evidence Found

**1. The original "no timers" rule and its stated reason (idle CPU).**
- What it says: "No timers, no polling, no background loops: every input is a push (frames, cfprefs KVO, IOKit notifications, workspace notifications, the TCC Darwin notification, user events). This is what keeps idle CPU at zero."
- Where: `docs/architecture.md` as first committed in 1cf9c4b (PR #1, "Trackpad Launcher app"), Concurrency section. Still present today at docs/architecture.md:20.
- Author/date: Dominykas Grubys (with Claude), 2026-10-09.
- Relevance: the oldest stated reason for the timer ban; the display-link ban was later filed under this same rule.

**2. The product requirement behind the resource rules.**
- What it says: "Trackpad launcher should be as performant as possible, consuming the least possible resources as it's technically possible. We don't need performance tests, but we should just pick the most performant technical path available when doin technical research." and "We should use the latest liquid glass human interface design."
- Where: `docs/product-overview.md`, first commit fe0e0d7 ("Add product overview and design assets", 2026-10-08). Both lines unchanged today (docs/product-overview.md:7 and :10).
- Relevance: the product-level reason for both the Liquid Glass look and the "least resources" constraint. docs/performance.md:3 later cites it: "The product promise is the least resources technically possible (`product-overview.md`)."

**3. Display links banned: introduced with the launch animation.**
- What it says (commit message, sub-commit of PR #3): "- Display links are banned in shipped sources."
- Architecture bullet added in the same squash (ee9a3f0): "Animation is Core Animation keyframes, which the render server plays. Whatever an animation leaves behind is cleaned up from its completion callback. No code of ours runs per frame, and display links are banned along with timers."
- Test change in the same commit (`LauncherKit/Tests/LauncherCoreTests/SourcePolicyTests.swift`): `Entry(token: "displayLink", rule: "timer")`, `Entry(token: "DisplayLink", rule: "timer")`, and the kept-bans test now also pins `"displayLink", "DisplayLink"` ("IOHID, Input Monitoring, timer, display-link and polling tokens are still banned").
- Where: ee9a3f0, "Launch animation (#3)", 2026-10-10, Dominykas Grubys (co-authored with Claude Opus 5.5).
- Relevance: the display-link ban is filed under rule `"timer"`. That ties it to the timer ban's idle-CPU reason (item 1). The commit message itself gives no reason beyond the ban.
- Today: SourcePolicyTests.swift:34-35 still bans both tokens. The scanner matches raw substrings in every shipped Swift file under `Sources/` and `TrackpadLauncher/` (`noSourceUses`, :164-168), so a comment that mentions a display link also fails the build.

**4. "per frame" narrowed to "per display frame", and the per-input-event allowance added (launch bounce, #21).**
- Diff (a068ed5, squash of PR #21; first introduced on branch commit 28f5a6f "Design the launch bounce", 2026-10-19 13:38, domasgru):
  - `-` "No code of ours runs per frame, and display links are banned along with timers."
  - `+` "No code of ours runs per display frame, and display links are banned along with timers. Code may run per input event while the effect it serves is on screen: the switchers' highlight on trackpad frames, the launch bounce's row on pointer moves."
- In the same diff, the timer bullet gained: "Time passes only on Core Animation's clock: a deadline, such as a launch bounce's cap or its wait after the app finished launching, is an animation on a layer of the effect it belongs to, its completion is the push, and it cannot outlive that effect."
- PR #21 body: "It adds pointer-move monitors and an Accessibility window observer, which exist only while a bounce shows."
- Relevance: the switcher highlight's per-trackpad-frame updates were written into the rule as an allowed case only when the launch bounce needed pointer-move code. Before 28f5a6f, the text "No code of ours runs per frame" sat next to a switcher that already ran `show` on every trackpad frame (see Contradictions). Commit messages give no reason for the rewording. The plan text that explains it is listed under Additional Leads.

**5. The 150 ms fade: first done with NSAnimationContext, moved to Core Animation after review, citing the animation rule.**
- S3 commit cb7b432 ("Switcher on screen (S3)", 2026-10-11, domasgru), SwitcherPresenter.hide: `NSAnimationContext.runAnimationGroup { context in context.duration = 0.15; panel.animator().alphaValue = 0 } completionHandler: { ... guard let self, !self.isShown else { return }; self.panel.orderOut(nil) }`.
- Review fix b15701e ("Fix implementation review findings", 2026-10-11): "Core Animation fade for the switcher, ...". The diff replaces the above with `SwitcherPanel.fadeOut` (CABasicAnimation on `opacity`, `fromValue = layer.presentation()?.opacity ?? layer.opacity`, `.easeOut`, completion block) and a `fadeGeneration` counter: "Bumped by every open and close, so a fade's completion that a later open or close outlived does nothing."
- The same commit adds a development-log line (file is under plans/, but it arrived in this commit): "Review → switcher close fade used `panel.animator().alphaValue`, not Core Animation (architecture's animation rule) → now a Core Animation opacity fade on the content layer with `orderOut` from its completion, guarded by a generation counter; the keyed `CASpringAnimation` stays (design decision 8)."
- Relevance: this is the direct reason the fade is a render-server CABasicAnimation with cleanup from its completion block and a generation guard. The 150 ms value comes unchanged from S3. No commit message gives a reason for 150 ms itself.

**6. GlassClip / `roundedClip`: a fix for a visual defect (square shadow outline).**
- Commit 85ea6f2 (PR #1 branch, 2026-10-09, domasgru), "Remove square window outline, widen toggle spacing, loosen hint leading": "The glass left faint full-rectangle content behind its rounded corners and the window shadow traced it as a square outline. Clip the panel content to the glass shape so the shadow follows the rounded edge." It first applied to `LauncherPanel` (the menu-bar window), and that diff also adds `invalidateShadow()`.
- The comment is carried verbatim into today's GlassClip.swift:3-5: "The glass alone leaves faint full-rectangle content behind its rounded corners, and the window shadow traces that rectangle as a square outline. Clipping the content to the glass's shape makes everything outside the rounded corners transparent, so the shadow follows the rounded edge."
- It was copied into SwitcherPanel in S3 (cb7b432, private static `roundedClip`, comment: "The glass alone leaves faint full-rectangle content behind its rounded corners, which the shadow would trace."). It was then moved to a shared file in b15701e. Dev-log line in that commit: "`roundedClip` shared in `GlassClip.swift`."
- Relevance: GlassClip is defensive. It works around how `NSGlassEffectView` renders inside a shadowed borderless window. PR #1 body also lists "window outline" among its follow-up fixes. LauncherPanel was deleted in c9125b6 (#28), so today `roundedClip` is used only by OverlayPanel.swift:44, and therefore only by the two switchers.

**7. Measured cost of the per-trackpad-frame highlight update, and a rejected optimisation.**
- docs/performance.md:65 (baseline audit 2026-10-17, origin/main 9557bc2): "During swipes, about a quarter of the CPU was the switcher panels' per-frame `show` (Core Animation commits and `NSView.setFrame` on the glass highlight)."
- docs/performance.md:50: "App switcher swipes, about 6 in 30 s | 1362 ms (4.5%) | 1.08 ms" per frame. That is the highest per-frame cost in the table, against 0.36 ms for pointer and scroll.
- docs/performance.md:78: "**Fewer redraws in `SwitcherPanel.show`: rejected.** It would save a few milliseconds per swipe, and skipping unchanged transforms would likely change the icon-grow animation, which plan 013 keeps unchanged."
- Where: added in branch commit 36c3803 ("Document performance measurements and check in the tools", 2026-10-18, domasgru), on feature/014-gate-event-tap, merged as bc56781 (#18).
- Relevance: the only measurement in source control of what the current per-frame highlight path costs. It names `NSView.setFrame` on the glass highlight and CA commits. The decision not to optimise it rests on keeping the icon-grow (implicit 0.12 s scale) animation.

**8. Highlight visibility: clear glass alone can vanish.**
- PR #24 body (820192a, 2026-10-21): "The switcher's clear-glass row highlight could nearly vanish over some backdrops. It now carries a faint label-colour tint (8% alpha, adapts to light/dark), tunable via `WindowSwitcherLook.highlightTint`."
- Code: WindowSwitcherPanel.swift:11-12 "A faint wash of the label colour over the highlight's clear glass, so it stays visible over any backdrop." and :37 `highlight.tintColor = .labelColor.withAlphaComponent(look.highlightTint)`.
- Relevance: a recorded legibility problem with `.clear` glass highlights. The tint was applied only to the window switcher. The app switcher's highlight (SwitcherPanel.swift:23) is still untinted `.clear` (see Gaps).

---

### Indirect / Circumstantial Evidence

**A. Shape of the switcher visuals was set in S3 and barely changed afterwards.**
- cb7b432 (S3, 2026-10-11) already has: `.regular` NSGlassEffectView panel with cornerRadius 34; `.clear` NSGlassEffectView highlight, cornerRadius 24, 92 pt; icon CALayers; `show` that sets `highlight.frame.origin.x` inside a `CATransaction` with `setDisableActions(true)`; icon scale 1.12 with implicit actions over 0.12 s (`setDisableActions(!animatesSize)`, `setAnimationDuration(0.12)`); keyed additive `CASpringAnimation` on `position.x` (mass 1, stiffness 420, damping 22) for the rubber band. Pickaxe for `1.12`, `setAnimationDuration(0.12)`, `stiffness = 420`, `highlight.style = .clear` all point first to 10b0e91 (#5).
- Later changes: b67a5ca (#11) moved geometry into `SwitcherRowLayout` ("The panel positions icons and highlight through `centreX(at:)` alone, so they cannot drift apart") and shrinks long rows. f4590b1 (#15 prefactor) pulled the window config and fade into `OverlayPanel`, shared by both switchers ("one overlay panel"). 66b3ff6 (#16) dropped the name label, set padding to 22 pt, and moved `selectedIconScale = 1.12` into SwitcherRowLayout with "it stays inside the highlight". PR #16 body: "Layout constants and a removed label only".
- What it suggests: the separate-highlight-view design (a moving `NSGlassEffectView` frame over static icon layers) comes from the first implementation. No later commit message discusses alternatives such as one shape or a mask.
- Alternative reading: the absence of discussion may reflect squash merges and no PR reviews (every PR has 0 reviews). It does not show that no alternatives were considered. Plan 006's design decision 8 may hold that reasoning (lead).

**B. The per-frame path itself.**
- Launcher.swift:301-305: each `.moved(travel)` event writes `shown = .apps(open)`. SwitcherPresenter.swift:27 iterates `Observations({ launcher.switcher })` and calls `render`, which calls `panel.show(...)` (SwitcherPresenter.swift:124). Architecture bullet docs/architecture.md:18: "only recognised events hop to the main actor: ... the begin, moves and end of a swipe ... in frame order on the main queue".
- What it suggests: the highlight moves at the trackpad frame rate, set by the main queue hop and `Observations` delivery, not at the display rate. Source control holds no statement of the trackpad frame rate or of display refresh rates. The test conventions in plan 006 (line 1409) use "10 frames, 10 ms apart" for scripted slides, but that is test scripting, not a measured rate.

**C. Selection model feeding the visuals.**
- SwitcherSelection.swift:44-54: `position` is continuous ("Between two items it sits between them in proportion"). `stretch` is a saturating rubber band bounded by `switcherMaxStretch = 0.2` (GestureRules.swift:31). Tests: `theHighlightSitsBetweenIconsInProportionToTheTravel`, `pushingPastAnEndStretchesTheHighlightButNeverByAFifthOfAnIcon` (SwitcherTests.swift:128, :136).
- 10b0e91 sub-commits: "Accelerate switcher swipes by finger speed — Far icons were hard to reach within the trackpad's width. ... Travel past the row's ends is capped at a quarter icon, so turning back moves the selection at once." and "Swipe like the cursor ... Switcher travel now reproduces macOS's own trackpad pointer acceleration from IOHIDFamily, with the driver's curves and the user's tracking speed, at 100 cursor points per icon."
- What it suggests: "follows the fingers" means a continuous position mapped through pointer acceleration. The spring exists only for the stretch past the ends.

**D. Reduce motion is honoured throughout.**
- SwitcherPresenter.swift:121-127 (no size animation, no spring), OverlayPanel.swift:62 and :98 (no appear, no fade). Present since S3 (cb7b432 hide: "guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { panel.orderOut(nil) ...").
- What it suggests: any new motion is expected to have a Reduce motion path. This is an inference from consistent practice, not a stated rule in architecture.md (grep for "reduce motion" in architecture.md found nothing).

**E. Overlay window config is a deliberate common base.**
- OverlayPanel.swift:13-16 and the 10b0e91 SwitcherPanel header: "the launch overlay's configuration (borderless, non-activating, click-through, above everything on every Space, never key) around Liquid Glass". It was pulled into OverlayPanel in f4590b1 for both switchers. Review fix 92914eb made the interface smaller ("smaller overlay interface": `present(animated:)` was removed in favour of `present(appear: OverlayAppear?)`).
- What it suggests: the switcher window copies the launch overlay's non-activating, click-through setup. The app "never takes focus" (domain-model wording since #5: "It never takes focus").

**F. The animation tuner already hosts switcher knobs.**
- LaunchTuning.swift:4 "Every number that shapes a launch flight and a launch bounce, plus the switcher's swipe acceleration, which the same tuner tweaks." AnimationTuner.swift:206 has a "Switcher swipe" section. The tuner is `#if DEBUG` only (architecture.md:22).
- What it suggests: the codebase already tunes feel through a Debug-only tuner whose defaults are the shipped values. The window switcher follows the same pattern with `WindowSwitcherLook` ("as `LaunchTuning` is for the launch animation: refining it later touches no policy", WindowSwitcherPanel.swift:5-7).

**G. Cost-at-rest practice.**
- docs/performance.md:47 (baseline): "Hands off, 60 s (twice) | 0.77 ms in total (0.001%) | 0 idle wakeups, 1–4 interrupt wakeups per minute". docs/performance.md:21 headline metric: CPU per trackpad frame during ordinary use.
- What it suggests: "costs nothing at rest" has a measured baseline and a method (`Scripts/perf/`) to compare against.

---

### Contradictions

1. **The rule said "No code of ours runs per frame" (ee9a3f0, 2026-10-10), while the app switcher shipped in #5 (10b0e91, 2026-10-12) ran `SwitcherPanel.show` on every trackpad frame.** The wording stayed "per frame" through #5, #11, #15, #16 and #18, and changed only in 28f5a6f/a068ed5 (2026-10-19) to "per display frame" with the explicit per-input-event allowance naming "the switchers' highlight on trackpad frames". So the switcher's per-frame updates were legalised after the fact. In between, the 006 review (b15701e) applied the animation rule to the fade (item 5) but did not flag the per-trackpad-frame `show`. Plan 006 line 1338 (lead) already spoke of "no code of ours per display frame" on 2026-10-11, so the plan author may have read "frame" as display frame from the start. Both readings remain open.

2. **"No code of ours runs per display frame" vs. implicit/`CATransaction` animations.** Today's code drives the icon-grow with CA implicit actions (0.12 s) and the stretch with `CASpringAnimation`. Both play on the render server, so they are consistent with the rule. performance.md:78 shows that keeping the implicit icon-grow animation outweighed a per-frame CPU saving. Not a contradiction in the code; I record it as a tension the record names explicitly.

3. **Highlight legibility fix applied to only one switcher.** PR #24 says "The switcher's clear-glass row highlight could nearly vanish over some backdrops". Its title and diff limit the fix to the window switcher ("The window switcher's highlight carries a faint tint"). The app switcher's `.clear` highlight (SwitcherPanel.swift:23-24) has no tint. Source control holds no statement on whether the app switcher shows the same problem.

---

### Gaps

- No PR review comments or discussion exist for any relevant PR: `gh pr list` shows 0 reviews on all 28 PRs. Only #15 and #27 have a top-level comment, and neither concerns visuals. `gh api pulls/{5,15,16,21}/comments` returned nothing.
- No commit message or code comment gives a reason for: the 150 ms fade length; the 0.12 s icon-grow duration; selected scale 1.12; highlight 92 pt / radius 24; panel radius 34; spring stiffness 420 / damping 22; `.clear` vs `.regular` glass for the highlight. All first appear in S3 (cb7b432) without rationale in the message.
- Searched all commit messages (`--all -i --grep`) for `120 ?hz|promotion|frame rate|stutter|jank|smooth`: the only hits are a068ed5 and 08f5eb0 ("Inflate is one smooth curve..."), both about the launch bounce. Grepped docs/ and Sources for Hz/ProMotion/120 Hz: nothing. Source control has no stated display-refresh or frame-rate target.
- No record of a measured or observed incident (dropped frames, hitches) with the switcher's glass highlight. The only cost record is performance.md:65.
- No tests cover LauncherUI (no LauncherUI test target exists: Tests/ holds only LauncherCoreTests and LauncherPlatformTests). Panel visuals, the fade, GlassClip and the spring are untested. The model-level geometry is tested (SwitcherRowLayoutTests, SwitcherTests).
- No commit records why the highlight is a separate `NSGlassEffectView` moved by frame rather than, for example, a layer transform or a mask. No commit mentions `NSGlassEffectContainerView` or glass merging (`git log --all -i --grep` for glass returned only the commits listed above).
- No commit gives a CPU or energy reason specific to display links beyond filing them under rule "timer". The reason is inherited from the timer ban's "This is what keeps idle CPU at zero."
- The local branch `feature/023-app-selection-grow-animation` has no commits beyond c9125b6 (nothing to read). `origin/feature/019-switcher-highlight-prominence` holds only 408f5b9, which was squashed into 820192a (#24).

---

### Additional Leads (for the Plans investigator)

- **plans/004-launch-icon-animation/plan.md:347**: "`SourcePolicyTests.banned` gains `displayLink` and `DisplayLink`, under the rule "timer". A per-frame callback is the tempting alternative to keyframes, and it would run code of ours on every frame." Also :352 and :526. This appears to be the stated reason for the display-link ban.
- **plans/017-launch-wait-bounce/plan.md:1087**: "The animation bullet is reworded to say what it allows: never per display frame, per input event while the effect shows." **:1196**: "D1: is "never per display frame; per input event while the effect shows" the rule you want written into `docs/architecture.md` for later features too?" (an open question to the user). **:238**: the source scan bans display links "by substring, in comments and `#if DEBUG` code too (F23)". Plan 017's own `.temp/architect/grounding/why*.md` files were committed in 28f5a6f.
- **plans/006-five-finger-tap-and-corner-swipe/plan.md**: :241 (R10 panel requirement: "Liquid Glass panel ... a glass selection highlight slightly larger than..."); :266 (Reduce motion scenario: "with no spring, fade or size animation"); :646 (design decision 8, "The switcher is model state rendered by `LauncherUI`, with AppKit and Core Animation (O5; F24, F26, F27, F32)", which the b15701e dev log cites for keeping the keyed spring); :1178 (the 150 ms fade spec); :1181 (highlight with actions disabled, 1.12× icon); :1338 (tradeoff: "rendering the switcher in AppKit and Core Animation is more imperative than SwiftUI, in exchange for springs and fades played by the render server with no code of ours per display frame, as in the launch overlay"); :1367-1368 (open questions on NSGlassEffectView in a screen-saver-level panel, glass on glass, and the 1.12× feel). The committed `.temp/architect/` design/candidate files for 006 may record the alternatives that were rejected.
- **plans/013-simplify-switchers**: performance.md:78 says plan 013 "keeps unchanged" the icon-grow animation.
- **plans/014-gate-event-tap**: the source of docs/performance.md and the per-frame CPU budget ("Plan 014's budget (0.088 ms per frame) is this no-tap figure plus 0.03 ms", performance.md:74).
- **plans/019-switcher-highlight-prominence** (branch name for PR #24): may explain why the tint went only to the window switcher.
- **plans/012-window-switcher-gesture/.temp/slices/S1.md** (committed in f4590b1): may record why OverlayPanel was extracted.
- Measurement tooling for a future smoothness and cost-at-rest check: `Scripts/perf/` (sampler, mtidle, session.sh, Time Profiler recipe), described in docs/performance.md:5-26.
