# Why: source control evidence (window swipe, window switcher, frontmost window read)

### Source
Source control only: git history (main, origin/feature/* branches incl. pre-squash branch commits, backup/025-full-blocking), commit messages and diffs, `gh pr view` for PRs #11, #15, #16, #17, #19, #33, #41, code comments, tests, and the checked-in docs (`docs/architecture.md`, `docs/domain-model.md`, `docs/product-overview.md`, `docs/performance.md`). I did not read anything under `plans/` (including the `.temp/` files committed inside plan directories). Those are listed under Additional Leads.

### What I Searched
- `git log --oneline` (full main history); `git log --follow` on `FrontmostAppWindows.swift`, `SwitcherRowLayout.swift`, `WindowColumnLayout.swift`, `Switcher.swift`; `git log` on WindowSwitcher/WindowLift/WindowSwipeConfirmation/WindowColumnLayout/Switcher/SwitcherRowLayout/Ports/Launcher.swift.
- Pre-squash branch history: `git log origin/feature/012-window-switcher-gesture ^6054488` (12 commits), `origin/feature/008-recent-apps-switcher`, `origin/feature/025-recent-switcher-fixes`, `backup/025-full-blocking`.
- `git show` on: 18acef7, c5f9ffd, a09ddfa, ffa025d, 92914eb, b3af55c, 8c3f56f, fc2e216, a88b1c3, 50c9c9f, 7bcb68d, 9557bc2, a068ed5, b67a5ca, 6405d49, 97abf50, 8de1e32, 4428446, 8acaea8, 6e70227, 5b36103, d9cf962.
- `gh pr view` 11, 15 (incl. comments/reviews), 16, 17, 19, 33, 41.
- `git blame -L 14,20` and `-L 371,407` on `Launcher.swift`.
- Pickaxe: `-S 'the window reads have two readers'`, `-S 'AXUIElementSetAttributeValue'`, `-S 'no further raises until it is read again'`, `-S "The switcher's icons are drawn before any swipe"`, `-S 'which only the main actor can tell'`, `-S 'Every slide up or down reads'`, `-S 'messaging timeout'` (on the 012 branch), `-S 'the model keeps none of it'`, `-S 'The list is fixed when the window swipe begins'`, `-S 'The row is fixed when the swipe begins'`, `-S 'one source of truth'`, `-S 'windowSwitcherMaxRows'`; `--all -G 'func frontmostWindows'`; `--all -G 'frontmostWindows\(\) async|async.*frontmostWindows|windowCounts|windowCount'`.
- `git log --all -i --grep` for deadlock / main actor / main thread / off main / off-main / concurren / messaging timeout / timed out / hang.
- Tests read: `SourcePolicyTests.swift` (confined list), `WindowSwipeNeedsTwoWindowsTests.swift` (whole), parts of `WindowSwitchingTests.swift`, `WindowSwipeAnswerTests.swift`, `WindowSwipeConfirmationTests.swift` names, platform `FrontmostAppWindowsTests.swift` and `DeviceSessionAnswerTests.swift` names.
- Unmerged branches touching window files: `git log --all --not main -- <window files>` (only pre-squash commits of already-merged work found).

---

### Direct Evidence Found

#### Q1: synchronous main-actor read, 0.2 s timeout, no raises after a timeout, one-file confinement

1. **Architecture doc, Concurrency (current text, introduced in the #15 plan commit c5f9ffd, widened by the squash 18acef7):**
   > "Every slide up or down reads the frontmost app's windows when it starts, and a window swipe raises them, through the Accessibility API on the main actor: synchronous calls into another app, about a millisecond each, each bounded by a short messaging timeout, after which that app gets no further raises until it is read again; the window list's first call in the process (about 50 ms) is paid off the main actor at launch."
   - `docs/architecture.md` line 19. Pickaxe: `-S 'no further raises until it is read again'` → 18acef7 (2026-10-16). On the branch, the first version (c5f9ffd, "Plan: swipe up or down to switch windows") read "A window swipe reads the frontmost app's windows and raises them through the Accessibility API on the main actor: …". It became "Every slide up or down reads…" once the 2+ rule landed.
   - Relevance: this states the design (synchronous, main actor, bounded, cut off after a timeout). It gives costs ("about a millisecond each") but no rejected alternative.

2. **The port contract (Ports.swift 124-138, from a09ddfa and ffa025d, both 2026-10-16):**
   > "The frontmost app's windows, read now, beside `runningApps()`: about a millisecond, at most one messaging timeout (0.2 s) when the app does not answer. Reads only. The windows it lists are the only ones a later `raiseWindows` may name, until the next read."
   > "… A window that has closed is skipped; an id the latest read did not list is skipped, so nothing on another Space is ever raised. About 2 ms per raise; once the app has timed out, no further calls go to it for that read. [] does nothing."
   - `LauncherKit/Sources/LauncherCore/Ports.swift`. The first sentence comes from a09ddfa ("Sliding up or down shows the frontmost app's windows"). The raise-scoping sentences come from ffa025d ("Sliding brings each window forward and lifting keeps it").
   - Relevance: the stated reason for "only ids from the latest read are raisable" is **"so nothing on another Space is ever raised"**.

3. **FrontmostAppWindows.swift inline comments (ffa025d, 2026-10-16):**
   > `/// The windows the latest read listed: the only ones a raise may touch, so nothing on another Space is raised.`
   > `private var listed: [WindowID: AXUIElement] = [:]`
   > `/// The app timed out during the latest read or a raise since: no further calls go to it until the next read.`
   > `private var isUnanswering = false`
   > `// The app stopped answering: what was read so far stands, and nothing is raised.`
   - `LauncherKit/Sources/LauncherPlatform/FrontmostAppWindows.swift` lines 20-23, 67.
   - Relevance: this is where the "no further raises after timeout" guard and the latest-read-only scope live. Both were added in the same commit as the raise, and the raise comes with a stated reason (Spaces). The no-calls-after-timeout rule has no reason beyond the rule itself. The timeout constant's comment is the closest thing:
   > `/// Bounds every call into another app: one that does not answer in time reads as having no windows.` `static let messagingTimeout: Float = 0.2` (line 14-15, from a09ddfa).

4. **Process-wide timeout set once (FrontmostAppWindows.init, a09ddfa):**
   > "Sets the messaging timeout once on the system-wide element, which makes it the process's default (set on any other element it covers that element only); resolves the private window number; and pays the window list's first-call cost (about 50 ms) off the main actor now rather than at the first window swipe."
   - Relevance: the 0.2 s is the **process-wide default** for every AX element. `LaunchWatch.swift` sets its own per-element timeout ("Every Accessibility call goes to the app element it creates, whose messaging timeout it sets to `messagingTimeout` itself", `LaunchWatch.swift` line 14-15, `static let messagingTimeout: Float = 0.2`). The only off-main work in this file is the 50 ms window-list warm-up. Any new concurrent per-app reads would inherit this process default.

5. **"Review fixes: concurrent off-main work…" (92914eb, 2026-10-16 18:05, branch feature/012):** the title sounds like a decision about off-main window reads. The diff shows it is not. It replaced `DispatchQueue.global(qos: .utility).async { CGWindowListCopyWindowInfo… }` with `Task { await Self.warmWindowList() }` plus `@concurrent private static func warmWindowList() async`, and made the private-number fallback per window (`if raw.contains(where: { $0.number == nil })` instead of `if getWindow == nil`). The read itself stayed synchronous on the main actor.
   - Relevance: this is the only commit whose message mentions "concurrent"/"off-main" for this file. It does **not** consider or reject moving the window read off the main actor.

6. **Source-scan confinement (SourcePolicyTests.swift):**
   - a09ddfa (2026-10-16) added:
     > `Confined(token: "AXUIElement", onlyIn: "FrontmostAppWindows.swift", rule: "the window read has one reader"),`
     > `Confined(token: "CGWindowList", onlyIn: "FrontmostAppWindows.swift", rule: "the window read has one reader"),`
   - a068ed5 (#21, 2026-10-19, launch bounce) widened both to two files:
     > `Confined(token: "AXUIElement", onlyIn: ["FrontmostAppWindows.swift", "LaunchWatch.swift"], rule: "the window reads have two readers"),` (same for `CGWindowList`). Branch commit message in the #21 squash: "Share flight staging, confine tokens to sets of files, add launch probes … the source scan confines a token to several files".
   - The banned list (from 18acef7) also has: `Entry(token: "AXUIElementSetAttributeValue", rule: "the window switcher only raises a window")`, `Entry(token: "kAXPressAction", rule: "the window switcher only raises a window")`.
   - The suite's own doc comment: "Each permission API lives in exactly one file, the adapter that owns it. Any other hit fails." (`SourcePolicyTests.swift`, `Confined` struct). The architecture doc: "the Accessibility element API with the window list to two (the frontmost app's window read and the launch watch)" (`docs/architecture.md` line 25).
   - Relevance: the confinement exists to keep each permission API in one owning adapter. **The current code confines it to two files, not one**: the question's premise ("confined to one file") is out of date since #21.

7. **Only the frontmost app is read.** No commit, PR or comment found that explains choosing only the frontmost app over several apps. What exists:
   - PR #15 body: "…shows a Liquid Glass window switcher in the top-left corner listing the frontmost app's windows (60 pt preview + title)." This is a requirement-level statement, not a rationale.
   - Architecture permissions sentence (line 25): Accessibility is used "to list the frontmost app's windows when two fingers start sliding up or down under the thumb, to raise and restore them during a window swipe…". This is the **enumerated permission-use promise**. Reading the windows of up to 10 apps would fall outside its current wording.
   - See Gaps.

#### Q2: window swipe only with 2+ windows; the answer hopping back to the frame thread

8. **PR #15, original body (2026-10-16):** "Each window comes to the front as the selection passes it; lifting keeps it. **One window or none still shows the switcher.**"
   **Owner comment on PR #15 (domasgru, 2026-10-16T17:02:07Z):**
   > "Change 1: the window swipe now exists only when the frontmost app has two or more windows. With one window, no windows, a full-screen front window, no frontmost app, or no Accessibility, a vertical slide shows nothing and behaves exactly as with the window swipe switch off. The model confirms each vertical slide from a fresh window read before it becomes a window swipe. 486 tests pass."
   - Relevance (direct, and the strongest collision with the new design): the 0-or-1-window switcher **was built, shipped on the branch, and then deliberately reversed inside the same PR**. The comment says what changed. It does not say why. The "why" is presumably in the plan commit b3af55c "Plan: window swipe only for apps with two or more windows" (plans/ territory, see Leads).

9. **What the reversal removed (a88b1c3, 2026-10-16 19:52, "A slide up or down is a window swipe only with two or more windows"):**
   > "The model confirms a window swipe's start only when gestures are active and the frontmost app's windows make two or more rows; otherwise the slide behaves exactly as with the window swipe setting off. Without Accessibility the recognizers run without the window swipe. The message rows go, untitled windows are always numbered, and the Accessibility hint names switching windows."
   - Diff: removed `Copy.noOpenWindows = "No open windows"` ("The window switcher's single row when the frontmost app has no windows, or there is no frontmost app") and `Copy.accessibilityForWindows = "Allow Accessibility to switch windows"`; removed `WindowSwitcher.Content.noWindows(of:)`, `.accessibilityNeeded(for:)`, `Row.message(String)`, `listsWindows`; removed a full-screen front window as a single row (`if front.isFullScreen { self = .windows(of: app, .front(front, others: [], minimised: [])) }` → `guard !front.isFullScreen else { return nil }`); `Content.init` became failable with `guard count >= 2 else { return nil }`; `Launcher.reconcile` started dropping `.windowSwipe` from `slides` when Accessibility is not granted.
   - The removed product-overview silence clause: "…lifts a window swipe on the window that was in front, **on a "No open windows" or Accessibility message**, or on a window that closed…".
   - Relevance: the earlier "card for 0/1 windows" shape (a single message row) existed and was taken out. A new 0/1-window card would bring back something close to it.

10. **The 2+ rule stated in the model (Launcher.swift 375-377, blame 18acef7):**
    > "// A slide up or down is a window swipe only when the one read lists two or more rows. Unconfirmed, the recognizer makes it the slide the setting off would have made, before its next frame."
    And `WindowSwitcher.Content.init?` doc: "The one parse from what the system read to what the switcher lists, and so whether a slide up or down is a window swipe at all: … nil for `.noApp`, and for fewer than two rows after these rules: one window, an only window minimised, no windows, a full-screen front window, or an app that did not answer (its read lists nothing)."
    - Note: **an app that times out counts as "no window swipe"**, so the slide scrolls. The timeout result is part of the 2+ decision.

11. **Why the answer hops back (architecture.md line 18, added in plan commit 8c3f56f "Plan: model confirms each window swipe; slices S5 and S6"):**
    > "One thing hops back: the model's answer to a window swipe's start, whether the slide is a window swipe, which only the main actor can tell because it reads the frontmost app's windows. The model gives it while it handles the start; the adapter replies once that call returns, and the frame thread hands the reply to that trackpad's recognizer before its next frame. The recognizer ignores an answer to any other start. Until the answer arrives the slide blocks clicks and scrolling only by the thumb rules, and Dock swipes as any thumb touch does, and the frame thread never waits for it."
    - Relevance: the hop-back exists **because** the 2+ decision needs the window read, and the window read is main-actor only. Order on the branch: a09ddfa (no confirmation, every vertical slide is a window swipe) → fc2e216 (prefactor: confirmation plumbing, "the model confirms every start for now") → a88b1c3 (confirm only with 2+ rows).

12. **fc2e216 (2026-10-16 19:46) "Prefactor: a window swipe's start waits for the model's answer":**
    > "The recognizer begins a slide up or down unconfirmed, blocking only by the thumb rules, until answerWindowSwipe settles it: confirmed, it blocks from the next frame; declined, it becomes the setting-off slide. Both adapters answer each start through WindowSwipeConfirmation once onEvent returns; the model confirms every start for now."
    - `GestureRecognizer.answerWindowSwipe` doc (same commit): "…false turns the slide into what the window swipe setting off makes of it … Changes nothing unless an unconfirmed slide that began at `began` is in progress: an earlier start's answer, an answer after the slide ended and a second answer are ignored. (Exactly the setting-off state when it arrives before the next frame; a thumb that lifted and landed again before a late false is taken as the slide's thumb.)"
    - `FrameStream.swift` (same commit): "Writer: the main actor, through a reply. Reader: this device's frame callback, which hands it to the recognizer before each step. Never cleared: the recognizer ignores an answer it has already taken or that names another start."
    - `WindowSwipeConfirmation` doc: "The main-actor half of the answer to a window swipe's start, one rule both hardware adapters share … a start comes back with its answer for the adapter to send to that trackpad's recognizer." `confirm(on:)`: "Counts only while `deliver` hands over a start from `trackpad`; any other call does nothing, and nothing carries over to the next start."
    - Relevance: the confirmation is **synchronous within the `onEvent` call**. `deliver` returns whether `confirm` was called *while the handler ran*. An asynchronous answer (one that comes after an awaited multi-app read) cannot confirm through this mechanism as written. The recognizer does tolerate late answers (see tests in 13).

13. **Tests that encode Q2 (they would fail or need rewriting under the new design):**
    - `WindowSwipeNeedsTwoWindowsTests.aSlideDownIsAWindowSwipeOnlyWhenTheReadListsTwoOrMoreRows`: listing cases `(visible:1, minimised:0) → nil`, `(0,1) → nil`, `(0,0) → nil`, full-screen front → nil, `answers: false` → nil, `14 visible → 10 rows`. Each asserts `world.system.windows.reads == 1`.
    - `withFewerThanTwoWindowsASlideDownBehavesExactlyAsWithTheWindowSwipeOff` (fronts: `textEditOneWindow, finderNoWindows, noActiveApp, safariFullScreen`): asserts outcomes equal to the setting-off reference world, no switcher, `windowSwipeAnswers == [false]`, and that a fresh slide-press-lift is dropped/passed like the setting-off case.
    - `aWindowThatOpensMidSlideDoesNotMakeItAWindowSwipeButCountsForTheNextSlide`.
    - `withoutAccessibilityASlideDownIsNoWindowSwipeAndAGrantBringsItBackWithTheNextSlide` (`reads == 0`, `windowSwipeAnswers.isEmpty`).
    - `WindowSwipeAnswerTests`: `aDeclinedStartIsExactlyTheSlideOfTheSettingOff`, `aConfirmedStartBlocksFromTheNextFrameUntilBothFingersLift`, `anUnconfirmedStartBlocksAsTheSettingOffAndStillEnds` (`neverAnswered, answerNamesAnEarlierStart, answeredAfterTheLift`), `aLateDeclineBlocksAsTheSettingOffThroughoutAndMatchesItFromTheAnswerOn`.
    - Platform `DeviceSessionAnswerTests`: `aStartConfirmedAtOnceBlocksClicksFromTheNextFrameUntilTheLift`, `aStartDeclinedAtOnceNeverBlocksClicks`, `aStartNeverAnsweredNeverBlocksClicks`, `aConfirmationOfTheFirstStartArrivingAfterTheSecondStartNeverBlocksClicks`.

14. **Domain model "Window swipe" (docs/domain-model.md line 93, current):**
    > "It exists only when there is something to switch to: the frontmost app has at least two windows, counted as the window switcher would list them, when the slide's direction is decided, and Trackpad Launcher has the Accessibility permission, without which no window can be read. Otherwise the slide is no window swipe: nothing shows, nothing pulses, and it behaves exactly as with the window swipe setting off, scrolling once the blocking window has passed and never becoming a swipe; a window that opens later in the slide does not make it one."
    - "only when there is something to switch to" is the one rationale phrase in source control for the 2+ rule.

#### Q3: ordering (front, visible front-to-back, minimised), cap 10, lift reorder

15. **List order, from a09ddfa onward (WindowSwitcher.swift):** `case front(AppWindow, others: [AppWindow], minimised: [AppWindow])`, "The front window, the other visible windows front to back, then the minimised ones in the app's order." The platform sort (`FrontmostAppWindows.sort`) says: "Visible: role AXWindow, subrole AXStandardWindow, not minimised, on screen now (so on this Space), in the window list's order. Minimised: by the minimised flag alone, because a minimised window reports the AXDialog subrole, in the app's order."
    - Platform tests encode it: `visibleWindowsFollowTheWindowListAndAMinimisedOneComesAfterThemDespiteItsDialogSubrole`, `theWindowListDecidesTheVisibleOrderWhateverTheElementOrder`, `aStandardWindowNeitherOnScreenNorMinimisedIsOnAnotherSpaceAndLeftOut`, `minimisedWindowsKeepTheAppsOrder`.
    - Relevance: the visible order comes from the **window server's live z-order** (`CGWindowListCopyWindowInfo` with `.optionOnScreenOnly`). It is not model state. Minimised windows have no z-order, so the app's AX order is used.

16. **Cap 10:** `GestureRules.windowSwitcherMaxRows = 10`, doc "The most rows a window switcher holds: the front window, the other visible ones, then the minimised ones." (18acef7). It mirrors `switcherMaxApps = 10`, which 8de1e32 (2026-10-13, "Limit the switcher to 10 apps") introduced with the message "The row holds the frontmost app and the 9 most recently used others." No rationale for the number 10 was found in commit messages.

17. **Lift reorder (ffa025d "Sliding brings each window forward and lifting keeps it", 2026-10-16; WindowLift.swift):**
    > "Otherwise the target is the selected window, then the visible windows in their begin order (the front window first) without it, minus any that closed; the haptic plays iff the selected window is not `frontWindow` … Lifting on the front window therefore restores the begin order, silently."
    - `WindowStack.raises` doc: "The shortest front part of `target` … that, raised back to front, leaves the target windows on screen in `target` order among themselves … A window not in `target` keeps its place among the windows not raised, so one opened mid-swipe in front ends just behind the raised ones. Empty when the order already holds."
    - Product overview (18acef7): "lifting keeps the selected window in front (restoring it if it is minimised) with the window that was in front just behind it". Domain model: "Lifting … orders the windows: the selected window, then the front window, then the others as before".
    - Test: `WindowSwitchingTests.liftingOnAnotherWindowKeepsItInFrontWithTheFrontWindowNextAndTheNextWindowSwipeStartsThere`. After lifting on "News" from [Docs, Mail, News], the stack is `["News", "Docs", "Mail"]`, and **the next window swipe's rows are `["News", "Docs", "Mail"]`, selection 0**. Inference (not stated): putting the old front window second makes the next swipe's second row the previous window, a ⌘-`-like toggle. Because the order is re-read from the window server, this works without model memory.
    - Why the raises while sliding are undone by the lift: Launcher.swift 392 "// Only a visible window comes forward while sliding: raising a minimised one would restore it." and 397 "// The second read: the lift follows the windows as they are now, whatever the raises while sliding did." Test `slidingAwayAndBackThenLiftingRestoresTheOrderSilently`, `liftingOrdersTheWindowsEvenWhenRaisesWhileSlidingWereIgnored`.
    - 50c9c9f (2026-10-16 22:15) "Keep a window minimised mid-swipe minimised when the lift is on another row": changed `WindowStack.raises` so target windows not on screen (other than the first) are dropped. Test `aWindowMinimisedMidSwipeStaysMinimisedWhenTheLiftIsOnAnotherRow`.

#### Q4: no window state across swipes; list and row fixed at begin

18. **Fixed at begin:** WindowSwitcher.swift doc (a09ddfa): "Its content is fixed when the window swipe begins: a window that opens later is not added, and one that closes stays listed. The selection follows the travel." Domain model (18acef7): "The list is fixed when the window swipe begins: a window that opens during it is not added, and one that closes stays listed; lifting on a closed window leaves the windows as they are." The phrasing copies the app switcher's rule from #11 (b67a5ca, 2026-10-13): "The row is fixed when the swipe begins: an app that launches during the swipe is not in it, and one that quits stays in it."
    - Test: `selectingAWindowThatClosedChangesNothingOnScreenAndItStaysListed`; `whenTheSelectedWindowCannotBeReachedTheLiftChangesNothingAndIsSilent` (args: "the app stops answering", "Notes becomes the frontmost app", "every listed window closes").

19. **No state across swipes, precedent from #11 (b67a5ca):** the domain model for Running apps: "Read from LaunchServices at the moment a swipe begins and again when it ends; **the model keeps none of it**." The port doc from the same PR: "The active app and the ⌘-Tab apps, read now from their one source of truth." (Ports.swift 127). Later (#12/#33 era) the clause became "the model keeps none of it beyond the last swap of the latest swap series, which is replaced when the next series starts."
    - For windows, the equivalent statements are on the port ("The windows it lists are the only ones a later `raiseWindows` may name, until the next read") and in the adapter (`listed` is reset at the start of every `read()`: `listed = [:]; isUnanswering = false`).
    - Tests count reads exactly: `reads == 1` per slide (WindowSwipeNeedsTwoWindowsTests), `reads == 2` for begin + lift (WindowSwitchingTests ~line 205).
    - Relevance: "read now from the one source of truth, keep nothing" is a pattern stated for running apps since #11. For windows it is implemented and tested but not justified in prose. A per-app window order kept for as long as the app runs would be the first piece of model-held order state in these switchers.

#### Q5: switcher icons drawn before any swipe; running apps read from LaunchServices at begin; layout types in LauncherCore

20. **Icons before swipe (b67a5ca #11, branch commit 6405d49 "Switcher icons are drawn before the first swipe", 2026-10-13, touched `AppIcons.swift`, `SwitcherPresenter.swift`):** architecture.md line 19, unchanged since #11:
    > "Work that would delay a click (folder scans, Spotlight reads, icon drawing) runs off the main actor in explicitly concurrent functions … The switcher's icons are drawn before any swipe: every running Dock app's in the first icon pass at start, and each newly launched app's off the main actor on the workspace's launch notification, again on an appearance change; a swipe begins by reading the running apps from LaunchServices, a few milliseconds at most, and draws an icon on the main actor only for an app whose pass has not finished yet or that no pass covers…"
    - Relevance: the stated forcing function is "Work that would delay a click … runs off the main actor". Plus `docs/product-overview.md` "Additional notes": "Trackpad launcher should be as performant as possible, consuming the least possible resources as it's technically possible."

21. **Layout types in LauncherCore:** `SwitcherRowLayout` was created in LauncherCore by 97abf50 ("Long switcher rows shrink to fit the display", 2026-10-13, branch 008) along with `LauncherCoreTests/SwitcherRowLayoutTests.swift` and edits to `SwitcherOnScreenTests.swift`. `WindowColumnLayout` was created in LauncherCore by a09ddfa with `WindowColumnLayoutTests.swift`. Both doc comments end with a design claim: "The panel positions icons and highlight through `centreX(at:)` and `centreY` alone, so they cannot drift apart." / "The panel positions rows and highlight through `rowTop(at:)` alone, so they cannot drift apart."
    - Architecture line 11-12: "Platform adapters sense and act behind small ports; the AppKit/SwiftUI shell renders the models' state and forwards user intents. Policy lives in pure functions and value types; the shell stays thin." `LauncherCore` = "domain types, pure policy, ports, the models; imports Foundation and Observation only".
    - No commit message or PR gives an explicit reason for putting the layouts in Core. See Gaps.

---

### Indirect / Circumstantial Evidence

- **Stale doc comment that still describes the pre-reversal design.** `Launcher.swift` line 17: `/// Non-nil for the whole of a window swipe: it always shows.` It was written in a09ddfa, when every vertical slide showed a switcher. Blame credits it to 18acef7, and it survived a88b1c3. Inference: it is consistent with the code (the switcher exists for the whole of a *confirmed* window swipe), but "it always shows" originally meant "even with 0/1 windows". A reader could mistake it for current policy.

- **Self-pid special case (7bcb68d, #33, 2026-11-04).** Before: `running.processIdentifier != ProcessInfo.processInfo.processIdentifier` → `.noApp`. After: `if running.processIdentifier == ProcessInfo.processInfo.processIdentifier { return .app(entry, visible: [], minimised: []) }`. Doc: "or when it is Trackpad Launcher, whose one window is never listed." PR #33: "a slide up or down over it is no window swipe." Domain model: "A slide up or down over it is no window swipe, since the settings window is its only window." No commit says why the app never sends AX calls to its own process from the main actor. One plausible reading, *not stated*, is that a synchronous AX call to one's own process from the main thread cannot be answered. The stated reason is only "its one window".

- **Perf measurement (docs/performance.md line 51):** "Window switcher swipes with previews, about 6 in 30 s | 744 ms (2.5%) | 0.58 ms". This measured cost is for the current single-app read. Nothing measures a multi-app read.

- **Off by default (4428446, 2026-11-04) "Switch windows is off by default":** "A fresh install, and an upgrade from a version without the setting, start with the window swipe off; a saved choice is kept. The screen recording hint follows it…" No reason is given. PR #15 had it on by default.

- **Abandoned 025 work (backup/025-full-blocking, not merged):** 6e70227 "The pointer stays where it stood from a swipe's start, **a window swipe's decision** or a swap series' first swap until the fingers lift"; 5b36103 "No system swipe runs under an undecided slide or while switching…"; d9cf962 "Scrolling a switcher could take over waits for the slide's direction, and nothing scrolls while switching". PR #33 body: "The input-blocking work this PR first carried was dropped from scope." Inference: blocking during the undecided window (between start and answer) was looked at and dropped. Relevant if the new design makes the answer later (async) or removes it.

- **Hide background apps (#41, 4e8ce3e):** the lift now also calls `hideOtherApps(than: open.app.bundleID)` when `lift.playsHaptic` (Launcher.swift 403). The PR says "window swipe lifts hide everything else". This adds an effect tied to "changing" lifts.

---

### Contradictions

1. **PR #15 body vs. PR #15 final state.** Body: "One window or none still shows the switcher." Owner comment (Change 1) and merged code: no switcher and no window swipe below two rows. The PR body was never edited. The squash commit 18acef7 carries both plan commits ("Plan: swipe up or down to switch windows" and "Plan: window swipe only for apps with two or more windows").

2. **"Confined to one file" (question premise, and a09ddfa rule "the window read has one reader") vs. current SourcePolicyTests** ("the window reads have two readers": `FrontmostAppWindows.swift`, `LaunchWatch.swift`, since a068ed5 #21).

3. **`Launcher.swift:17` "it always shows"** vs. domain model/code "It exists only when there is something to switch to" (see Indirect).

4. **"Review fixes: concurrent off-main work" (92914eb) title vs. its diff.** The title suggests the window read moved off main. The diff only changes the 50 ms warm-up from GCD to `@concurrent`.

---

### Gaps

- Searched commit messages (`--all -i --grep` deadlock / main actor / main thread / off main / off-main / concurren / messaging timeout / timed out / hang) and PR bodies/comments for #15, #16, #17, #19, #33. **I found no source-control statement that a concurrent or off-main window read was considered and rejected.** The only "concurrent off-main" commit (92914eb) concerns the warm-up call.
- `git log --all -G 'frontmostWindows\(\) async|async.*frontmostWindows|windowCounts|windowCount' -- LauncherKit`: no hits. `frontmostWindows` was never async in any branch.
- I found no commit, PR or code comment that explains **why only the frontmost app** is read (as opposed to several apps).
- I found no commit or PR that states **why** the 2+ rule replaced the 0/1-window switcher. The PR comment and a88b1c3 describe what changed only. The plan commit b3af55c ("Plan: window swipe only for apps with two or more windows") has a message with no body. Its content is in `plans/012-window-switcher-gesture/` (not read by me).
- No reason found for the cap of 10 beyond mirroring `switcherMaxApps` (8de1e32 message: "The row holds the frontmost app and the 9 most recently used others.").
- No reason found in commits/PRs for putting `SwitcherRowLayout`/`WindowColumnLayout` in LauncherCore. The only related statements are the architecture's "Policy lives in pure functions and value types; the shell stays thin" and the fact that both were created together with LauncherCoreTests suites.
- No incident/revert commits found for the window read, the timeout or the raise guard. `git log` shows no "revert", "fix for", "hang" or "timeout" commit touching `FrontmostAppWindows.swift`. Only two commits touched it on main (18acef7, 7bcb68d). The defensive pieces (timeout, `isUnanswering`, latest-read scope, closed-window skip) all arrive in the original feature branch (a09ddfa, ffa025d), not after an incident.
- PR #15 has no review comments (`reviews: []`). PRs #16, #17, #19, #33 have no comments. PR #17 body is "-".

---

### Additional Leads (for the Plans investigator)

- `plans/012-window-switcher-gesture/plan.md` and `development-logs.md`, especially the material added by branch commits **b3af55c** "Plan: window swipe only for apps with two or more windows" and **8c3f56f** "Plan: model confirms each window swipe; slices S5 and S6". These should hold the reason for the 2+ reversal and for the confirmation hop.
- Committed explorations inside plan 012 (from c5f9ffd): `.temp/architect/candidate-1.md`, `candidate-2.md`, `candidate-3.md`, `synthesis-draft.md`, `rubric.md`, `grounding/probes/probe-2-ax-windows.*` (AX timing), `probe-5-spaces.*` (Spaces; ties to "nothing on another Space is raised"), `checks/check-1-preflight-cost.*` (the "about 4 ms" Screen Recording preflight cited at Launcher.swift 382), `checks/check-2-lift-rules.*` (lift ordering). Candidates may contain rejected alternatives such as off-main reads or multi-app reads.
- `plans/012-window-switcher-gesture/.temp/slices/fixes.md` (added by 92914eb "Review fixes: concurrent off-main work…"), plus slices S3-S6 (S6 added with a88b1c3).
- `plans/008-recent-apps-switcher/plan.md` (origin of "keeps none of it", "row fixed when swipe begins", icons drawn before any swipe, `SwitcherRowLayout`, the cap of 10 via 8de1e32's plan edit).
- `plans/013-simplify-switchers/` (#16, the 360 pt window switcher width, `WindowColumnLayout` changes).
- `plans/017-launch-wait-bounce/` (#21, where AX/CGWindowList confinement widened to `LaunchWatch.swift`, and LaunchWatch's own 0.2 s per-element timeout).
- `plans/025-recent-switcher-fixes/` and the abandoned branch `backup/025-full-blocking` (plan commit e58626e "Plan 025: the switchers do nothing but switch", with `.temp/architect/grounding/why-*.md`). That plan apparently treated a "window swipe's decision" moment and blocking under an undecided slide, then dropped it from scope (PR #33).
