# Development logs: Click blocking and forgiving taps

## Specify
- Cross-reference named the wrong 001 requirements → now names R11 finger count, duration and press rule, R20, and the amended 001 non-goal.
- Lone finger in the corner could swallow ordinary clicks → presses with only the anchored thumb down pass; baseline and lone-finger scenarios added.
- Press straddling the window or a drag in progress was undefined → new requirement: a press is blocked or passed as a whole.
- Press-and-hold while blocked was unnamed → scenario: nothing clicks, no gesture fires.
- Tap boundary and finger bounce were undefined → tap defined; a re-landed finger counts once; two quick 1-finger taps scenario.
- R3 scenario unverifiable → outcome tied to the haptic at lift with no added wait.
- Click blocking going live was hidden in the hint requirement → its own requirement; hint requirement covers only the hint, with exact copy.
- Mouse clicks were in scope without a stated problem → mouse clicks, pointer and scrolling are never blocked.
- Accessibility use was unbounded → app uses it only to block clicks, never reads or changes other events.
- First-launch prompt plus hint → window is open after the prompt, hint shows if not granted.
- Missing non-goals and 3-second rationale → added.
- Rejected: continuing 001's requirement numbering. Each plan numbers from R1 and cites the other plan by path.

## Plan
- Grounding: an active mouse-button event tap returns nil from an untrusted process and a listen-only one is created disabled (probed) → Accessibility is the permission the tap needs; the design keeps the permission optional and the tap confined to one adapter.
- Grounding: the TCC Darwin notification `com.apple.tcc.access.changed` is delivered 30 ms after a TCC change on the main queue, while the distributed `com.apple.accessibility.api` is not posted (probed) → the permission port follows that push; no timer, no polling, R7's 5-second bound rides on it.
- Grounding (`why`): the press rule, the button-state sampling and the permission and timer bans were one package for 001's R20 and R22; 002 revokes R20 only → timers and polling stay banned, the frame clock stays the only clock, and the design decides the 3-second window on frames.
- Red-flag screen: candidate-2 made `TouchFrame.buttonDown` mean different things depending on adapter state (information leakage) and reached the filter through a `pressHeld` closure → base from candidate-1, whose `TouchFrame.Press` sum type carries the fact; neither candidate was shallow, pass-through or split by execution order.
- Cross-judge (candidate-1 17/18 vs candidate-2 14/18, agreeing with the orchestrator's 17 vs 13): candidate-2 opened the first-launch window after the prompt, but the shell closes the window when the panel resigns key or an outside click lands, so the system prompt would close it and R10 would fail on hardware → candidate-1's held window kept (`closed | open | heldOpen`, `dismissWindow()` for soft closes).
- Cross-judge: candidate-1 read a frame's press from "withheld" plus the session's button state, so a frame could read a press as a click before the tap dropped it, costing the user both the click and the gesture → the frame's press is derived from `ClickFilter.holding` (`.withheld` / `.passed` / `.nothing`), with the button still down required for `.click` so a release the tap missed heals on the next frame.
- Cross-judge: candidate-1 assumed a resting thumb arrives as `.down` on a fresh recognizer's first frame → `landedAt` is nil on the first frame whatever phase the driver reports.
- Cross-judge: candidate-1's held window could sit over System Settings → a grant closes a held window; the window's own settings buttons close it explicitly before opening a pane.
- Cross-judge: candidate-2 never cleared a passed press whose release the tap missed while disabled, cancelling every later tap until the next reconcile → candidate-1's forget-on-disable kept and extended to passed presses; a new press of the same button also replaces a stale one.
- Cross-judge: candidate-2 keyed dragged events on the press's event number, which the header documents only for down and up → drags keyed by button.
- Grafted from candidate-2: the TCC broadcast is deduplicated in the adapter (`onChange` means "trust changed", so `Launcher` treats the third port like the other two), with an injectable trust reader and a public notification name for the adapter's own `notify_post` test; a self-check pinning both halves of the policy-list edit.
- Verification: `kAXTrustedCheckOptionPrompt` imports as a global `var` that Swift 6 strict concurrency rejects, and its value is `"AXTrustedCheckOptionPrompt"` (checked) → the adapter spells the key out; `CGEventType(rawValue: 34)` is usable in a mask and as a rewrite (checked) → the pressure type sits in the tap's type table.
- Verification: an ordinary process may `notify_post` the TCC name (checked) → the real permission adapter's push path is tested in-process.
- Verification: `docs/architecture.md` "The app asks for no permission" contradicted R9 → rewritten; the concurrency section names the tap thread and the TCC push; `docs/domain-model.md` gains *Blocking window*.
- Rejected grafts, recorded in the Synthesis decision: restarting the blocking window on reconcile (breaks R4), a third observation loop, a separate hint view, leaving the pressure type out of the mask, a stored "prompted" flag, polling trust.
- No runner dropout; both candidates produced output on the first dispatch.
- Test planner: R6's "clicks from a mouse MUST NOT be blocked" contradicted the accepted tradeoff (no public event field names the device, and the subtype probe needs trust) → R6 amended to the condition the design guarantees: nothing but the anchored thumb on the trackpad; flagged for the human to confirm.
- Test planner: R9's "MUST NOT read … any other event" contradicted the tap's mask (drags, pressure) and the drag rewrite of a blocked press → R9 amended to name what belongs to a press; flagged for the human to confirm.
- Test planner: the prompt-before-first-save order was unobservable → `InMemoryAccessibilityPermission.onPrompt` added to the fake and the handles table (T42).
- Test planner (rejected): a `tapCreate` refusal right after a grant has no seam, no fake and no retry → no change: nothing pushes "the tap is now allowed", a retry would be the app's only timer, and `AXIsProcessTrusted` and `tapCreate` consult the same TCC state; the manual R7 step checks it and the fallback (re-read trust on the next push) stays in the open questions.
- Test planner (rejected): the merge across trackpads (`anyTrackpadBlocksClicks()`) has no in-process seam → no change: it is one `contains` over the sessions' flags and a seam for it would be a pass-through; checked manually with a Magic Trackpad under R4.
- Test planner (round 2): the two open questions the amended R6 and R9 now answer were stale, and the tradeoff on mouse clicks read as a concession → replaced by one note recording the amendments for the human's confirmation and the subtype probe as a future option; the tradeoff cites R6.
- Test planner (round 2): `docs/domain-model.md` *Click blocking* still said mouse clicks are never blocked, contradicting the amended R6 → the entry follows R6's wording; the design's Phase D paragraph names it. No signature or seam changed, so the testing sections were not re-run.
