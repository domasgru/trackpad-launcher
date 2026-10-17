# Why: source control evidence (git history, PRs, code comments, tests, docs/)

Scope: source control only. I used no plans/ or research/ content as evidence. The `docs/` files are committed, outside `plans/`, and their history is in git, so I include them and label them as docs.

## Source
Source control: git history on all branches (main, plus the remote `origin/feature/*` branches, which still hold the commits from before each squash), `gh pr view` for PRs #1–#17, inline comments in the target and neighbouring files, tests, `docs/architecture.md` and `docs/domain-model.md`.

## What I Searched

- `git log --oneline` (HEAD) and `git branch -a`. The remote feature branches survive, so the slice commits behind each squash merge can be read.
- `git log --follow --oneline -- LauncherKit/Sources/LauncherPlatform/ClickTap.swift` returned 10b0e91, 1cf9c4b.
- `git log --all -- ClickTap.swift ClickFilter.swift ScrollFilter.swift DockSwipeFilter.swift` returned 0765cf4, 6ed0d9c, 24993a0 (branch 001), 1cf9c4b, 9d2f330, 9044785 (branch 006), 10b0e91. **No commit after 10b0e91 (2026-10-12) touches the tap or any of the three filters.**
- `git log --oneline` on GestureRecognizer.swift returned 1cf9c4b, 10b0e91, d4edfba, b67a5ca, 858c61d, 6054488, 18acef7. `git log -G 'blocksClicks|blocksDockSwipes|isRealLanding|landingTime|clickBlockingWindow'` narrowed this to 1cf9c4b, 10b0e91, 858c61d, 18acef7.
- `git log --all` on FrameStream.swift and MultitouchTrackpads.swift (18 commits, listed under Indirect).
- Full messages via `git log --format=%B` for 1cf9c4b, 10b0e91, 858c61d, and the slice commits 7c7f7c2, d207504, 3ce3f64, b43619b, 0765cf4, 6ed0d9c, 24993a0, def630e, 4552ceb, f2c576f, 9d2f330, b15701e, 9044785, f38cf95, fc2e216, 879d03c, f7a8a4f, e85019b.
- Full code diffs: 6ed0d9c (ClickTap born), 0765cf4 (ClickFilter, Press sampling, blocksClicks born), 24993a0 (first-frame landing fix), 9d2f330 (ScrollFilter), 9044785 (DockSwipeFilter, types 29/30), f2c576f (main-queue hop), fc2e216 (window swipe answer), f7a8a4f (scrolling fingers still swap), and the docs part of d207504.
- `git log -S` for these exact strings: 'has not seen yet', 'accepted', 'reaches the tap between frames', 'harmless stray mouse-up', 'The pad sends no frames while nothing touches it', 'opens that window like any other', 'stays suppressed, momentum included', 'decided when it begins', and three test names (listed under Indirect).
- `git log -G 'click tap|event tap|extra thread' -p -- docs/architecture.md`, on main and on branch 001.
- `git blame -L 1,89` on ClickTap.swift.
- `gh pr list --state all` and `gh pr view` (body, comments, reviews) for #1, #5, #6, #7, #9, #11, #12, #14, #15, #16, #17. No PR has review threads. Only #15 has a comment, and it is about window-swipe confirmation, not the tap. `gh issue list` printed nothing (no issues, or none visible).
- Commit-message greps (`--all -i`): 'tap'; `-E 'disable|re-enable|reenable|timeout|incident|revert|cpu|energy|idle|battery|high-volume|volume|gate'`; `-E 'scroll|mask|run loop|thread|latency|lag|stall'`.
- Code greps across LauncherKit/Sources and Tests: `tapEnable|frame thread|tap thread|own thread|while armed|tapDisabled`, `enabl`, `revoke`, `forgetSwipe|forgetGesture|forgetHeldPresses`, the same-frame and resting-finger race test names, and `onLanding`.
- Read in full: ClickTap.swift, ClickFilter.swift, ScrollFilter.swift, DockSwipeFilter.swift, FrameStream.swift, MultitouchTrackpads.swift, Touch.swift, GestureRecognizer.swift, docs/architecture.md, and the docs/domain-model.md entries "Click blocking", "Blocking window", "Anchored thumb", "Thumb tap".
- Tests read: ClickBlockingRecognizerTests (incl. ClickFilterTests, PressSamplingTests), ClickBlockingTests, ScrollFilterTests, ScrollSuppressionTests, DockSwipeFilterTests, DockSwipeBlockingRecognizerTests, WindowSwipeBlockingTests (part), DeviceSessionAnswerTests, TapEventTests (head), SourcePolicyTests (lists), InMemoryAdapters (InMemoryTrackpads), TouchScript (head), and the relevant parts of GestureRecognizerTests, SwapTests and SwapRecognizerTests.

---

## Direct Evidence Found

