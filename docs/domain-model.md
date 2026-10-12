# Domain model

The glossary for Trackpad Launcher. Use these words, with these meanings, everywhere: docs, plans, code, UI.

## Trackpad Launcher
The product. A macOS menu bar app that brings apps to the front with trackpad gestures.

## Gesture
One of the five tap gestures: the thumb anchored in the anchor corner, plus a tap with one, two, three, four or five fingers. Gestures are named by finger count: *1-finger gesture* … *5-finger gesture*. The swipe is the other way to reach an app and is not a gesture in this sense.

## Anchor corner
The corner of the trackpad where the thumb rests to arm a gesture. Top-left in right-hand mode, top-right in left-hand mode. A fixed zone; not user-tunable.

## Anchored thumb
A finger resting inside the anchor corner. While a thumb is anchored, the trackpad is in *launcher mode*: taps with the other fingers are gestures.

## Tap
Fingers that touch down and lift again within a short window, without dragging. A gesture fires once per tap, when the fingers lift. The *finger count* of a tap is the number of fingers that touched during the tap, not counting the anchored thumb. Two fingers that slide sideways more than 3 mm under the anchored thumb are a swipe, not a tap; two fingers that rest longer than the window fire nothing but may still become a swipe.

## Swipe
Two fingers sliding left or right, started under an anchored thumb: the thumb anchored first, exactly two fingers landed, and one of them moved more than 3 mm, more sideways than up or down, with no time limit. The thumb only starts the swipe; afterwards it may stay, lift, leave the corner or land again, and nothing changes. A swipe ends when both fingers have lifted; a finger that briefly loses contact and lands again rejoins it. It is cancelled when a third finger lands outside the anchor corner while both are down, or a click reaches apps. Clicks and scrolling stay blocked for the whole of a swipe. Nothing further happens until every non-thumb finger has lifted.

## Switcher
The on-screen row shown during a swipe: a Liquid Glass panel centred on the pointer's display, holding one row of 80 pt icons, the switcher list's present apps in list order with the frontmost app added at the left end when it is not listed, a glass highlight that follows the fingers, and the selected icon drawn slightly larger with its name below. The highlight moves exactly as far as the cursor would for the same finger movement, with macOS's own pointer acceleration at the user's tracking speed, so 100 points of cursor travel, the icon pitch, is one icon. The selected icon is the nearest one, so the selection changes halfway to the next icon. The ends are hard stops with a small rubber band; travel past an end beyond a quarter icon is dropped, so turning back moves the selection at once. Lifting brings the selected app to the front with the gesture haptic; lifting on the frontmost app does nothing. It never takes focus and shows nothing when there is nothing to switch to.

## Switcher list
The user-ordered apps the switcher shows, set in the launcher window's switcher section: add from the Add app… menu (an app picker's menu without None, with listed apps checked and disabled) or through Other…, reorder by dragging, remove from a row's hover button or context menu. No app twice; any number of apps; empty on a fresh install. An app may be on a tap gesture and in the list. A missing app is left out of the switcher and shown greyed with "not found" in the window, recovering by itself when a copy exists again.

## Frontmost app
The active app at the moment a swipe begins; never Trackpad Launcher, which never activates. The switcher's selection starts on it, so the user can stay where they are. When none can be read, no switcher appears.

## Hand mode
*Right hand* (anchor corner top-left, the default) or *Left hand* (anchor corner top-right). One global setting.

## Assignment
The app chosen for a gesture, identified by its bundle identifier, not its location. A gesture is *assigned* or *unassigned*. An assignment is *missing* when no copy of the app exists outside the Trash; it recovers by itself when a copy exists again.

## Target app
The app assigned to the gesture that just fired.

## Bring to front
What a gesture does to its target app: launch it if it is not running; otherwise unhide, restore minimised windows or open a new window as needed, and make it the active app.

