# Hand mode

A segmented `Left hand` / `Right hand` toggle sets which top corner anchors the thumb: top-left in right-hand mode (the default), top-right in left-hand mode. The hint text names the corner, the gesture illustrations mirror, and the choice is saved.

Last proven live: 2026-10-13, `/tmp/tlv-evidence/20261013-120421` (`hand-*`). Not run: the physical corner change (see `gesture-launch.md`).

## Sub-features

- `hand-toggle` switches between Left hand and Right hand from the segmented control.
- `hand-hint` names the anchor corner in the hint: `top-left` for right hand, `top-right` for left hand.
- `hand-mirror` mirrors the gesture illustrations horizontally in left-hand mode.
- `hand-persist` keeps the chosen mode across relaunch.

## How to get to it (user POV)

- Open the launcher window and click `Left hand` or `Right hand` below the gesture rows.

## Driving it with tlv

Preconditions:

- Baseline from `README.md` (default fixture, right hand), with gestures active: after `$T open`, `$T tree` shows the `Hold thumb on top-left corner` hint, not a `Gestures are off` notice.

- **Before.** Run `$T open`, then `$T capture hand-before`. In `hand-before.ax.txt`, `AXRadioButton label="Right hand"` has `value="1"` and the hint says `top-left corner`.
- **Switch to left.** Click `Left hand`. Run `$T hand left`, then `$T capture hand-left`. In `hand-left.ax.txt`, `label="Left hand"` has `value="1"` and the hint says `top-right corner`. `$T settings` has `"handMode": "left"`.
- **Mirror.** Compare `hand-before.png` and `hand-left.png`. The thumb dot in each illustration moves from the top-left to the top-right of its box.
- **Persist.** Run `$T quit`, `$T launch --seed keep`, `$T open`, then `$T record hand-persist tree`. `label="Left hand"` still has `value="1"`.
- **Switch back.** Run `$T hand right`. `$T settings` has `"handMode": "right"`.

## Gotchas

- The hint is only shown while gestures are active. If the user's trackpad settings make gestures inactive, the conflict notice replaces it (see `settings-notices.md`). Prove the hint with an active trackpad.
- The hint starts with U+FFFC image placeholders for the inline marks. Match on `top-left corner` / `top-right corner`, not the whole string.
- Hand mode changes the gesture recognizer's anchor corner. Only a physical gesture proves the corner actually moved (see `gesture-launch.md`).
