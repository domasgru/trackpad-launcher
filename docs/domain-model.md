# Domain model

The glossary for Trackpad Launcher. Use these words, with these meanings, everywhere: docs, plans, code, UI.

## Trackpad Launcher
The product. A macOS menu bar app that brings apps to the front with trackpad gestures.

## Gesture
One of the five tap gestures: the thumb anchored in the anchor corner, plus a tap with one, two, three, four or five fingers. Gestures are named by finger count: *1-finger gesture* … *5-finger gesture*. The swipe and the swap are the other ways to reach an app and are not gestures in this sense.

## Anchor corner
The corner of the trackpad where the thumb rests to arm a gesture, or taps to swap apps. Top-left in right-hand mode, top-right in left-hand mode. A fixed zone; not user-tunable.

## Anchored thumb
A finger resting inside the anchor corner. While a thumb is anchored, the trackpad is in *launcher mode*: taps with the other fingers are gestures. Landing order matters: a thumb that lands under fingers already resting is not anchored while it taps (see *Thumb tap*); one that stays down past the tap window is anchored once the fingers lift.

## Thumb tap
A contact that lands inside the anchor corner, does not drag more than 3 mm, and lifts within the tap window (400 ms). Each landing is judged on its own: a thumb that lifts and lands again is a new thumb tap. Under two resting fingers it fires a swap; otherwise it is only an anchored thumb that lifted. A thumb that lands under resting fingers and stays down longer than the tap window never swaps and is an anchored thumb once the fingers lift. A press during the thumb tap, withheld or delivered, is part of it: unlike a tap, a thumb tap is never cancelled by a click.

## Edge contact
A contact that lands where the side of a palm rests beside the pad: closer than 3 mm to the bottom edge, anywhere along its length, or closer than 3 mm to the hand-side edge and more than 40% of the trackpad's height down from the top. The 40% line is a share of the height, like the anchor corner's size, so the band sits at the same place on every trackpad size; the 3 mm width is the same everywhere. A contact landing anywhere else near an edge, the top edge, the edge opposite the hand side, or the upper part of the hand-side edge, is a finger like any other. An edge contact is ignored for as long as it stays down: it neither starts nor joins a tap or a swipe, and it is not another contact for arming, click blocking or Dock swipe blocking. A finger that lands farther in and slides into the band stays a finger; a contact that lifts and lands again is judged by its new landing point.

## Tap
Fingers that touch down and lift again within a short window, without dragging. A gesture fires once per tap, when the fingers lift. The *finger count* of a tap is the number of fingers that touched during the tap, not counting the anchored thumb or any edge contact. Two fingers that slide sideways more than 3 mm under the anchored thumb are a swipe, not a tap; two fingers that rest longer than the window fire nothing but may still become a swipe.

## Swipe
Two fingers sliding left or right, started under an anchored thumb while the swipe setting is on: the thumb anchored first, exactly two fingers landed, and one of them moved more than 3 mm, more sideways than up or down, with no time limit. The thumb only starts the swipe; afterwards it may stay, lift, leave the corner or land again, and nothing changes. A swipe ends when both fingers have lifted; a finger that briefly loses contact and lands again rejoins it. It is cancelled when a third finger lands outside the anchor corner while both are down, or a click reaches apps. Clicks and scrolling stay blocked for the whole of a swipe, whether or not a switcher shows. Nothing further happens until every non-thumb finger has lifted.

## Switcher
The on-screen row shown during a swipe: a Liquid Glass panel centred on the pointer's display, holding one row of at most 10 icons, the frontmost app at the left end followed by the 9 most recently used other running apps that no gesture is assigned to, in their order, a glass highlight that follows the fingers, and the selected icon drawn slightly larger with its name below (the name macOS shows for the running app). A running app that any of the five gestures is assigned to is left out, by its bundle identifier (every running copy of that bundle, and whether or not the assignment is missing), so its slot goes to the next most recently used app without a gesture; only the frontmost app is shown whatever its gesture. The assignments in place when the swipe begins decide the row; there is no setting for this. Icons are 80 pt, 20 pt apart; when that row would not fit the display, the icons and the gaps shrink by one factor so the whole row fits in one row. The highlight moves one icon for every 100 points the cursor would travel for the same finger movement, with macOS's own pointer acceleration at the user's tracking speed, whatever the icons' size on screen. The selection starts on the frontmost app; sliding right moves it to apps used longer ago and sliding left back towards the frontmost app, in both hand modes. The selected icon is the nearest one, so the selection changes halfway to the next icon. The ends are hard stops with a small rubber band that adds no dead zone: the moment the fingers turn back, travel past the end is forgotten and the next icon is the usual half icon away. The row is fixed when the swipe begins: an app that launches during the swipe is not in it, and one that quits stays in it. Lifting brings the selected app to the front with the gesture haptic; lifting on the frontmost app, or on an app that has quit, does nothing and is silent. It never takes focus, and shows nothing when there is nothing to switch to, as when every other running app has a gesture: the swipe then still runs its course, blocking clicks and scrolling until the fingers lift.