### D1. The tap's lifetime is "from the run that armed click blocking until the next run", installed and removed on main
- **What it says** (ClickTap.swift:8–11, blamed to 1cf9c4b, written in slice 6ed0d9c "S4: The click tap for real", domasgru, 2026-10-09):
  > "It exists from the `run` that armed click blocking until the next `run`.
  > Threads: installed and removed on main. Its callback runs on the tap's own `userInteractive` thread, whose run loop holds only this tap's source and ends when the tap is removed. That thread retains the ClickTap, so no callback outlives the object behind its `userInfo`."
- ClickTap.swift:19 (1cf9c4b): `/// Writer: main (install, remove). The tap thread only re-enables.` (on `port`)
- ClickTap.swift:21: `/// Set by the tap thread; main stops it on remove.` (on `runLoop`)
- ClickTap.swift:51: `/// Main. Idempotent. Never relies on macOS to stop delivery after a revoke.` (on `remove()`)
- **Relevance:** This is the only statement in the code of who may touch the tap's port: main installs and removes, and the tap thread only re-enables. The frame thread is not listed as a writer. The comment states the rule. It does not give a reason.

### D2. "Armed" is defined as gestures active plus Accessibility granted, and the tap is created with the run, before any frame
- Launcher.swift reconcile (current file, around lines 221–224): `// Blocking needs gestures active and access granted; without either, presses are plain clicks.` with `blockClicks: active && granted`.
- MultitouchTrackpads.swift:67 (6ed0d9c): `/// A click tap exists afterwards iff `blockClicks`, the system allows it and a trackpad is running.` Line 87: `if blockClicks && !devices.isEmpty { clickTap = ClickTap.install() }`. The install happens before any device is started (lines 88–115).
- Ports.swift:35–38 (introduced in 0765cf4): "Forgets every session, removes the click tap, stops every device, then starts exactly `trackpads` with a fresh recognizer each and, if `blockClicks` and `trackpads` is not empty, a fresh click tap. Idempotent. The tap needs Accessibility. If the system refuses it, nothing is filtered, presses are sampled as before, and taps behave exactly as without access."
- Test `ClickBlockingTests.aTapRightAfterAccessIsGrantedBlocksItsPressWithNoFrameBeforeTheThumb` (ClickBlockingTests.swift:66–72). Added in 24993a0, whose message is "Open the blocking window for a thumb landing on a recognizer's first frame." Right after the grant, the very first tap's press is expected to be `[.drop, .drop]`.
- Test `blockingIsArmedOnlyWhileGesturesAreActiveAndAccessIsGranted` (ClickBlockingTests.swift:115–129) and `blockingFollowsTheGrantAndTheRevokeWithoutRelaunching` (131–146).
- **Relevance:** These show the shape that exists now (armed means installed and enabled, decided per run) and the behaviour the tests pin down: a press on the first frames after arming is caught.

### D3. The one extra thread exists only while armed and sleeps until an event arrives. The "no timers / idle CPU at zero" rule
- docs/architecture.md:20. The text was first added in d207504 ("Design click blocking and forgiving taps", 2026-10-09). Its event list was extended in 10b0e91:
  > "No timers, no polling, no background loops: every input is a push (...). This is what keeps idle CPU at zero. The one extra thread is the click tap's run loop, which exists only while click blocking is armed and sleeps until an event arrives (a press, its drags and pressure, a scroll event, or a system gesture event)."
- The original wording (d207504 / 1cf9c4b) ended "...and sleeps until an event arrives." The parenthetical list was added in 10b0e91 (diff of docs/architecture.md in that commit).
- SourcePolicyTests.swift:30–35 ban `Timer`, `asyncAfter`, `makeTimerSource`, `displayLink`, `DisplayLink` (rule "timer") and `Task.sleep` (rule "polling"). Line 53 bans `nonisolated(unsafe)` with rule "one writer per field".
- **Relevance:** This states the design goal behind a thread that lives only while armed: no idle CPU when nothing arrives. It says nothing about event volume while armed. It also limits gating designs: a gate that closes after a delay would need a timer, which is banned.