## Launcher window
The window that opens from the menu bar icon: five gesture rows, the switcher section (the swipe illustration and its title, the switcher list's rows, and Add app…), the hand-mode toggle, the launch animation switch, the hint, and Quit. It grows with the switcher list and, when it would not fit the screen, the list scrolls inside it while everything else stays reachable.

## Gesture row
One line in the launcher window: a gesture illustration and the app picker for that gesture.

## Installed apps
The apps an app picker lists: every app in /Applications and /System/Applications (with their subfolders), in ~/Applications, and Finder. One entry per bundle identifier. An app anywhere else, such as ~/Downloads, is not an installed app in this sense, even when a gesture is assigned to it through *Other…*.

## Recent apps
The up to 10 installed apps the user opened most recently, newest first, as Spotlight records it (an app's last-used date). Opening means launching; switching to an app that is already running does not count. No age limit. All five app pickers and the Add app… menu show the same recent apps; they refresh each time the launcher window opens and may lag behind the very latest launches.

## App picker
The popup in a gesture row that sets the assignment: the recent apps, a divider, the other installed apps alphabetically, then *Other…* (choose any app on disk) and *None* (unassign). With no recent apps there is no recent section and no extra divider. The picker opens from a list Trackpad Launcher already holds; installed and removed apps show up in it within 5 seconds.

## Trackpad
A connected Apple trackpad. Its *kind* is *built-in* or *external* (a Magic Trackpad). macOS keeps trackpad settings per kind, so an external trackpad's settings can differ from the built-in one's. A Magic Mouse is not a trackpad.

## Conflicting setting
A system trackpad setting that binds an action to a tap rather than a click, so it cannot coexist with gestures. Today: *Tap to click* and *Look up: Tap with three fingers*. The list is one table in the code; a setting is *conflicting* when it is on for any connected trackpad.

## Gestures active / inactive
Gestures are *active* when Trackpad Launcher is running, at least one trackpad is connected, and no conflicting setting is on for any connected trackpad. Otherwise gestures are *inactive*: nothing is recognised and nothing fires.

## Trackpad settings notice
The message in the launcher window, shown while gestures are inactive, that names the conflicting settings currently on (or says no trackpad is connected) and opens System Settings for the user.

## Feedback
The haptic pulses the trackpad gives: the *gesture haptic* when a gesture fires for an assigned, present target app and when a swipe opens an app, and the *light tick*, a lighter pulse, each time the switcher's selection changes. A swipe released on the frontmost app is silent.

## Light tick
The lighter haptic pulse that marks each change of the switcher's selection: one per icon the highlight crosses, none while the selection stays put.

## Launch animation
The target app's icon floating up from the pointer when a gesture fires for an assigned, present target app, together with the feedback. It appears at once at full size, puffs up for a split second, then rises faster and faster as it shrinks, sways and tilts a little to one side, and fades out within about a third of a second, like a small balloon letting its air out. With the system's Reduce motion setting on, it fades out in place instead. It never takes focus or receives clicks, and every fired gesture plays its own. The *launch animation setting* turns it off.

## Launch animation setting
One global setting, on by default, shown as the *Launch animation* switch in the launcher window below the hand-mode toggle. While it is off, a gesture shows nothing at the pointer, whatever the system's Reduce motion setting; the feedback, bring to front and closing the launcher window are unchanged. A change applies to the next gesture and is saved at once, so it survives a quit, a force-quit or a Mac restart. Upgrading from a version without the setting leaves it on and changes no other setting.

## Sway
A launch animation's small sideways veer, to the left or to the right, never more than a third of its rise, with a slight tilt toward that side. The side is random, except that the same side never comes up three times in a row.

## Click blocking
Ignoring trackpad clicks (left-click, right-click, Force Click) for the first 3 seconds after a thumb becomes anchored, while it stays anchored, another finger is on the trackpad, and gestures are active, and for the whole of a swipe. A press is blocked or passed whole. It needs the Accessibility permission; without it, clicks are never blocked. Under the same rule, trackpad and Magic Mouse scrolling is suppressed: a scroll suppressed at any point stays suppressed, momentum included, until its fingers lift, and a scroll that began unsuppressed coasts to a stop as usual. Pointer movement and a mouse's scroll wheel are never blocked; a mouse click is blocked only while another finger rests on the trackpad inside the blocking window or a swipe is on, when it cannot be told from a trackpad press. The system's own trackpad swipes to another desktop, a full-screen app, Mission Control or App Exposé are blocked too, with no time limit: for as long as a thumb is anchored and another finger is down, and for the whole of a swipe. macOS can count the anchored thumb as a finger, so thumb plus two sliding fingers can read as its three-finger swipe. A system swipe is blocked or passed whole, decided when it begins.

## Blocking window
The first 3 seconds after a thumb becomes anchored, during which click blocking applies; held open for the whole of a swipe, however long after the thumb anchored and whether or not it stays. A thumb that was already resting when recognition restarted (after a trackpad change, wake, or a settings change) opens no window: its landing time is unknown, so clicks pass.

## Accessibility hint
The message in the launcher window, shown while Trackpad Launcher lacks the Accessibility permission, that says clicks and scrolling are not blocked during gestures and opens System Settings for the user.