## Running apps
The apps macOS's ⌘-Tab shows, in its order: every running app that appears in the Dock, whether hidden, minimised, windowless, on another Space or in full screen, most recently activated first; never a menu bar app, and never Trackpad Launcher. Read from LaunchServices at the moment a swipe begins and again when it ends, and at each thumb tap that may swap; the model keeps none of it beyond the last swap of the latest swap series, which is replaced when the next series starts. Should macOS stop revealing the order, the app in front when Trackpad Launcher started and the apps activated since come first, most recent first, and the rest follow in the order they launched.

## Swipe setting
One global setting, on by default, shown as the *Swipe to switch apps* switch in the launcher window's switcher section. While it is off there is no swipe: two fingers sliding under an anchored thumb are not a swipe, no switcher appears, the slide scrolls once the blocking window has passed, and only the tap rules block clicks, scrolling and the system's trackpad swipes (the blocking window, and Dock swipe blocking while a thumb is anchored and another finger is down). Taps and swaps are unchanged. A change applies to the next swipe and is saved at once, so it survives a quit, a force-quit or a Mac restart.

## Swap
Bringing to front the app used most recently before the frontmost app, like a quick ⌘-Tab, with nothing on screen. Fired by a thumb tap while exactly two fingers rest outside the anchor corner (edge contacts aside), both landed before the thumb, however shortly, whether or not they are moving or have scrolled, while the swap setting is on and gestures are active. The target is the first of the running apps, in ⌘-Tab order, that is not the frontmost app, whether or not a gesture is assigned to it; with no frontmost app, as while Trackpad Launcher itself is active, the most recently used running app. It fires when the thumb lifts: the gesture haptic, bring to front, and the launcher window closes; never the launch animation. With nothing to swap to it is silent. The order is read afresh at each thumb tap; while the last swap's app is still coming to the front (the read still shows the app that swap started from, and the app it brought to front is still running), that app counts as the frontmost app, so rapid taps alternate. Thumb first, then fingers, is a gesture or a swipe, never a swap. Not a gesture in the glossary's sense.

## Swap series
The swaps made while the same two fingers stay down: from the first thumb tap that fires under them until no finger rests outside the anchor corner. A series finger that lifts rejoins if it lands again while the other is still down. The fingers may move freely. The series stops swapping, but keeps blocking, once a third finger lands outside the anchor corner; it ends when no finger rests outside the anchor corner. Clicks, scrolling and the system's trackpad swipes stay blocked for the whole series, as during a swipe. The model remembers only the last swap made, to target the next one while that swap's app is still coming to the front; that memory is replaced when the next series starts.

## Swap setting
One global setting, on by default, shown as the *Thumb tap to swap apps* switch in the launcher window's switcher section, below the swipe setting's switch. While it is off there is no swap and no swap series: a thumb that lands under resting fingers is an anchored thumb that waits for them to lift, as before the swap existed, and only the thumb rules block. Independent of the swipe setting. A change applies to the next thumb tap and is saved at once, so it survives a quit, a force-quit or a Mac restart. Upgrading from a version without the setting leaves it on and changes no other setting.

## Frontmost app
The active app at the moment a swipe begins or a thumb tap lifts; never Trackpad Launcher. Trackpad Launcher is active only when macOS makes it so: right after it is opened (from Finder, or Run in Xcode) and around the Other… chooser. It sits at the left end of the switcher's row and the selection starts on it, so the user can stay where they are; it is there even when ⌘-Tab would not show it, such as a menu bar app with a window in front, and even when a gesture is assigned to it. When there is none, as while Trackpad Launcher itself is active, the row is the running apps without a gesture alone, the selection starts on the most recently used one, and lifting on any app, that one included, brings it to the front; a swap brings the most recently used one to the front.

## Hand mode
*Right hand* (anchor corner top-left, the default) or *Left hand* (anchor corner top-right). One global setting. The *hand-side edge*, where the palm rests beside the pad, is the right edge in right-hand mode and the left edge in left-hand mode; with the bottom edge, it is where an edge contact can land.

## Assignment
The app chosen for a gesture, identified by its bundle identifier, not its location. A gesture is *assigned* or *unassigned*. An assignment is *missing* when no copy of the app exists outside the Trash; it recovers by itself when a copy exists again. An assigned app is left out of the switcher's row, missing or not, unless it is the frontmost app; the swap still reaches it.