### D4. The tap mask began minimal and grew. Scroll (22) and gesture/Dock control (29, 30) were added later
- 6ed0d9c (S4, 2026-10-09). The tap comment was "an active session tap over mouse buttons, drags and pressure only", and the mask doc said: "There are no keyboard, scroll or plain-move types."
- 9d2f330 "Scroll suppression in the one tap (S4)" (2026-10-11) added `.scrollWheel`. The doc became "There are no keyboard or plain-move types." Commit message: "ScrollFilter suppresses trackpad scrolling under the click-blocking rule and for the whole of a swipe, with its momentum; the tap parses CGEvents once through TapEvent with scrollWheel confined to ClickTap."
- 9044785 "Block the system's desktop swipes during gestures" (2026-10-12) added types 29 and 30. Message: "macOS can count the anchored thumb as a finger, so thumb plus two sliding fingers can read as its three-finger swipe between desktops. The tap now also takes the system's gesture and Dock control events and drops Dock swipes while a thumb is anchored with another finger down, or a swipe is on. Each Dock swipe is judged on its opening event and kept whole, so the Dock is never stranded between desktops."
- TapEventTests.swift:8–10 pins the mask: `let bits: [UInt64] = [1, 2, 3, 4, 6, 7, 22, 25, 26, 27, 29, 30, 34]` in `maskCoversPressesTheirReleasesDragsPressureScrollAndGesturesOnly`. Lines 13–17, `everyMaskedTypeParses`, enforce "the tap is never sent a type the parser does not read" (ClickTap.swift:110–111).
- SourcePolicyTests.swift:79–81 confines `tapCreate` and `CGEventTapCreate` to ClickTap.swift ("R9 the one event tap") and `scrollWheel` to ClickTap.swift ("scrolling is read only by the one event tap"). Line 49 bans `ScrollWheel` elsewhere.
- **Relevance:** The high-volume types (scroll, gesture) arrived in 9d2f330 and 9044785. Both were added to the existing tap ("the one tap"), and its lifetime was not changed. No commit message gives a reason for keeping one tap rather than a second or gated one. The search covered "volume", "cpu", "energy", "idle" and "gate" in commit messages.

### D5. The re-enable on tapDisabledByTimeout / tapDisabledByUserInput, and what it forgets
- ClickTap.swift:65–71. Lines 65, 67 and 70 come from 1cf9c4b / 6ed0d9c. Lines 66, 68 and 69 come from 10b0e91 (9d2f330, 9044785).
  ```swift
  if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      // Releases and scroll phases may have passed while the tap was disabled.
      filter.withLock { $0.forgetHeldPresses() }
      scrollFilter.withLock { $0.forgetGesture() }
      dockSwipeFilters.withLock { $0 = [:] }
      port.withLock { $0.map { CGEvent.tapEnable(tap: $0.value, enable: true) } }
      return .passUnretained(event)
  }
  ```
  The original 6ed0d9c comment was "// Releases may have passed while the tap was disabled."
- ClickFilter.swift:73: "The system disabled the tap, and releases may have passed meanwhile. Forget every held press."
- ScrollFilter.swift:64: "The system disabled the tap; events may have passed unseen. Forget the gesture in progress (under-blocking)."
- DockSwipeFilter.swift:29: "The system disabled the tap; events may have passed unseen. Forget the swipe in progress (under-blocking)."
- Tests: `forgettingHeldPressesLetsALostReleasePassAndClearsHolding` (ClickBlockingRecognizerTests.swift:182–194), `forgettingTheGestureTreatsTheRestAsFirstSeenMidWay` (ScrollFilterTests.swift:47–57), `forgettingTheSwipeTreatsTheRestAsFirstSeenMidWay` (DockSwipeFilterTests.swift:31–36).
- PR #7 body, "Not covered" (merged 2026-10-13): "`ClickTap.handle` re-enabling a disabled tap: it needs Accessibility trust."
- **Relevance:** This is the defensive branch. The written reason covers what to forget and why: events missed while disabled, with under-blocking chosen as the failure direction. No commit, PR or comment names an incident or a timeout that was actually seen. Commit-message greps for "timeout", "disable", "incident" and "revert" found nothing about it. The branch is in code from the first tap commit, 6ed0d9c. **The forgetting is tied to system-initiated disable events only.** Nothing in the code or history covers an intentional disable by the app itself. That would be a new case.

### D6. ClickFilter: a press is blocked or passed whole, decided at the press, and the flag is ignored at release
- ClickFilter.swift:43–50 (0765cf4, "S3: Click blocking decided in the core", 2026-10-09):
  > "// A new press of a button ends any stale one."
  > "// That button is up, whatever came before. The press is blocked or passed whole: the flag is ignored."
- ClickFilter.swift:55: "// A Force Click's stages belong to its press." Pressure is dropped only while a press is withheld.
- PointerVerdict `.passAsMove` doc (ClickFilter.swift:28): "Delivered as a plain pointer move: the pointer keeps moving, and no app sees a drag whose press it never got."
- docs/domain-model.md "Click blocking" (sentence from d207504 onward): "A press is blocked or passed whole."
- Tests: `aPressIsBlockedOrPassedAsAWholeWhateverTheFlagDoesBetween` (ClickBlockingRecognizerTests.swift:120–135). `aPressAcrossTheThreeSecondMarkIsBlockedWholeAndStillCountsAsTheTap` (ClickBlockingTests.swift:58–64). `dragsBecomeMovesOnlyDuringAWithheldPressOfTheSameButton` (152–166). `pressureIsDroppedOnlyWhileAPressIsWithheld` (168–180).
- **Relevance:** The rule is stated directly ("blocked or passed whole") and pinned by tests. To keep a press whole, the filter has to see both the press and its release. That is why the per-button state (`held`) must survive between them.

