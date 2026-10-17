# Fixes after review

Repo root: `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/013-simplify-switchers` (git worktree; absolute paths). Do not commit. Edit only the files named below; no other test file may change.

## F1. T6 does not pin the selected-icon scale

- File: `LauncherKit/Tests/LauncherCoreTests/SwitcherRowLayoutTests.swift`, lines 63-67 (`theSelectedIconIsLargerThanTheOthersAndInsideTheHighlight`).
- Rule: plan T6, "1.12, 80 and 92 are today's values (R2 'unchanged from today')". The test only compares the constants with each other, so any scale between 1 and 1.15 passes.
- Fix: add `#expect(SwitcherRowLayout.selectedIconScale == 1.12)` and check the product against the literal `89.6` (within the file's tolerance), keeping the `> fullIconSide` and `<= fullHighlightSide` checks.

## F2. The highlight-gap arithmetic is written out four times

- File: `LauncherKit/Tests/LauncherCoreTests/SwitcherRowLayoutTests.swift`, lines 21-51 (the first-highlight, last-highlight, single-icon and shrunk-row tests).
- Rule: Duplicated Code smell; tdd `tests.md`, each test reads as one logical assertion.
- Fix: add one private helper in the suite, e.g. `gaps(_ layout: SwitcherRowLayout) -> (left: Double, right: Double, top: Double, bottom: Double)`, where left is measured with the highlight on the first icon (`centreX(at: 0)`) and right with it on the last (`centreX(at: Double(layout.iconCount - 1))`). Use it in those four tests. Keep every expected value and tolerance as now.

## F3. Inlined tolerances beside the `close` helpers

- Files: `SwitcherRowLayoutTests.swift:45` (`abs(... ) < 0.0001`); `WindowColumnLayoutTests.swift`, the T8 test `aShrunkColumnNarrowsItsWidthAndTitleColumnByTheRowsFactor` and the shrunk half of `theTitleColumnEndsAtTheRowsInsetAtEveryScale` (`abs(...) < 0.001`).
- Rule: Duplicated Code smell; the file already has a comparison helper.
- Fix: give each file's `close` a tolerance parameter with the current value as its default (`0.01` and `1e-9`), e.g. `close(_ value: Double, _ expected: Double, within tolerance: Double = 0.01)`, and replace the inlined `abs` comparisons with `close(..., within: 0.0001)` / `close(..., within: 0.001)`. Same tolerances as today.

## F4. `SwitcherPanel` reads `panelSize` twice to build one size

- File: `LauncherKit/Sources/LauncherUI/SwitcherPanel.swift:34`: `let size = CGSize(width: layout.panelSize.width, height: layout.panelSize.height)`.
- Rule: computing the same layout value twice in the shell; the shell should read the layout once.
- Fix: `let panelSize = layout.panelSize` then build the `CGSize` from it. No behaviour change.

Not fixed (decided): T1 and T8 stay separate tests rather than folded into the existing rows; separate tests keep one logical assertion each. `panelSize` stays a tuple, matching `WindowColumnLayout`.

## Done when

`/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/013-simplify-switchers/Scripts/test.sh` is green (whole suite).
