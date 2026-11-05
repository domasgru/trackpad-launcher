# Development logs: Hide background apps

## Specify
- Solution's "changes what is in front" contradicted R5 and R8 → rewrote it as the actual rule; R5 now says why a tap on the app in front still hides.
- The swap cannot "list" anything → Solution says the swap reaches hidden apps.
- No scenario for lifting a swipe on a hidden app → added "Lift on a hidden app" under R20.
- R12 read as an instant-in-time check, and asserted Mail stays in front → rephrased around the user bringing another app forward; dropped the assertion.
- R9 missed silent cases → added "Lift on the window already in front" and "Thumb tap with nothing to swap to".
- R13 named Spaces with no scenario and left full screen open → added "App on another Space" and a sentence that full-screen apps follow ⌘⌥H.
- R2 and R3 named cases with no scenario → added "Fresh install" and "Login start".
- R14 and R16 held several behaviours each → split into R14–R16 and R18–R20; "as the user left it" became position and switch state.
- R17's scenario could not be set up and hinted at implementation → now R21, phrased as no new permission prompt.
- R11 named an unstated limit → states 10 seconds, or 2 seconds after finishing launching.
- R5's "missing" and R10's "no process" were vague or implementation language → "no longer installed" and "not running".
- Non-goals lacked the settings window opening → added.
- Own check after applying: R9's "only one app is running" is impossible with Finder → reworded; R14's frontmost exception had no scenario → added "Settings window in front".
- Rejected: dropping "third group" (the user's wording); dropping the launch animation off scenario (the setting exists, the overview omits it); an ordering requirement for R5/R6 (the probe showed hiding at gesture time ends with the target in front).

## Plan
- R7's same-turn hide rested on a probe that waited 0.6 s between the open and the hide, with a filtered order → re-probed same-turn with the whole ⌘-Tab order: a third visible app landed second in three series steps of four. The adapter now hides the app that was frontmost only on the kept app's activation push (the earlier probe's order held in every step that way) and the rest at once; R7 gained a probe-and-manual entry and T5 a rapid-tap clause.
- R5 with the launch animation off was untested → T3 gained the clause, plus a no-process tap that hides nothing, since `fire` must read `hasProcess` with the switch on in S2.
- R4's "only later actions" was not pinned for a launch under way → T11 gained two clauses that flip the switch with no second tap; the launch record decides, not the live setting.
- The unseen watch's time limits had no proof above `LaunchClock` → T14 now drives `LaunchWatch` directly (cap, limit, stop), lower bounds only, serialized; the `LaunchClock` host-closed clause went; S4's manual checks a menu bar app past 2 s with the animation off.
- T13 and the "shows again" clauses of T4 and T5 read back the fake's own hidden set → T13 deleted, R18 moved to a manual check, T4 and T5 reworded to the model's target, "shows again" added to S2's manual criteria.
- T4's first clause assigned Safari to a gesture, which the switcher leaves out → the clause clears the assignment; the row is Notes, Safari, Mail.
- T1 tapped with the thumb top left on a top-right record; T7 asserted no pulse where slides tick, and a `raised` literal missing the lift's empty raise → fixed with the existing rows' literals.
- Hide order was observed only in T8 → the fake gains an `onHideOtherApps` hook, asserted in T3.
- The plan read R12 generously (a user who came back gets the hide) without saying so was a deviation → stated as needing the human's ruling before S4 merges, with the activation-observer alternative and its noise.
- `.windowShown` can be a hidden Electron startup window (plan 017's D3/O4) → S4's manual covers Slack, Figma and Chrome, with the window-list confirmation as the contingency.
- No probe ordered a panel in while the app was hidden → re-probed: such panels show whatever `canHide`; the closed-window branch now unhides without activation after ordering out (probed).
- The S2/S3 boundary needed the `hasProcess` read S3 claimed → the read moved to S2 with its row.
- S2 held 18 requirements → split: S2 the other apps' hides, S3 the settings window and overlays, S4 the launches.
- R13's manual lacked an ordinary window on another desktop and the ⌘⌥H comparison's contingency → added.
- The *Settings window* entry omitted the switch → added.
- Port comments were said to keep their contracts though their texts name the bounce → rewritten in the slices that change each behaviour.
- A repeat gesture on an unseen watch after turning the animation on → stated: the watch keeps its kind; the entry says so.
- Plan 017 misquoted ("ruled out") → the suite was removed for 6 s → 92 s.
- "The AX observer fires for a hidden window" was unprobed → reworded as the watch's two ends, the observer case unmeasured.
- `WatchedLaunch.showsBounce` was never read → dropped.
- Hide cost unmeasured → probed: 0.75 ms visible, 0.25 ms hidden, `isHidden` as dear as the call; the immediate hides go out on the next main-actor turn.
- App Nap on the unseen watch was uninferred → S4's manual times the 2 s limit on an idle bundled build, with a `ProcessInfo` activity as the contingency.
- Rejected: moving R18 back into a World row (it cannot fail); a window-list check before every hide (only if an app hides early); skipping already hidden apps (the read costs as much as the call).
- R12's "came back" reading needed a decision → amended R12: the frontmost read at window time decides, so a user who came back gets the hide; no activation observer. Decided by the orchestrating session under `/do`; flagged to the human in the final report.
