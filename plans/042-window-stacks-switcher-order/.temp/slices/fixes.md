# Fixes after review (plan 042)

## Context

The repo is a SwiftPM package in `LauncherKit/`. Run everything from `/Users/dominykasgrubys/code/trackpad-launcher/.claude/worktrees/042-window-stacks-switcher-order`.

All five slices are committed, and the full gate (`make test`) is green. Fix only the findings below. Do not change behaviour beyond them. Do not commit.

## Findings to fix

### 1. Negated Boolean inside `#expect`

**Rule.** `macos-dev-workflow:swift-testing-pro`, `references/core-rules.md`, forbids negating Booleans with `!` inside `#expect`. Use `#expect(x == false)` instead, or a positive form that reads better.

**Sites.** All paths are under `LauncherKit/Tests/`:
- `LauncherCoreTests/NoWindowsCardTests.swift`, lines 224, 242 and 260.
- `LauncherCoreTests/WindowStackTests.swift`, lines 45, 52 and 54.
- `LauncherCoreTests/WindowStacksOnScreenTests.swift`, line 205.
- `LauncherPlatformTests/WindowCountReadTests.swift`, line 71.
- `LauncherUITests/WindowSwitcherCardTests.swift`, lines 69 and 85.

**Fix.** Rewrite each one without `!`. Grep the files this branch added or changed for any other `#expect(!` and fix those too: `git diff main...HEAD --name-only -- LauncherKit/Tests`.

### 2. Force-unwraps in tests

**Rule.** `swift-testing-pro`, `references/writing-better-tests.md`, says to unwrap optionals with `try #require(...)` and not with `!`.

**Sites.**
- `LauncherCoreTests/WindowStackTests.swift`, lines 42, 46, 89, 98, 106, 107 and 112. These are `WindowStack(windows: 3)!` and similar.
- `LauncherCoreTests/WindowStacksOnScreenTests.swift`, line 12.
- `LauncherUITests/WindowSwitcherCardTests.swift`, line 21 (`orders.list(...)!`).
- `LauncherUITests/SwitcherStackTests.swift`, lines 56, 191 and 198.

**Fix.**
- Inside tests, use `try #require(...)` and mark the test `throws`.
- In a non-throwing helper or fixture, such as a static stack value used by many rows, make the helper `throws` and call it with `try`. If that is truly awkward, keep a helper that unwraps once with a clear `preconditionFailure` message. Prefer `#require`.

### 3. T42 is partial: the lift's 200 ms deadline is untested

**Rule.** The plan's test row T42 reads: "A two-window window swipe asks for 200 ms at its start and at its lift."

**Gap.** The only deadline assertion is `frontmostDeadlines == [.milliseconds(200)]`, for the declined fronts, in `LauncherCoreTests/NoWindowsCardTests.swift:155`.

**Fix.** Add a World test next to it:
1. Safari is frontmost with two windows, and *Switch windows* is on.
2. The user window-swipes and lifts.
3. Expect `system.frontmostDeadlines == [.milliseconds(200), .milliseconds(200)]`: one read at the start, one at the lift.

Show it red first by temporarily breaking the lift's deadline argument in your head, or by checking it fails before the assertion exists. Then confirm it passes.

### 4. `readEach`'s default `readOne` resolves the private function on every read

**Rule.** The doc comment says the private window-number function is "resolved once" (plan: "the private window-number function resolved once (into a `Sendable` holder, so the off-main reads can call it)").

**Defect.** In `LauncherKit/Sources/LauncherPlatform/AppWindowReader.swift`:
- `AXWindowCalls.init()` calls `dlsym` (around line 290).
- `readEach`'s default `readOne`, `{ AppWindowReader.read($0, budget: $1, calls: AXWindowCalls()).read }` (around line 110), builds a new `AXWindowCalls` per app per swipe. So `dlsym` runs on every row read.

**Fix.** Resolve once:
- Give `AXWindowCalls` a single shared instance, e.g. `static let shared = AXWindowCalls()`. It is a `Sendable` struct holding a C function pointer, so check that it compiles clean under Swift 6.
- Use that shared instance from both the default `readOne` and the reader's own `calls`.

### 5. Duplicated hop in `readEach`

**Rule.** Code smell: duplicated code.

**Sites.** `DispatchQueue.main.async { MainActor.assumeIsolated { answer(slot, read) } }` appears twice, in `AppWindowReader.swift` at lines 123 and 127.

**Fix.** Pull it into one small local function, e.g. `func hop(_ slot: Int, _ read: WindowRead)`, and call it from both places.

### 6. Stale header comment on `AppWindowReader`

**Rule.** Code smell: a misleading name or comment.

**Site.** The header doc comment at the top of `AppWindowReader.swift` still begins "The frontmost app's windows, read through …". The type now also reads every row app's windows, away from the main actor, for counting only.

**Fix.** Reword the header so it says what the type owns:
- the frontmost app's read on the main actor, whose listed windows a raise may name;
- the switcher row's reads away from it, which are only counted;
- `openWindows(among:)`.

Keep the rest of the comment: the private function, and the frame and title fallback.

## Findings not fixed (decided)

- **Live-Mac platform tests** (`WindowCountReadTests`, `OpenWindowsTests`). The plan chose real-adapter rows T13, T25 and T44 at this seam on purpose, so they stay.
- **Plain `@Suite`.** This is the repo's convention, used in 94 files.
- **Panels no longer `final`, and `panel:` injection.** These are the agreed bench seam.
- **Call-counting assertions on `openWindowsQueries` and `countReads`.** The plan's rows T23, T45, T9 and T6 assert exactly these.
- **The `WindowStackLayout.Copy` name.** It is the plan's name.
- **`messagingTimeout` alongside `windowReadDeadline`.** They are different concepts: the process default versus the per-read budget.

## Done when

- All six fixes are in.
- The full `Scripts/test.sh` is green.
- Report each fix with its file and line, and the test results.