### D7. The frame thread reads the filter's `holding`, and the meaning of `.nothing` versus `nil` (filter live versus no filter)
- ClickTap.swift:13: `/// Writer: the tap thread. Reader: frame threads.` (on `filter`). ClickTap.swift:48–49: `/// Frame thread.` `var holding: ClickFilter.Holding { filter.withLock { $0.holding } }`.
- FrameStream.swift:71–72: `/// Frame thread: the click filter's summary when a tap is live, nil otherwise.` `var holding: ClickFilter.Holding? { clickTap?.holding }`. FrameStream.swift:88: `let press = TouchFrame.Press(holding: session.holding, buttonDown: anyMouseButtonDown())`.
- Touch.swift:67–71 (0765cf4, `case .passed, nil` merged in 24993a0):
  > "The one precedence rule, used by both hardware adapters. `holding` is the click filter's summary, nil when no filter is live (no tap, no permission). A withheld press is `.blocked` whatever the button state reads; a passed press is `.click` while the button is still down (so a release the tap missed heals on the next frame); a press the filter has not seen yet is nothing (it reads `.click` once the tap passes it, or `.blocked` once it drops it). Without a filter the button state alone decides."
- Test `PressSamplingTests.holdingAndButtonStateDecideWhatAFrameReads` (ClickBlockingRecognizerTests.swift:209–224) pins `(.nothing, true) -> nil` but `(nil, true) -> .click`.
- FrameStream.swift:93: `/// A state query on the session's event source, no permission: the no-tap path and the "still down" check of a passed press.`
- **Relevance:** When a tap is live, a held button that the filter has not seen reads as no press at all. Only `nil` (no filter) falls back to the button state. The code does not consider a tap that exists but is disabled. *(Inference from code, not stated history: if a gated tap left `holding` at `.nothing` while disabled, a press delivered to apps in that period would never read as `.click` and would not cancel a tap. Under the current design the tap never misses a press while armed, apart from system disables.)*

### D8. ScrollFilter: never relaxes inside a gesture, and a gesture first seen mid-way is stilled
- ScrollFilter.swift:40–48, 53 (9d2f330, 2026-10-11):
  > "// Never relaxes inside a gesture: a passing one that meets blocking mid-way is stilled."
  > "// A gesture first seen mid-way was already seen by apps: only stilling keeps it whole."
  > "// Momentum inherits its gesture's treatment and never escalates; unknown coasting is never interrupted."
- ScrollVerdict `.passStill` doc (ScrollFilter.swift:21): "Delivered with every delta zeroed: the app's gesture ends cleanly and nothing moves." ClickTap.swift:231–232: "`.passStill` zeroes every delta field in place and passes the event, so the app's gesture closes cleanly with nothing moving. Nothing is ever posted."
- docs/domain-model.md "Click blocking" (sentence from 0451f0f / 10b0e91): "a scroll suppressed at any point stays suppressed, momentum included, until its fingers lift, and a scroll that began unsuppressed coasts to a stop as usual."
- Tests (ScrollFilterTests.swift): `aWheelNeverScrollsAwayAndAGestureIsJudgedOnItsOpeningEventThenKeptWhole` (10–25), `aGesturePassingWhenBlockingArrivesIsStilledToItsMomentumsEnd` (27–35, incl. `run([(.fingers(.changed), true), (.fingers(.ended), false)]) == [.passStill, .passStill]`), `momentumFollowsItsGestureAndNothingKnownIsNeverInterrupted` (37–45).
- Tests (ScrollSuppressionTests.swift): `aLateSwipeScrollsOnlyUntilItBeginsThenStillsThePageThroughTheLiftAndItsMomentum` (47–62), `coastingFromBeforeIsNotInterruptedWhenTheThumbLands` (98–108), `withTheWindowSwipeOffAFlickWithinTheWindowDoesNotCoastAfterTheLift` (80–96).
- **Relevance:** The filter's stated rule already covers "a gesture first seen mid-way" (`stage == nil`, a mid-gesture phase, blocking true → `.stilled`). The same path runs when the tap is re-enabled after a system disable. Unknown momentum (`stage == nil`) always passes. A tap enabled mid-scroll would land on these same paths.

### D9. DockSwipeFilter: judged once at the opening event and kept whole, so a swipe first seen mid-way passes
- DockSwipeFilter.swift:11–12 (9044785, 2026-10-12):
  > "A Dock swipe is judged once, on its opening event, and kept whole: dropping one already under way could leave the Dock stranded between two desktops. So a swipe first seen mid-way always passes."
