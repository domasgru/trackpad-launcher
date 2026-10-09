# Domain model

The glossary for Trackpad Launcher. Use these words, with these meanings, everywhere: docs, plans, code, UI.

## Trackpad Launcher
The product. A macOS menu bar app that brings apps to the front with trackpad gestures.

## Gesture
One of the four launcher gestures: the thumb anchored in the anchor corner, plus a tap with one, two, three or four fingers. Gestures are named by finger count: *1-finger gesture* … *4-finger gesture*.

## Anchor corner
The corner of the trackpad where the thumb rests to arm a gesture. Top-left in right-hand mode, top-right in left-hand mode. A fixed zone; not user-tunable.

## Anchored thumb
A finger resting inside the anchor corner. While a thumb is anchored, the trackpad is in *launcher mode*: taps with the other fingers are gestures.

## Tap
Fingers that touch down and lift again within a short window, without dragging. A gesture fires once per tap, when the fingers lift. The *finger count* of a tap is the number of fingers that touched during the tap, not counting the anchored thumb.

## Hand mode
*Right hand* (anchor corner top-left, the default) or *Left hand* (anchor corner top-right). One global setting.

## Assignment
The app chosen for a gesture, identified by its bundle identifier, not its location. A gesture is *assigned* or *unassigned*. An assignment is *missing* when no copy of the app exists outside the Trash; it recovers by itself when a copy exists again.

## Target app
The app assigned to the gesture that just fired.

## Bring to front
What a gesture does to its target app: launch it if it is not running; otherwise unhide, restore minimised windows or open a new window as needed, and make it the active app.

## Launcher window
The window that opens from the menu bar icon: four gesture rows, the hand-mode toggle, the hint, and Quit.

## Gesture row
One line in the launcher window: a gesture illustration and the app picker for that gesture.

## App picker
The popup in a gesture row that sets the assignment: the installed apps, *Other…* (choose any app on disk) and *None* (unassign).

## Trackpad
A connected Apple trackpad. Its *kind* is *built-in* or *external* (a Magic Trackpad). macOS keeps trackpad settings per kind, so an external trackpad's settings can differ from the built-in one's. A Magic Mouse is not a trackpad.

## Conflicting setting
A system trackpad setting that binds an action to a tap rather than a click, so it cannot coexist with gestures. Today: *Tap to click* and *Look up: Tap with three fingers*. The list is one table in the code; a setting is *conflicting* when it is on for any connected trackpad.

## Gestures active / inactive
Gestures are *active* when Trackpad Launcher is running, at least one trackpad is connected, and no conflicting setting is on for any connected trackpad. Otherwise gestures are *inactive*: nothing is recognised and nothing fires.

## Trackpad settings notice
The message in the launcher window, shown while gestures are inactive, that names the conflicting settings currently on (or says no trackpad is connected) and opens System Settings for the user.

## Feedback
The haptic pulse the trackpad gives when a gesture fires for an assigned, present target app.

## Click blocking
Ignoring trackpad clicks (left-click, right-click, Force Click) for the first 3 seconds after a thumb becomes anchored, while it stays anchored, another finger is on the trackpad, and gestures are active. A press is blocked or passed whole. It needs the Accessibility permission; without it, clicks are never blocked. Pointer movement, scrolling and mouse clicks are never blocked.

## Accessibility hint
The message in the launcher window, shown while Trackpad Launcher lacks the Accessibility permission, that says clicks are not blocked during gestures and opens System Settings for the user.
