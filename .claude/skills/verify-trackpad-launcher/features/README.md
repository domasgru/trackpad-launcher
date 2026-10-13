# Trackpad Launcher verification map

This directory is the maintained source for verifying Trackpad Launcher's user-facing behavior. Read this index before driving the app, then use the matching feature file as the recipe. Every command is `tlv` from `../scripts/tlv`, run from the repo root as `$T` (`T=.claude/skills/verify-trackpad-launcher/scripts/tlv`).

## Baseline preconditions

- `$T build` succeeded for the code under test (`TLV_REPO` for a worktree).
- `$T launch` (default fixture) printed `ready:`. The fixture is gesture 1 → TextEdit, 2 → "Ghost App" (not installed), 3 and 4 unassigned, right hand.
- `$T doctor` ends with `doctor: OK`.
- Never drive an instance this run didn't start.

## Driving conventions

- Drive through the menu bar icon, the pickers, the toggle and the buttons via `tlv`. Never fake state with `defaults write`. Seeding (`--seed`) is for preconditions only.
- Commands that act inside the window (`rows`, `menu`, `pick`, `hand`, `press`) reopen it if a real click elsewhere closed it. Read-only commands (`tree`, `frame`, `capture`) don't, so run `$T open` before them. When a recipe asserts that the window stayed open or closed, read `$T status` immediately after the action.
- After `$T launch --seed keep`, the window starts closed.
- Steps marked **ask first** take focus on the user's desktop. Get the user's OK before running them.
- Leave the stored settings as the recipe found them, or finish with `$T cleanup`.

## Proof and skip reporting

- Capture before and after (`$T capture <id>-before`, act, `$T capture <id>-after`).
- Save every command-output check through `$T record <id> <command>` so it lands in the evidence dir with its exit code.
- Every mutation proves its side effect with `$T settings`. Persistence is proven by `$T quit` then `$T launch --seed keep` and reading the result again.
- Name each artifact after the sub-feature ID it proves, e.g. `assign-pick-settings`.
- Steps marked **human** need a person at the Mac. Report them as *not verified by the agent* unless the user performed them while you captured the result.
- Do not report a skipped entry point as verified through a different path.

## Feature entry contract

Each feature file starts with an H1 title, one paragraph describing the user-visible behavior, and a `Last proven live:` line naming the date, the evidence dir, and the steps that were not run. Update that line whenever you drive the recipe. It then uses exactly four H2 sections in this order.

1. `Sub-features` lists short IDs with one line for each behavior.
2. `How to get to it (user POV)` lists every user entry point.
3. `Driving it with tlv` starts with `Preconditions:` and uses labeled bullets that pair each user action with an exact command and observable result.
4. `Gotchas` lists traps that can waste or invalidate a verification run.

## Features

- [Launcher window](./launcher-window.md) covers opening and closing from the menu bar icon, Escape, outside click, Quit, and staying out of the Dock.
- [Gesture assignments](./gesture-assignments.md) covers picking an app per gesture, None, the checked item, missing apps, Other…, and persistence.
- [Hand mode](./hand-mode.md) covers the Left/Right hand toggle, its hint text, mirrored illustrations, and persistence.
- [Settings notices](./settings-notices.md) covers the Accessibility notice, the trackpad-settings conflict notice, and their System Settings buttons.
- [Gesture launch](./gesture-launch.md) covers thumb-anchored 1–4 finger taps launching or focusing the assigned app (human-driven).