- ClickTap.swift:17: "One filter per gesture event type, since a Dock swipe may arrive as both." ClickTap.swift:152: "A Dock swipe with an unknown phase reads as `.changed`, which the filter never starts a drop on."
- ClickTap.swift:82: "// Its own flag: Dock swipes are blocked for as long as a thumb is anchored, not only inside the window."
- Tests (DockSwipeFilterTests.swift): `aSwipeOpeningWhileBlockingIsDroppedWholeEvenIfBlockingEnds`, `aSwipeOpeningUnblockedPassesWholeEvenIfBlockingArrives`, `eachSwipeIsJudgedAfreshOnceTheLastEnded`, `aSwipeFirstSeenMidWayAlwaysPasses`.
- docs/domain-model.md "Click blocking" (sentence from 9044785): "A system swipe is blocked or passed whole, decided when it begins."
- **Relevance:** The reason is given directly: dropping mid-way strands the Dock between desktops. A tap that misses a Dock swipe's `began` would pass that swipe whole. That is the stated safe direction.

### D10. "The accepted race": a press that reaches the tap on or before the landing frame
- TouchScript.swift:7–9 (0765cf4):
  > "`.onLanding`: the press starts on the landing frame, before the tap could know a finger is down (the accepted race). `.firm`: from the frame after the first landing to the last lift, as a real firm tap."
- InMemoryAdapters.swift:80–82 (0765cf4):
  > "Scripted frames carry the physical press as any non-nil `press`. Per frame, as on hardware: a press edge reaches the tap between frames, so it is decided on the flags the previous frame left, merged across trackpads; then the frame's press is re-sampled through the filter's `holding`, as the frame callback does."
- Test `aPressReachingTheTapBeforeTheLandingFrameIsAClickThatCancelsTheTap` (ClickBlockingTests.swift:108–113) expects `pressVerdicts == [.pass, .pass]` and nothing brought to front.
- Test `aBlockedPressIsPartOfTheTapAndADeliveredClickCancelsIt` (ClickBlockingRecognizerTests.swift:98–114) is parameterised on `onLanding`.
- Test `GestureRecognizerTests` line 133 is parameterised on `[TouchScript.ClickTiming.onLanding, .firm, .midway]`.
- **Relevance:** This is the only place source control uses the phrase "accepted race". It accepts that a press whose edge comes before the frame showing the finger is decided on the earlier flags. It passes and cancels the tap. The tap's own latency is zero here, because the tap is already enabled. The race is between the press edge and the frame callback.

### D11. Thumb and finger landing on the same frame
- GestureRecognizer.swift, `.idle` case: `state = down.count == 1 ? .armed(anchor) : .spoiled(anchor)`. A thumb that lands with another contact on the same frame is spoiled, not armed.
- Test `thumbAndFingerLandingInTheSameFrameNeverFire` (GestureRecognizerTests.swift:64–75). It was first added in 4552ceb ("S1: LauncherKit package, gesture recognizer and source policy gate", 2026-10-09, branch 001).
- Test `aThumbLandingInTheSameFrameAsTheFingersDoesNotSwap` (SwapTests.swift:182–193). It was added in e85019b "Swap: no minimum rest before the thumb tap" (2026-10-14), whose message says: "A quick thumb tap right after the fingers land now swaps. Only the landing order counts: fingers in an earlier frame than the thumb."
- Blocking in that case: in the final `else` branch of `step`, `state.thumb` for `.spoiled(anchor)` is the anchor (`default: anchor?.id`). So `blocksClicks` is true from that frame, as long as the thumb's landing time is known and another contact is down. This is read from the code. I found no test that pins `blocksClicks` for the same-frame landing.
- **Relevance:** Source control records the same-frame case as "never fires / never swaps". I found no commit or comment that frames it as a race the tap's timing accepts. I also found no test that pins blocking in that case.

### D12. Thumb landing under resting fingers
- docs/domain-model.md "Click blocking" (sentence from e045655 / 858c61d, 2026-10-13/14): "A thumb that lands under resting fingers opens that window like any other, so before a series starts the thumb rules alone apply."
- docs/domain-model.md "Thumb tap": "A press during the thumb tap, withheld or delivered, is part of it: unlike a tap, a thumb tap is never cancelled by a click."
- GestureRecognizer.swift `State.thumb` doc: "The thumb the blocking rules follow: the anchor, the thumb under a rest, or the thumb under an unconfirmed window swipe." The `.rest` case returns `rest.thumb?.id`. A series (`rest.isSeries`) blocks clicks and Dock swipes outright.
- Test `beforeTheFirstSwapTheThumbRulesBlockClicksForThreeSecondsAndDockSwipesWhileTheFingersAreDown` (SwapRecognizerTests.swift:29–42). Fingers land at 0 ms and the thumb at 150 ms. At 200 ms clicks and Dock swipes are both blocked. At 3200 ms only Dock swipes are. At 4000 ms neither is.
- Test `fromTheFirstSwapUntilTheFingersLiftClicksAndScrollsAreBlocked` (SwapTests.swift:315–334).
- Commit f7a8a4f "Swap: moving or scrolling fingers still swap" (2026-10-14): "A thumb tap under two fingers swaps whether they rested still, scrolled first, are scrolling during the tap, or moved between taps. Only a third finger stops a series. Series blocking is unchanged." Test `fingersScrollingWhileTheThumbTapsStillSwap` (SwapTests.swift, added in f7a8a4f).
- PR #12 body, "Blast Radius: recognizer": "A regression would show up as misfired or missed tap gestures, or as clicks or scrolling blocked while two fingers rest."
- **Relevance:** In this case blocking starts from a frame on which other fingers may already be scrolling. The ScrollFilter "never relaxes" path (D8) is what stills an in-progress scroll then. The domain sentence says the thumb under a rest "opens that window like any other". Source control does not call this a race.