## Target app
The app assigned to the gesture that just fired.

## Bring to front
What a gesture does to its target app: launch it if it is not running; otherwise unhide, restore minimised windows or open a new window as needed, and make it the active app.

## Launcher window
The window that opens from the menu bar icon: five gesture rows, the switcher section (the swipe illustration, its title and the swipe setting's switch, then the thumb tap illustration, its title and the swap setting's switch), the hand-mode toggle, the launch animation switch, the hint, and Quit.

## Gesture row
One line in the launcher window: a gesture illustration and the app picker for that gesture.

## Installed apps
The apps an app picker lists: every app in /Applications and /System/Applications (with their subfolders), in ~/Applications, and Finder. One entry per bundle identifier. An app anywhere else, such as ~/Downloads, is not an installed app in this sense, even when a gesture is assigned to it through *Other…*.

## Recent apps
The up to 10 installed apps the user opened most recently, newest first, as Spotlight records it (an app's last-used date). Opening means launching; switching to an app that is already running does not count. No age limit. All five app pickers show the same recent apps; they refresh each time the launcher window opens and may lag behind the very latest launches.

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
The haptic pulses the trackpad gives: the *gesture haptic* when a gesture fires for an assigned, present target app, when a swipe opens an app and when a swap brings an app to front, and the *light tick*, a lighter pulse, each time the switcher's selection changes. A swipe lift or a thumb tap that changes nothing is silent: a lift on the frontmost app, on an app that has quit, or with no switcher showing; a thumb tap that is not a swap, or with nothing to swap to.

## Light tick
The lighter haptic pulse that marks each change of the switcher's selection: one per icon the highlight crosses, none while the selection stays put.

## Launch animation
The target app's icon floating up from the pointer when a gesture fires for an assigned, present target app, together with the feedback. Only gestures play it: a swipe and a swap never do. It appears at once at full size, puffs up for a split second, then rises faster and faster as it shrinks, sways and tilts a little to one side, and fades out within about a third of a second, like a small balloon letting its air out. With the system's Reduce motion setting on, it fades out in place instead. It never takes focus or receives clicks, and every fired gesture plays its own. The *launch animation setting* turns it off.

## Launch animation setting
One global setting, on by default, shown as the *Launch animation* switch in the launcher window below the hand-mode toggle. While it is off, a gesture shows nothing at the pointer, whatever the system's Reduce motion setting; the feedback, bring to front and closing the launcher window are unchanged. A change applies to the next gesture and is saved at once, so it survives a quit, a force-quit or a Mac restart. Upgrading from a version without the setting leaves it on and changes no other setting.

## Sway
A launch animation's small sideways veer, to the left or to the right, never more than a third of its rise, with a slight tilt toward that side. The side is random, except that the same side never comes up three times in a row.

## Click blocking
Ignoring trackpad clicks (left-click, right-click, Force Click) for the first 3 seconds after a thumb lands in the anchor corner, while it stays there, another finger is on the trackpad, and gestures are active, and for the whole of a swipe or a swap series. A thumb that lands under resting fingers opens that window like any other, so before a series starts the thumb rules alone apply. A press is blocked or passed whole. It needs the Accessibility permission; without it, clicks are never blocked. Under the same rule, trackpad and Magic Mouse scrolling is suppressed: a scroll suppressed at any point stays suppressed, momentum included, until its fingers lift, and a scroll that began unsuppressed coasts to a stop as usual. Pointer movement and a mouse's scroll wheel are never blocked; a mouse click is blocked only while another finger rests on the trackpad inside the blocking window or a swipe or a swap series is on, when it cannot be told from a trackpad press. The system's own trackpad swipes to another desktop, a full-screen app, Mission Control or App Exposé are blocked too, with no time limit: for as long as a thumb is in the anchor corner and another finger is down, and for the whole of a swipe or a swap series. macOS can count the anchored thumb as a finger, so thumb plus two sliding fingers can read as its three-finger swipe. A system swipe is blocked or passed whole, decided when it begins. With the swipe setting off there is no swipe, and with the swap setting off no swap series, so only the thumb rules apply.

## Blocking window
The first 3 seconds after a thumb lands in the anchor corner, during which click blocking applies; held open for the whole of a swipe or a swap series, however long after the thumb landed and whether or not it stays. A thumb that was already resting when recognition restarted (after a trackpad change, wake, or a settings change) opens no window: its landing time is unknown, so clicks pass.

## Accessibility hint
The message in the launcher window, shown while Trackpad Launcher lacks the Accessibility permission, that says clicks and scrolling are not blocked during gestures and opens System Settings for the user.
