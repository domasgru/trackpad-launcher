# Fixes after review and by-hand checks

All paths are relative to the worktree root. Sources are in `LauncherKit/Sources/LauncherUI/`, tests in `LauncherKit/Tests/LauncherUITests/`.

Do not launch the app, and do not run `open`, `make run`, `tccutil`, `defaults`, `pkill` or anything touching /Applications. Building is fine. Do not edit `docs/` or `plan.md`. Do not commit: the orchestrator commits. Skills: `macos-dev-workflow:axiom-swiftui`, `macos-dev-workflow:swift-testing-pro`.

## F1. The two hint messages are 1 pt too tall

- **Where:** `AccessibilityHintCard.swift:15-18`, `SwitcherSection.swift:40-42`, `noticeText()` in `SettingsView.swift`.
- **Rule:** plan: "the implementation uses the notice text style … and checks the card's 76 pt and the row's 110 pt against the frame"; the frame's text is size 11, line height 14. The plan's line 3: "The frame is the visual target for everything these requirements change."
- **Measured on the real window:** two lines at `lineSpacing(1)` are 29 pt, so the card is 77 pt and the row 111 pt. The frame has 28, 76 and 110. SF at 11 pt already lays out at 14 pt a line.
- **Fix:** the two hints' messages drop the 1 pt line spacing. Add one shared `View` extension for a hint message, `hintMessage(maxWidth:)`: `.font(.system(size: 11))`, `.frame(maxWidth: maxWidth, alignment: .leading)`, `.fixedSize(horizontal: false, vertical: true)`. Both hints use it, with named widths 216 and 219. The no trackpad notice is a non-goal and must keep its look: `SettingsNotice` keeps `.font(.system(size: 11))` and `.lineSpacing(1)`. If `noticeText()` then has one caller, inline it there.

## F2. The screen recording button lost its medium label

- **Where:** `SwitcherSection.swift:43`.
- **Rule:** the frame's button label is SF Pro Medium, 13 pt (`.temp/figma-notes.md`). It used to inherit `SettingsView.labelFont` from the notice block and lost it when the hint moved. This is a regression of this branch.
- **Fix:** apply the same 13 pt medium label to this button (widen `labelFont`'s access rather than repeating the font). `.buttonStyle(.bordered)` and the radius stay.

## F3. `expectTurning` reports failures in the helper

- **Where:** `GearViewTests.swift:53`.
- **Rule:** swift-testing-pro `writing-better-tests.md`, "Writing good verification methods"; `PickerBench.swift:124` is the repo's example.
- **Fix:** add `sourceLocation: SourceLocation = #_sourceLocation` and pass it to each `#require` and `#expect`.

## F4. A tautology, and two behaviours in one test

- **Where:** `GearViewTests.swift:59`, `:74`.
- **Rule:** tdd `SKILL.md`, "Tautological"; `writing-better-tests.md`, one behaviour per test.
- **Fix:** delete `turn.duration == GearView.period` (the next line pins 30). Move the `hitTest` assertion into its own test.

## F5. The bench belongs in its own file

- **Where:** `GearViewTests.swift`, `GearBench`, and its `reduceMotion` var (lines 8, 33), which is written but never read.
- **Rule:** `writing-better-tests.md`, fixtures in a dedicated file; the repo keeps `PickerBench.swift` separate. Baseline smell: speculative generality.
- **Fix:** move `GearBench` to `GearBench.swift`. Remove the unread var, keeping whatever the reader closure really uses.

## F6. Dead code in `GearView`

- **Where:** `GearView.swift:80` (`guard window != nil`, unreachable because observing stops on leaving the window) and `:95` (`isRemovedOnCompletion = false`, not in the plan, and it does nothing to an animation that never completes).
- **Rule:** baseline smell: speculative generality; the plan's list of the animation's parameters.
- **Fix:** delete both. `aGearOutsideAWindowIgnoresReduceMotionChanges` stays.

## F7. The child re-reads what the parent already unwrapped

- **Where:** `SwitcherSection.swift:18,47`.
- **Rule:** baseline smell, data clumps: the parent tests `!= nil`, and the child needs `case nil: break`.
- **Fix:** `if let hint = launcher.screenRecordingHint { ScreenRecordingHintView(hint: hint, launcher: launcher, actions: actions)… }`, and the button switches on `hint` with two cases.

## F8. `91` restates `GearView.side`

- **Where:** `AccessibilityHintCard.swift:27`.
- **Rule:** baseline smell: duplicated code.
- **Fix:** use `GearView.side`. Keep `.allowsHitTesting(false)`: the plan asks for no hit tests on either side of the bridge.

## F9. One concept with three names in `TintedButtonStyle`

- **Where:** `SettingsView.swift:284,309,318`.
- **Rule:** baseline smells: mysterious name, repeated switches. `face`, `FaceKind`, `kind` and the private struct `Face` name one thing or collide.
- **Fix:** rename so one concept has one name (for instance the enum `Fill` with cases `.wash` and `.solid`, parameter `fill`, leaving `Face` as the private view), and resolve the two decisions on it in one place. Update `AccessibilityHintCard`. The look of both faces does not change.

## F10. Stale comments

- **Where:** `SettingsView.swift:12` ("every row of the form is 46 pt tall", false while the hint shows), `:23` (`partSpacing` still lists "the notices" and omits the card), `:9-10` (an orphaned wrap).
- **Rule:** plan: "The doc comments on the column and the notice view stop naming the tap-bound settings notice and the two permission hints."
- **Fix:** correct the three. Say the *Switch windows* row grows while its hint shows, and list the column's real parts.

## Decided against, leave as they are

- Reading Reduce motion from SwiftUI's environment: the plan rejected it for stated reasons.
- `!` in `#expect` and the bare `@Suite`: the repo uses both throughout.
- The `.accessibilityHidden(true)` on the gear: it is decoration.

## Done when

`make test` is green from the worktree root (report any failure by name, even once), and the app builds: `xcodegen generate`, then `xcodebuild build -project TrackpadLauncher.xcodeproj -scheme TrackpadLauncher -configuration Debug -derivedDataPath build/dev -quiet` with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