### D13. Window swipe: blocking starts one frame late, by design, and the frame thread never waits
- docs/architecture.md:18 (from 18acef7 / fc2e216): "...the frame thread hands the reply to that trackpad's recognizer before its next frame. ... Until the answer arrives the slide blocks only by the thumb rules, and the frame thread never waits for it. State shared with that thread lives behind a `Mutex` with one writer."
- fc2e216 message: "The recognizer begins a slide up or down unconfirmed, blocking only by the thumb rules, until answerWindowSwipe settles it: confirmed, it blocks from the next frame".
- Test `aStartConfirmedAtOnceBlocksClicksFromTheNextFrameUntilTheLift` (DeviceSessionAnswerTests.swift:102–108). Test `aPressOnTheFrameAfterALateStartPassesAndCancelsTheWindowSwipeSilently` (WindowSwipeBlockingTests.swift:39–61) expects `pressVerdicts == [.pass, .pass]`.
- **Relevance:** This is a written rule: the frame thread never waits on main. It is also a precedent where a one-frame lag before blocking is accepted and tested (a press on that frame passes and cancels).

---

## Indirect / Circumstantial Evidence

### I1. A run tears the tap down mid-flight, and the stray release is called harmless
- MultitouchTrackpads.swift:72–74 (6ed0d9c): `// A withheld press's release may now reach apps: a harmless stray mouse-up.` followed by `clickTap?.remove()`.
- **Suggests:** The authors accepted that removing the tap mid-press lets the release of a withheld press through, and judged it harmless. The comment covers only the `run` teardown path.
- **Alternative reading:** "Harmless" was judged for a rare event (settings change, hot-plug, wake). It may not hold if disabling happened often, on every gate close. History says nothing about frequency.

### I2. Reconcile avoids needless re-runs because a re-run ends in-flight state
- Launcher.swift around lines 197–199: "A reconcile that would run them the same way leaves them, and any swipe in progress, alone: preference and trust notifications also fire for writes that change nothing here."
- f38cf95 message (branch 006, 2026-10-12): "...and a reconcile that changes nothing no longer restarts recognition and closes the switcher."
- **Suggests:** Restarting the tap and recognizers at the wrong moment was seen as harmful enough to guard against.

### I3. Lock discipline between the tap thread and the frame threads
- ClickTap.swift:74 (10b0e91; the original 6ed0d9c wording was "Read before the filter lock so no two locks are held at once."): "// Read once, before either filter lock, so no two locks are held at once."
- FrameStream.swift:98–102: "Whether some running trackpad is inside its blocking window, merged across trackpads at the read. Copies the sessions out first, so no lock is held while another is taken."
- FrameStream.swift:19–22: `blocking` and `blockingDockSwipes`: "Writer: this device's frame callback. Reader: the click tap's thread."
- FrameStream.swift:81–84: `sessions` is "The only state shared with the frame thread: written by `run` (main), read by the callback and the click tap."
- docs/architecture.md:18: "State shared with that thread lives behind a `Mutex` with one writer." SourcePolicyTests bans `nonisolated(unsafe)` with rule "one writer per field".
- **Suggests:** Each shared field has one writer. Enabling or disabling the port from the frame thread would make the frame thread a second writer of the tap's enabled state, beside main (install/remove) and the tap thread (re-enable). That conflicts with the ClickTap.swift:19 comment.
- **Alternative reading:** The "one writer" rule is about Swift fields behind Mutexes. A `CGEvent.tapEnable` call is a system call, not a Swift field. The comment at :19 sits on the `port` Mutex, which holds the reference, not the enabled state. Whether the rule was meant to cover tap enablement is not stated.

