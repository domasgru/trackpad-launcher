# Gesture launch

The product's core: with the thumb resting on the anchor corner (top-left for right hand, top-right for left hand), tapping the rest of the trackpad with 1, 2, 3 or 4 fingers launches or brings forward the app assigned to that gesture, with haptic feedback, and closes the launcher window if it was open. An unassigned gesture, a missing app, or inactive gestures do nothing.

Last proven live: never. Every step needs a person at the trackpad.

## Sub-features

- `launch-fire` launches or focuses the assigned app from a thumb-anchored tap with 1–4 fingers.
- `launch-closes-window` closes an open launcher window when a gesture fires.
- `launch-silent-unassigned` does nothing, with no haptic, for a gesture with no assignment.
- `launch-silent-missing` does nothing for a gesture whose app is not installed.
- `launch-click-blocking` blocks the physical click during a gesture when Accessibility is granted.

## How to get to it (user POV)

- Rest the thumb on the anchor corner and tap with N fingers anywhere else on the trackpad.

## Driving it with tlv

Preconditions:

- Baseline from `README.md` (gesture 1 → TextEdit, 2 → missing, 3 and 4 unassigned, right hand). TextEdit is not running.
- `$T doctor` shows `others: none`. Otherwise the user's own copy fires too.
- Gestures active: the window shows the `Hold thumb on top-left corner` hint.
- A person at the Mac. MultitouchSupport frames can't be synthesized, so every step here is **human**.

- **Fire 1 finger (human).** Run `$T open` and `$T record launch-1-before frontmost`, then ask the user to hold their thumb top-left and tap with one finger. Then run `$T record launch-1-after frontmost` and `$T record launch-1-window status`. The frontmost app is `TextEdit (com.apple.TextEdit)` and the window is closed.
- **Missing app (human).** Ask for the 2-finger gesture. `$T record launch-2-after frontmost` is unchanged, and the user reports no haptic.
- **Unassigned (human).** Ask for the 3-finger gesture. Nothing happens.
- **Left hand (human).** Run `$T hand left` and ask for the 1-finger gesture with the thumb top-right. TextEdit comes forward. The same gesture with the thumb top-left does nothing.
- **Proof.** The `launch-*` records above, one before/after pair per gesture.

## Gotchas

- An agent alone cannot verify this feature. The behavior is covered by `swift test` (`Scripts/test.sh`) through the `TouchScript` fixtures, which feed recognizer frames at the `TrackpadHardware` port. That's a unit-level proof, not a live one.
- Click blocking needs Accessibility trust, and the `.verify` build doesn't have it (see `settings-notices.md`). Prove click blocking with the user's own signed copy, not this build.
- Tap to click (or three-finger Look up) being on deactivates every gesture. Read the window before blaming the recognizer.
- Quit TextEdit between attempts. "Brought forward" and "launched" look the same in `$T frontmost`.
