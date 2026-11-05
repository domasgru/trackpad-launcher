# Fixes after review: four thumb corners

Repository root: `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/028-thumb-corner-dropdown`; package `LauncherKit/`. All three slices are committed; the full gate (`make test`) is green at 677 tests. Fix exactly the findings below, nothing else. Do not commit. When done, run `make test` from the repository root and report the result and anything you did differently.

Skills: `macos-dev-workflow:swift-testing-pro` (findings 1, 2, 6, 7).

## 1. `!` inside `#expect` in new test lines

Rule (`macos-dev-workflow:swift-testing-pro`, core rules): never negate a Boolean with `!` inside `#expect`; compare with `== false` so the failure message shows the value.

- `LauncherKit/Tests/LauncherCoreTests/PersistenceTests.swift:118` `#expect(!relaunched.isWindowOpen)` → `#expect(relaunched.isWindowOpen == false)`.
- `PersistenceTests.swift:245` `#expect(!old.isLaunchAnimationOn && !old.isSwipeOn && !old.isSwapOn && old.isWindowSwipeOn)` → four separate expectations, one per switch, each `== false` / `== true` as set, so a failure says which key broke.
- `LauncherKit/Tests/LauncherCoreTests/GestureRecognizerTests.swift:56` `#expect(!fires(110, 55))` → `#expect(fires(110, 55) == false)`.

Only these new lines; leave older tests alone.

## 2. Force-unwraps in a throwing test helper

`LauncherKit/Tests/LauncherUITests/ThumbCornerRuleTests.swift:52-58`, `CornerIllustrationFileTests.Bitmap.init(_:) throws`: `CGColorSpace(name: CGColorSpace.sRGB)!`, `bytes.baseAddress!` and `CGContext(...)!`. Rule (`swift-testing-pro`): in a throwing test, unwrap with `try #require(...)` rather than `!`, so a failure is a test failure with a message, not a crash of the whole test process. Fix: unwrap the colour space and the context with `try #require` outside or inside the closure (make the `withUnsafeMutableBytes` closure throwing if needed: `try pixels.withUnsafeMutableBytes { bytes throws in … }`), and the base address with `try #require(bytes.baseAddress)`.

## 3. Repeated side/row switches over `ThumbCorner`

Smell: Repeated Switches. `LauncherKit/Sources/LauncherCore/Settings.swift:18-31` re-derives side and row in two four-way switches; `LauncherKit/Sources/LauncherCore/ThumbCorner.swift:11,14` spell out `self == .bottomLeft || self == .bottomRight` and `self == .topLeft || self == .bottomLeft`. Fix:
- In `ThumbCorner`, add an internal `var isLeft: Bool { self == .topLeft || self == .bottomLeft }` beside `isBottom`, and make `fractionFromSideEdge(x:)` read `isLeft ? x : 1 - x`.
- Add an internal initialiser `init(isLeft: Bool, isBottom: Bool)` on `ThumbCorner` (a four-way switch on the pair lives there once).
- `Settings.thumbCorner` becomes: get `ThumbCorner(isLeft: handMode == .right, isBottom: isThumbAtBottom)`; set `handMode = newValue.isLeft ? .right : .left; isThumbAtBottom = newValue.isBottom`. Keep the comment that `right` is the hand whose thumb rests on the left.
- Leave the test file's own `flipX`/`flipY` as written: tests stay independent of production's rule.

## 4. Unclear name `fractionFromRowEdge`

Smell: Mysterious Name. "Row edge" is not a glossary term (the domain model says "the corner's top or bottom edge"). Rename `ThumbCorner.fractionFromRowEdge(y:)` → `fractionFromTopOrBottomEdge(y:)` and `AnchorCorner.fromRowEdge(_:)` → `fromTopOrBottomEdge(_:)` (`LauncherKit/Sources/LauncherCore/Surface.swift`), with their comments.

## 5. Hand-written list of every corner in a test

Smell: Duplicated Code. `ThumbCornerRuleTests.swift:28` `nonisolated static let corners: [ThumbCorner] = [.topLeft, .topRight, .bottomLeft, .bottomRight]` → `ThumbCorner.allCases` (T3 already pins the order).

## 6. T19's bottom-right rows differ from the plan's table

Plan T19: "a one-finger tap at (123.8, 53.76) … at (1.0, 53.76) … at (123.8, 23.04) `[.one]`. The same three for `.bottomRight` with the bottom-right thumb." `LauncherKit/Tests/LauncherCoreTests/EdgeContactRecognizerTests.swift:388-390` has `(.bottomRight, 1.0, 23.04)` in place of `(.bottomRight, 123.8, 23.04)`. Fix: add `(.bottomRight, 123.8, 23.04)` to the arguments, keeping the mirrored row as well (seven rows).

## 7. T25 does not assert the rows and switches after a login start

Plan T25: "When `relaunch()` and `start()` (a login start). Then `!isWindowOpen`, `thumbCorner == .topRight`, the rows and switches as the existing test asserts". `PersistenceTests.aReleasedRecordWithRightThumbLoadsAsTopRightAndAnchorsThereAtLogin` (`PersistenceTests.swift:106-128`) asserts neither. Fix: after `relaunched.start()`, add the same assignments/rows and switch expectations that the existing test loading `Self.savedSettings` makes (it is just above, ending at line ~103: Arc on 1, Figma on 2, Spotify on 5, animation off, swipe off, swap on, window swipe off; copy its expectations' form, with `== false` rather than `!`).

## Not fixed, recorded

- T23's mask-difference threshold stays at 2% (plan said 1%): `window-swipe-bottom-inverse` differs in 15 of 1278 mark pixels (1.17%), all antialiased edge pixels of its small marks; a stale, hand-copied or whole-image-flipped asset differs by far more. The orchestrator logs this; leave the test as is, but add a one-line comment above that `#expect` saying why 2%.
- `ThumbCornerRow`'s `.controlSize(.regular)` and `.accessibilityLabel(Copy.thumbCornerRow)` stay: the plan names both explicitly.