### I4. The frame thread must not wait (a general principle that may bear on calling into the system from it)
- docs/architecture.md:18: "...and the frame thread never waits for it." This is stated about the window swipe answer.
- MultitouchTrackpads.swift:6 and docs/architecture.md:18: frames are recognised on the framework's own thread, and only recognised events hop to main.
- **Suggests:** Keeping blocking calls off the frame thread is a stated value. Source control does not say whether `CGEvent.tapEnable` blocks or how long it takes.
- **Gap:** I found no measurement or comment on tapEnable's cost or thread-safety.

### I5. The in-memory test adapter models the tap as always-on while armed
- InMemoryAdapters.swift:12–16: "The fake click tap: armed iff the last `run` asked for it with trackpads." and "Armed and disarmed with `clickFilter`: one tap decides both." (the scroll filter).
- InMemoryAdapters.swift:103–117 `deliverPressEdge` uses `blocking.values.contains(true)`, the flags of the previous frame, merged across trackpads.
- InMemoryAdapters.swift:119–123 `scroll(_:)`: "A scroll event reaching the fake tap on the flags the frames so far left, merged across trackpads. nil when no tap is armed, so the event reaches apps untouched."
- **Suggests:** Every model-level blocking test (ClickBlockingTests, ScrollSuppressionTests, SwapTests, WindowSwipeBlockingTests) assumes a tap that sees every event while armed. A gated tap has no counterpart in the fake, so the suite would not catch gate-timing regressions unless the fake changes.

### I6. Test-coverage gaps the authors named (PR #7)
- PR #7 body, "Not covered": "`ClickTap.handle` re-enabling a disabled tap: it needs Accessibility trust." "`MultitouchTrackpads.run`: it needs real devices." "`DeviceSession` click blocking across trackpads: a test would need the process-wide session registry and a serialized suite, which costs more than the two lines it guards."
- **Suggests:** The real tap's enable/disable path and its cross-thread behaviour have no automated test. Changes there can only be checked by hand on hardware.

### I7. The "first frame" premise behind blocking-window timing
- GestureRecognizer.swift:78–79 (24993a0 wording, moved into the contact book in 858c61d): "The pad sends no frames while nothing touches it, so a contact landing on the first frame really landed now. Only an already-resting contact (`.down`) has an unknown landing time."
- TouchScript.swift (24993a0): "The first frame is the first contact's landing: a pad delivers no frames while nothing touches it."
- Tests: `aThumbLandingOnTheFirstFrameOpensAWindow`, `aThumbAlreadyRestingOnTheFirstFrameOpensNoWindow` (ClickBlockingRecognizerTests.swift:78–96), `aReconcileUnderARestingThumbDoesNotRestartTheWindow` (ClickBlockingTests.swift:148–164), `aThumbAlreadyRestingWhenRecognitionStartedBlocksToo` (DockSwipeBlockingRecognizerTests.swift:24–30). In that last test, Dock-swipe blocking has no landing-time requirement.
- **Suggests:** `blocksClicks` can become true on the very frame that shows a thumb plus another contact (for example, the second frame of `aThumbLandingOnTheFirstFrameOpensAWindow`, 10 ms in). A gate driven from frames would need to be open by the next press edge after that frame.

### I8. Merge-danger notes that name scroll and click blocking as the area at risk
- PR #15 "Blast Radius: gestures": "Prefactor touches the shared swipe recognizer, selection rule and overlay panel, so the app switcher and scroll/click blocking could regress."
- PR #11 "Blast Radius: Swipe": "Tap gestures, click and scroll blocking with the switch on, and the other settings are untouched."
- PR #12 (quoted in D12).
- **Suggests:** Every past feature PR treated scroll and click blocking as a sensitive area. None of them changed the tap's lifetime.

### I9. Origins of the race-related tests (by `git log --all -S`)
- `thumbAndFingerLandingInTheSameFrameNeverFire`: hits in 4552ceb, 1cf9c4b, 0451f0f, 10b0e91. The 0451f0f hit is a design commit, likely a plan doc citing the name. I did not open it (plans scope).
- `aPressReachingTheTapBeforeTheLandingFrameIsAClickThatCancelsTheTap`: 0765cf4, 1cf9c4b.
- `aThumbLandingInTheSameFrameAsTheFingersDoesNotSwap`: e85019b, 858c61d. A hit in e045655 ("Plan: thumb tap to swap apps") also exists. I did not open it (plans scope).

### I10. Minor code observation
- ClickTap.swift:69 resets the Dock swipe filters with `dockSwipeFilters.withLock { $0 = [:] }`. `DockSwipeFilter.forgetSwipe()` (DockSwipeFilter.swift:30) is called only from tests (DockSwipeFilterTests.swift:34). The effect is the same. I note it only so the synthesizer knows `forgetSwipe` has no caller in production code.

---

## Contradictions

