# Development logs: The switcher shows running apps like ⌘-Tab

## Specify
- R1 and R2 contradicted each other on a frontmost app that ⌘-Tab does not show → R1 allows that one app at the left end; R2 gained a scenario for it.
- No scenario checked that a switch made by the switcher updates the order → added "Order follows the last switch" to R2.
- ⌘-Tab comparison scenarios changed the order they checked → they now dismiss ⌘-Tab with Esc.
- R2 had no fallback if the last-used order cannot be read → apps with unknown order go after known ones, in launch order.
- R3 bundled several rules and left-hand mode was ambiguous → split into R3 (start and direction, same in left-hand mode) and R4 (left-end hard stop, no dead zone); the "unchanged" clause moved to Non-goals.
- "Shrink evenly" was ambiguous, and long rows may exceed trackpad travel → R6 now scales icons and gaps by one factor; a non-goal covers no lift-and-reposition.
- Lift behaviour was unclear for windowless apps, apps on other Spaces, and a frontmost app that changes mid-swipe → R7 says "as clicking the Dock icon would" and "the app frontmost when the swipe began", with scenarios for each.
- R8's "frontmost cannot be read" was not testable → dropped.
- The persistence scenario did not exercise a force-quit → R10's scenario now force-quits.
- The off-setting requirement bundled blocking rules → split into R11 (no swipe) and R12 (only tap blocking rules apply); the slide scrolls after the blocking window.
- The hint requirement lacked an on-state scenario and a live update → R13 updates at once, with scenarios for both.
- The switch did not trace to the problem statement → the problem statement records the user's request for an on/off switch.
- The product overview's single silent exception and "left or right" wording → the planned overview edit generalises both.
- Rejected: an app-name non-goal (the switcher already shows the selected app's name) and the YAGNI note on start-up order (the exact order is readable without permissions).

## Plan
- Before the review, the resumed planner's own check: the Strategy counted six seams (there were seven), the two platform tests ran at the LaunchServices reader rather than the port's adapter, T5(b) was exposed to real activations on the test Mac and to the posted app already being first, and S1 was too large for one context window → seams listed by name, the platform tests moved up to the adapter, T5(b) posts for the last-read app and asserts relative order, S1 split.
- R13's live hint update was proved by nothing but a hardware step (T18 read the Bool, T22 the strings) → `Launcher.gestureHint` derives the string the window renders; T18 asserts it flips at once with the window open.
- Identity by location (two running copies as two icons) had no proof, and `identityIsTheBundleIDNotTheLocation` asserted the opposite → T23 (two Slack copies, the Downloads one frontmost) and the old row inverted.
- S1's grep for `frontmostApp` would always match `frontmostApplication` → `grep -rnF "frontmostApp("`.
- "The adapter registers no observer when the reader resolved" had no way to fail → an internal `isTrackingActivations`, false in T4, true in T5(b).
- T16 could not fail (the core never sees the layout) and the real risk, icons and highlight drifting apart, was untested → `SwitcherRowLayout.centreX(at:)` positions both; T15 pins it at scale 1 and 0.4886; T16 relabelled a regression guard.
- T10 quoted R4's "no extra travel to undo the stretch" while expecting 9 mm, 3 of which undid the band → R4 read literally: the band is forgiven on the turn at both ends, 6 mm from the turn; decision 3, T9, T10, the glossary's *Switcher* and the non-goals say so; Further Notes flags it for the owner.
- T1 cited "Order known right after start", which the World seam cannot observe → citation moved to T4 and S1's hardware step.
- T5(b)'s first half restated the fallback's own sort → demoted to a precondition; the seed and the notification-driven reorders are the assertions.
- T19's press verdicts were ambiguous on one World → the full sequence [drop, drop, pass, pass].
- T4's "read in the same instant" was not guaranteed (the workspace list is a run-loop snapshot) → the test reads the workspace set before and after and ends without asserting when they differ.
- Testing through `WorkspaceActions` would create the launch overlay's window → the running-apps read is its own platform type, `RunningAppsReader`, which `WorkspaceActions` delegates to; the tests construct it alone.
- The fallback forgot the app frontmost at start, so R2's "Order follows the last switch" failed on that path → the tracker is seeded with the frontmost regular app; T5(a) and T5(b) cover the seed; glossary and architecture updated.
- `apps` might carry a menu bar app or Trackpad Launcher after one had been in front → the membership probe (`.temp/.../membership.swift`) showed the array holds only `Foreground` apps even after an accessory app activated itself; the keyed read now asks for the application type and pid and filters both as guards; S1 gained the two hardware steps.
- R8 reverses plan 006's early end for a swipe with nothing to show, against the "end behaviour unchanged" non-goal → the non-goal names its two deliberate exceptions (R8, R4).
- Glossary said the highlight moves "exactly as far as the cursor" (false for shrunk rows) and running apps are "never stored" (the fallback stores a recency list); architecture omitted the frontmost menu bar app's swipe-time draw → all three sentences reworded.
- Strategy placed the by-eye ⌘-Tab check in the wrong slice → named S1.
- The affected-tests list missed `aSwipeOnASecondTrackpadWhileOneSwitcherIsUpIsIgnored`, the mid-row `SwitcherTests` rows that need `home`, and the row-menu assertion inside a deleted Add app… row → all listed.
- The launcher window's height cap would clip Quit with no scrolling region left → the cap goes.
- S1 bundled the port, both adapters, the list removal, icon pre-drawing and the World rewrite → the LaunchServices order (the riskiest assumption) lands in S1, the fallback is S2, icon pre-drawing is S3, shrink S4, the switch S5.
- The switch to the running app's name was never requested → recorded in the Solution as a decided change, with the cost that motivates it.
- Icon pre-drawing ran with the swipe off and the cache grew with every app ever run → passes and observers follow `isSwipeOn` (S5); icons are evicted when an app quits.
- The probe's cost claim ("under 0.5 ms") did not survive a re-run → 1.4 ms warm, under 4 ms cold for 14 apps with five keys, recorded in the decisions, the notes and the architecture.

## Implement
- The frontmost app's location came from `NSRunningApplication.bundleURL` and the ⌘-Tab apps' from `LSBundlePath`, and the presenter spelled its icon cache keys a third way. A spelling difference would show the frontmost app twice and miss the icon cache → one spelling, `AppEntry.location(ofBundleAtPath:)` in the core, used by every path. Entry building is now in one platform helper, `RunningApp`. A platform test checks that the frontmost app's location equals its entry in `apps`. The fix pass first made `LauncherUI` import `LauncherPlatform` for this, which would have been a new module dependency, so the spelling moved to the core.
- The lift check reached into `RunningApps` (feature envy) → `RunningApps.contains(_:)`.
- T5(b) passed silently with fewer than three Dock apps, but the plan says "skipped, not red" → it now uses an `.enabled(if:)` trait.
- T13 never checked "the window is as it was" → it opens the window and asserts it stays open.
- Removing `screenMargin` left a bare `8` three times in `LauncherPanel` → named `screenEdgeInset`.
- Not fixed:
  - The `@testable` reads of `isTrackingActivations` and `FallbackOrder`, and the presenter's own workspace observation. The plan prescribes both.
  - The call-count assertion in `LocateTests`, which predates this plan and was only moved.
  - T4's early return when the running apps change mid-read. The plan prescribes it.
  - The two-scenario test rows, the committed exploration notes, and the `(pid, launched)` tuple, all judged not worth changing.
- `SystemAppScannerTests` fails intermittently under machine load (FSEvents timing) and passes alone. This is unrelated to this change.

## Fix: the first swipe after opening the app did nothing
- Reported by the owner: after a rebuild the swipe did nothing until a tap gesture had fired. Reproduced by watching the active app across Xcode's Run: Trackpad Launcher stayed the active app afterwards. The switcher skipped itself as frontmost, so no row was built. A tap brought another app forward, which hid the problem. Opening the app from Finder does the same.
- → R14: with no readable frontmost app the row is the running apps alone, starting on the most recent, and lifting on any app brings it forward. `Switcher` takes an optional frontmost app; three World tests, and the nothing-to-show test's no-active-app case now runs with no running apps.