- **None between source-control items on the tap's lifetime.** Every source-control statement says the tap lives for the whole armed run: ClickTap.swift:8, MultitouchTrackpads.swift:67, Ports.swift:35–38, docs/architecture.md:20, InMemoryAdapters.swift:12.
- **The question's premise has no source-control support.** The question says "it was decided that the tap must not be enabled or disabled from the frame thread". No commit message, PR body, PR comment or code comment says this. The closest are ClickTap.swift:19 ("Writer: main (install, remove). The tap thread only re-enables."), ClickTap.swift:9 ("installed and removed on main") and the one-writer rule (I3). Those say who may write, not why the frame thread may not. If the decision is written down, it is outside my source (see Additional Leads).
- **Tension, not contradiction:** docs/architecture.md:20 justifies the tap's thread by "sleeps until an event arrives ... keeps idle CPU at zero". Since 9d2f330 and 9044785, though, the tap receives every trackpad scroll event and every system gesture event (types 22, 29, 30) for as long as gestures are active and Accessibility is granted, including during ordinary scrolling with no thumb anywhere. The doc's event list was updated in 10b0e91 to name these events, and the "idle CPU at zero" framing was kept. No commit addresses the cost of those events while not idle.

---

## Gaps

- "frame thread" together with tapEnable / enable / disable: searched code comments (`rg tapEnable|frame thread|tap thread|own thread|while armed|tapDisabled`, `enabl`) and commit messages (`--grep` for disable/re-enable/gate/thread). **Nothing explains why the frame thread may not enable or disable the tap.**
- Why the tap has its own thread rather than main: the only text is ClickTap.swift:9–11 (what it does: own userInteractive thread, run loop holds only this source, thread retains the ClickTap so no callback outlives `userInfo`) and docs/architecture.md:20 ("the one extra thread"). **No commit message or PR gives the reason** (for example, avoiding main-thread stalls that would trigger `tapDisabledByTimeout`). The slice commit 6ed0d9c that created it has the one-line message "S4: The click tap for real".
- An incident behind the timeout/user-input re-enable: none found. Searched commit messages for 'timeout', 'incident', 'revert', 'disable'. The branch exists in the first commit of the file (6ed0d9c). It is not a later fix.
- Event-volume or CPU concerns about scroll and gesture events in the tap: the message grep for 'volume|cpu|energy|idle|battery|high-volume' matched nothing relevant. The only 'gate' matches were "source policy gate" (4552ceb) and "gated by run generation" (f2c576f).
- PR review discussion: no PR has review threads. PR #15 has one comment, unrelated. PRs #1 and #5 (the two that touch ClickTap.swift) have no comments or reviews. Their bodies are short summaries ("optional Accessibility permission that blocks trackpad clicks for 3 seconds after the thumb anchors"; "Trackpad scrolling is suppressed under the click-blocking rule and for the whole of a swipe").
- GitHub issues: `gh issue list --state all` printed nothing.
- Tests for an enabled-but-gated tap, enable latency, or a press arriving between a gate opening and the first press: none exist, and the in-memory fake has no such concept (I5).
- A test pinning `blocksClicks` on the frame where thumb and finger land together: not found (D11). The behaviour is read from the code only.
- Commits on `feature/014-gate-event-tap`: none. The branch tip equals 9557bc2 (#17), and `plans/014-gate-event-tap/` is untracked.

---

## Additional Leads (other sources, not chased)

- **Plans investigator:** `plans/002-gesture-click-blocking/` was committed in d207504 on branch 001 and is present on HEAD. It includes `.temp/architect/grounding/why.md`, `how.md`, `candidate-1.md`, `candidate-2.md`, and the probe `.temp/architect/grounding/probes/ax-tap-probe/` (main.swift and output.txt). The 24993a0 "review findings" are logged in `plans/002-gesture-click-blocking/development-logs.md`. The tap's own thread, its lifetime, and the re-enable branch were designed there. That is the likeliest place for the "own thread" and "not from the frame thread" reasons.
- **Plans investigator:** `plans/006-five-finger-tap-and-corner-swipe/` includes `.temp/architect/grounding/probes/scroll-tap-probe/` (main.swift and output.txt), `design.md`, `why.md`, and a development-logs entry added by 9044785 (Dock swipe blocking). This is where scroll and gesture events were added to "the one tap". It may say why the tap was not split or gated.
- **Plans investigator:** `plans/009-app-switch-gesture/` (e045655 and later; f7a8a4f edited its plan and logs) for the "thumb under resting fingers" blocking decision. `plans/012-window-switcher-gesture/` (fc2e216, 879d03c; development-logs plus `.temp/slices/fixes.md`) for the one-frame-late window swipe blocking.
- **Plans investigator:** the design commits 0451f0f and e045655 mention the race test names (I9). The plan text may state which races were accepted.
- **Hardware / manual:** PR #7 notes that the re-enable path and `MultitouchTrackpads.run` cannot be tested without Accessibility trust and real devices. Any gating change would need a hand check on hardware.
