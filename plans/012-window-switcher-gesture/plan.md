# Plan: Swipe up or down to switch windows

## Problem statement

Trackpad Launcher reaches apps, not windows. The swipe brings another app to the front, and a gesture brings its target app to the front. Users who keep several windows of one app open, such as browser windows, editor projects or Finder windows, still reach for ⌘-` or Mission Control to move between them. ⌘-` gives no overview: the user cycles blind until the right window turns up. Mission Control takes over the whole screen and needs a click. Minimised windows are reachable only from the Dock.

## Solution

A new action, the **window swipe**: with the thumb anchored, the user slides two fingers up or down instead of sideways. A small **window switcher** appears in the top-left corner of the display. It lists the frontmost app's windows, front window first, each as a row with a small preview and the window title. Sliding down moves the selection to the next window and up moves it back. Each time the selection moves, the selected window comes to the front at once, so the user sees it at full size behind the switcher. Lifting keeps the selected window in front. Sliding back to the first row and lifting leaves things as they were.

The window swipe exists only when there is something to switch to: the frontmost app has at least two windows. Otherwise, a slide up or down is no window swipe. Nothing appears, and the slide behaves exactly as if the window swipe switch were off. The same holds without the Accessibility permission, since windows cannot be read without it.

Previews need the macOS Screen Recording permission. Without it, rows show the app icon and the title. The launcher window shows a hint that asks for the permission. The window swipe itself never prompts.

The window swipe has its own switch, **Swipe up or down to switch windows**, on by default. It sits in the launcher window's switcher section, below *Thumb tap to swap apps*. It is independent of the other two switches.

Terms, for the glossary. New: *window swipe* (the action above), *window switcher* (its on-screen list), *window* (an app's normal window, as R4 defines it), *front window* (the app's window in front when the window swipe begins), *window swipe setting* (the switch), *screen recording hint* (the launcher window's message). The *swipe* entry gains that its two fingers slide more sideways than up or down, and that a slide's direction is decided once. The *launcher window*, *feedback*, *light tick*, *click blocking* and *blocking window* entries change to mention the window swipe. Like the swipe, the window swipe is not a *gesture* in the glossary's sense.

### Documentation

`docs/product-overview.md` gains the window swipe next to the swipe: with the thumb held in the corner, sliding two fingers up or down shows the frontmost app's windows in the top-left corner and brings each visible window to the front as the fingers pass it. That sentence gains "when the frontmost app has two or more windows". The app switcher's silent-lift exception extends to the window swipe, and loses its clause about a "No open windows" or Accessibility message: there is no such message, since a slide on an app with fewer than two windows, or without Accessibility, is no window swipe. The privacy note changes: the app may ask for Screen Recording, used only to draw window previews while the window switcher shows. `docs/domain-model.md` follows the terms above.

## Requirements

### R1. Two fingers sliding up or down under an anchored thumb start a window swipe
While the window swipe setting is on and gestures are active, a window swipe MUST start when the thumb is anchored first, exactly two fingers land, and one of them moves more than 3 mm, more up or down than sideways. The start rules MUST otherwise match the swipe's. There MUST be no time limit. Edge contacts (as the glossary defines them) MUST neither start nor join a window swipe. Once a window swipe has started, the thumb may stay, lift, leave the corner or land again, and nothing MUST change. The window swipe MUST work in both hand modes. A window swipe MUST start only when the frontmost app has at least two windows (R13). Deciding this MUST add no delay the user can notice: the switcher MUST appear within 50 ms of the movement that starts the window swipe. The window count MUST be the number of rows the switcher shows, so a switcher never appears with fewer than two rows. "Gestures are active" is the glossary's term: Trackpad Launcher is running, a trackpad is connected, and no conflicting setting is on. Gestures being active does not need the Accessibility permission; the window swipe does (R14).

#### Scenario: Slide down starts a window swipe
- **GIVEN** Safari is frontmost with two windows
- **WHEN** the user anchors the thumb, lands two fingers and slides them 5 mm down
- **THEN** the window switcher appears

#### Scenario: Left-hand mode
- **GIVEN** hand mode is Left hand and Safari is frontmost with two windows
- **WHEN** the user anchors the thumb in the top-right corner and slides two fingers down
- **THEN** the window switcher appears

#### Scenario: Fingers first, then thumb
- **WHEN** the user rests two fingers, then anchors the thumb and slides the fingers down
- **THEN** no window switcher appears

#### Scenario: Three fingers
- **WHEN** the user anchors the thumb, lands three fingers and slides them down
- **THEN** no window switcher appears

#### Scenario: A tap that drifts stays a tap
- **GIVEN** the 2-finger gesture is assigned to Mail
- **WHEN** the user anchors the thumb and taps two fingers that drift 2 mm down before lifting
- **THEN** Mail comes to the front and no window switcher appears

### R2. A slide's direction is decided once
The first movement past 3 mm MUST decide whether a slide is sideways (a swipe) or up or down (a window swipe when R13 and R14 allow; otherwise as R16 describes with the setting off). The decision MUST hold until both fingers lift. A window swipe MUST never turn into a swipe, nor a swipe into a window swipe.

#### Scenario: Sideways wobble during a window swipe
- **GIVEN** a window swipe is on, its switcher showing
- **WHEN** the fingers drift 20 mm sideways
- **THEN** the app switcher does not appear and the window switcher stays

#### Scenario: Vertical drift during a swipe
- **GIVEN** a swipe is on, its switcher showing
- **WHEN** the fingers drift 20 mm down
- **THEN** the window switcher does not appear and the app switcher stays

### R3. The window switcher lists the frontmost app's windows
The window switcher MUST list the windows of the frontmost app at the moment the window swipe begins. It MUST list the visible windows front to back, the front window first, then the minimised windows in the order the app lists them, and cut the list at 10. When the front window is full screen, it MUST count as the app's only window, so there is no window swipe (R13). The list MUST be fixed when the window swipe begins: a window that opens during it is not added, and one that closes stays listed.

#### Scenario: Front-to-back order
- **GIVEN** Safari is frontmost, and its windows are, front to back, "Docs", "Mail" and "News"
- **WHEN** the user starts a window swipe
- **THEN** the rows read "Docs", "Mail", "News", top to bottom, and "Docs" is selected

#### Scenario: More than 10 windows
- **GIVEN** the frontmost app has 14 windows
- **WHEN** the user starts a window swipe
- **THEN** the switcher lists the 10 frontmost windows

#### Scenario: Full-screen front window
- **GIVEN** Safari is frontmost, its front window full screen, it has two other windows, and the thumb landed just now
- **WHEN** the user anchors the thumb, slides two fingers down and lifts
- **THEN** no window switcher appears, the page does not scroll, no tap gesture fires and nothing changes

#### Scenario: Window opens during the window swipe
- **GIVEN** a window swipe is on with 2 rows
- **WHEN** the app opens a third window
- **THEN** the switcher still shows 2 rows

### R4. Windows are the app's normal windows on the current Space, plus minimised ones
A *window* MUST be one of the app's normal document or app windows on the current Space, or one of its minimised windows. Panels, palettes, popovers, sheets, toolbars and other floating helpers MUST NOT be listed. Windows on other Spaces and full-screen windows other than the front window MUST NOT be listed. Minimised windows MUST come after the visible ones, shown dimmed with a "Minimised" badge and the app icon in place of a preview.

#### Scenario: Minimised window
- **GIVEN** Finder has two visible windows and one minimised window
- **WHEN** the user starts a window swipe
- **THEN** the switcher shows three rows, the minimised one last, dimmed and badged "Minimised"

#### Scenario: Floating panel left out
- **GIVEN** the frontmost app shows two document windows and a floating colour panel
- **WHEN** the user starts a window swipe
- **THEN** the switcher shows two rows, the document windows, and no row for the panel

#### Scenario: Window on another Space left out
- **GIVEN** Safari is frontmost with two windows on the current Space and one on another Space
- **WHEN** the user starts a window swipe
- **THEN** the switcher shows two rows, and no row for the window on the other Space

### R5. The window switcher sits in the top-left corner of the pointer's display
The window switcher MUST be a Liquid Glass panel in the top-left corner of the display that holds the pointer, just below the menu bar, with a small margin, in both hand modes. It MUST hold one vertical column of rows. When the column would not fit the display's height, the rows MUST shrink by one factor so the whole column fits. It MUST never take focus or receive clicks, and MUST disappear when the window swipe ends.

#### Scenario: Two displays
- **GIVEN** the pointer is on the second display and Safari is frontmost with two windows
- **WHEN** the user starts a window swipe
- **THEN** the switcher appears in the top-left corner of the second display

#### Scenario: Rows shrink to fit
- **GIVEN** the pointer is on a small display, too short for 10 full-size rows
- **WHEN** the user starts a window swipe on an app with 10 windows
- **THEN** all 10 rows show, each shrunk by the same factor, and the column fits the display

#### Scenario: Focus stays put
- **GIVEN** Safari is frontmost with two windows, and a text field in the front window has the keyboard focus
- **WHEN** the user starts a window swipe and lifts without moving the selection
- **THEN** the text field still has the keyboard focus

### R6. Each row shows a preview and a title
Each row MUST show a preview of its window 60 points tall, keeping the window's proportions, at most 120 points wide, with the window's title to its right on one line, truncated at the end. A window with no title MUST show the app's name, followed by " — Window N", N being its position in the list. The selected row MUST carry a glass highlight. Previews MUST show the window as it looked when the window swipe began. A minimised window's row MUST show the app icon in place of a preview. The switcher MUST appear in the same movement that starts the window swipe. Previews MAY fill in afterwards; until a row's preview is ready, that row MUST show the app icon.

#### Scenario: Titled window
- **GIVEN** Screen Recording is allowed, Safari is frontmost with two windows, and one window's title is "Apple Developer"
- **WHEN** the user starts a window swipe
- **THEN** its row shows a small picture of that window and "Apple Developer"

#### Scenario: Untitled windows
- **GIVEN** the frontmost app, Preview, has two windows with no title
- **WHEN** the user starts a window swipe
- **THEN** the rows read "Preview — Window 1" and "Preview — Window 2"

#### Scenario: Long title
- **GIVEN** a window swipe is on with two windows
- **WHEN** a window's title is too long for its row
- **THEN** the title is cut short with an ellipsis at the end

#### Scenario: Window content changes mid-swipe
- **GIVEN** Screen Recording is allowed and a window swipe is on
- **WHEN** a listed window's content changes, such as a page finishing loading
- **THEN** that window's preview still shows it as it looked when the window swipe began

### R7. Without Screen Recording, rows show the app icon instead of a preview
While Trackpad Launcher lacks the Screen Recording permission, each row MUST show the app's icon in place of the preview, with the title unchanged. A window swipe MUST never ask for the permission. Once the permission is granted, the next window swipe after any relaunch macOS requires MUST show previews.

#### Scenario: Permission missing
- **GIVEN** Screen Recording is not allowed
- **WHEN** the user starts a window swipe on Safari with two windows
- **THEN** each row shows the Safari icon and its window's title, and no system prompt appears

#### Scenario: Permission granted later
- **GIVEN** Screen Recording was not allowed, and the user then allows it in System Settings and relaunches Trackpad Launcher if macOS asks to
- **WHEN** the user starts the next window swipe on Safari with two windows
- **THEN** the rows show previews

### R8. The launcher window shows a screen recording hint
While Trackpad Launcher lacks the Screen Recording permission and the window swipe setting is on, the launcher window MUST show a hint saying window previews need Screen Recording. The hint MUST have a button. The first press MUST ask macOS for the permission. Any later press while the permission is still missing MUST open the Screen Recording page of System Settings. The hint MUST disappear once the permission is granted.

#### Scenario: Ask for the permission
- **GIVEN** Screen Recording has never been asked for
- **WHEN** the user opens the launcher window and presses the hint's button
- **THEN** macOS asks whether Trackpad Launcher may record the screen

#### Scenario: Denied earlier
- **GIVEN** the user pressed the hint's button before and did not allow Screen Recording
- **WHEN** the user presses the hint's button again
- **THEN** System Settings opens on the Screen Recording page

#### Scenario: Permission granted
- **GIVEN** the launcher window shows the screen recording hint
- **WHEN** the user allows Screen Recording
- **THEN** the hint disappears

#### Scenario: Setting off hides the hint
- **GIVEN** Screen Recording is not allowed
- **WHEN** the user turns the window swipe setting off
- **THEN** the hint disappears

### R9. The selection follows the fingers
The selection MUST start on the front window, or on the first row when there is no front window (R11). Sliding down MUST move it to the next row, and sliding up back towards the first, in both hand modes. It MUST move one row for every 100 points the cursor would travel for the same finger movement, with macOS's own pointer acceleration at the user's tracking speed, whatever the rows' size on screen. The selected row MUST be the nearest one, so the selection changes halfway to the next row. Travel MUST be counted from the movement that starts the window swipe, so the 3 mm that start it do not count towards the selection, as in the app switcher. The ends MUST be hard stops with a small rubber band that adds no dead zone, as in the app switcher.

#### Scenario: Slide down one row
- **GIVEN** a window swipe on an app with three windows
- **WHEN** the fingers slide down as far as 100 points of cursor travel
- **THEN** the second row is selected

#### Scenario: Turning back at the end
- **GIVEN** a window swipe on an app with two windows, the second selected
- **WHEN** the fingers slide further down, then turn back up
- **THEN** the selection returns to the first row after half a row of travel up, not more

### R10. The selected window comes to the front while sliding
Each time the selection moves to a visible window, that window MUST come to the front at once, above the app's other windows, and get the keyboard focus, while the switcher stays on top. Selecting a minimised window MUST NOT restore it while sliding. Selecting a window that has closed MUST change nothing on screen. Moving the selection back to the first row MUST bring the front window back to the front. When there is no front window, sliding back to the first row MUST change nothing on screen.

#### Scenario: Live switch
- **GIVEN** Safari's windows are "Docs", then "Mail"
- **WHEN** the user starts a window swipe and slides down one row
- **THEN** "Mail" is in front at full size, behind the switcher, before the fingers lift

#### Scenario: Slide back
- **GIVEN** the user has slid from "Docs" down to "Mail"
- **WHEN** the user slides back up to "Docs"
- **THEN** "Docs" is in front again

#### Scenario: Passing a minimised window
- **GIVEN** the third row is a minimised window
- **WHEN** the user slides onto it
- **THEN** it stays minimised and the window in front does not change

### R11. Lifting keeps the selected window in front
When both fingers lift, the selected window MUST be in front and have the keyboard focus. A selected minimised window MUST be restored and brought to the front. The windows MUST then be ordered: the selected window, then the front window, then the others in their order from before the window swipe. When every listed window is minimised there is no front window: the selection MUST start on the first row, and lifting on any row MUST restore that window and bring it to the front with the gesture haptic. Lifting on the front window MUST change nothing and be silent. Lifting on a window that has closed MUST leave the windows as they are at that moment, with no reordering, and follows R12 for the haptic.

#### Scenario: Toggle between the last two windows
- **GIVEN** Safari's windows are, front to back, "Docs", "Mail", "News"
- **WHEN** the user slides down to "News" and lifts, then starts another window swipe
- **THEN** the rows read "News", "Docs", "Mail", and typing goes to "News"

#### Scenario: Every window minimised
- **GIVEN** Finder is frontmost with only two windows, both minimised
- **WHEN** the user starts a window swipe and lifts without leaving the first row
- **THEN** the first window is restored and in front, and the trackpad gives the gesture haptic

#### Scenario: Lift on a minimised window
- **GIVEN** the third row is a minimised window
- **WHEN** the user lifts on it
- **THEN** the window is restored and in front

#### Scenario: Lift on the front window
- **GIVEN** Safari is frontmost with two windows
- **WHEN** the user starts a window swipe and lifts without leaving the first row
- **THEN** nothing changes and no haptic plays

#### Scenario: Selected window closes
- **GIVEN** Safari's front window was "Docs" and the user has slid onto "Mail"
- **WHEN** "Mail" closes, then the user lifts
- **THEN** the windows stay as they are at that moment, with no reordering, and the gesture haptic plays only if the window now in front is not "Docs"

### R12. Feedback follows the app switcher's rules
Each change of the selection MUST give one light tick. A lift MUST give the gesture haptic if, and only if, the window in front after the lift differs from the front window at the start of the window swipe, or a minimised window was restored. Otherwise the lift MUST be silent. The window swipe MUST never play the launch animation.

#### Scenario: Ticks while sliding
- **GIVEN** Safari is frontmost with three windows
- **WHEN** the user slides down across two rows
- **THEN** the trackpad gives two light ticks

#### Scenario: Lift on another window
- **GIVEN** Safari is frontmost with two windows
- **WHEN** the user slides down one row and lifts
- **THEN** the trackpad gives the gesture haptic and no launch animation plays

### R13. Fewer than two windows means no window swipe
When the frontmost app has fewer than two windows (R4) at the moment a slide's direction is decided, or there is no frontmost app (as the glossary defines it, such as while Trackpad Launcher itself is active), the slide MUST NOT be a window swipe. A switcher MUST NOT appear and a haptic MUST NOT play. The slide MUST then behave exactly as it does with the window swipe setting off (R16): it scrolls once the blocking window has passed, and it never becomes a swipe, since its first movement was up or down. The count MUST be fixed when the direction is decided: a window that opens later in the slide does not start a window swipe, and a window that closes during a window swipe does not end it.

#### Scenario: One window
- **GIVEN** TextEdit is frontmost with one window, and the thumb landed just now
- **WHEN** the user anchors the thumb, slides two fingers down and lifts
- **THEN** no switcher appears, no haptic plays, the page does not scroll, no tap gesture fires and nothing changes

#### Scenario: No windows
- **GIVEN** Finder is frontmost with no windows open
- **WHEN** the user anchors the thumb and slides two fingers down
- **THEN** no switcher appears

#### Scenario: One visible and one minimised window
- **GIVEN** Finder is frontmost with one visible and one minimised window
- **WHEN** the user anchors the thumb and slides two fingers down
- **THEN** the window switcher appears with two rows

#### Scenario: Only window minimised
- **GIVEN** Finder is frontmost with only one window, and it is minimised
- **WHEN** the user anchors the thumb and slides two fingers down
- **THEN** no switcher appears

#### Scenario: Sideways after down stays no swipe
- **GIVEN** TextEdit is frontmost with one window and the swipe setting is on
- **WHEN** the user slides two fingers 5 mm down, then 20 mm sideways
- **THEN** neither the app switcher nor the window switcher appears

#### Scenario: One window scrolls after the blocking window
- **GIVEN** TextEdit is frontmost with one long document window, and the thumb landed more than 3 seconds ago
- **WHEN** the user slides two fingers down
- **THEN** the document scrolls

#### Scenario: Window opens mid-slide
- **GIVEN** TextEdit is frontmost with one window, and the user is sliding two fingers down with no switcher showing
- **WHEN** TextEdit opens a second window while the fingers keep sliding
- **THEN** no switcher appears until the fingers lift

### R14. Without Accessibility, there is no window swipe
While Trackpad Launcher lacks the Accessibility permission, a slide up or down MUST NOT be a window swipe, as in R13. The launcher window's existing Accessibility hint MUST also say that switching windows needs the permission.

#### Scenario: Accessibility missing
- **GIVEN** Trackpad Launcher lacks the Accessibility permission and Safari is frontmost with two windows
- **WHEN** the user anchors the thumb and slides two fingers down
- **THEN** no switcher appears

#### Scenario: Accessibility granted later
- **GIVEN** Trackpad Launcher lacked the Accessibility permission, and the user then allows it in System Settings
- **WHEN** the user next slides two fingers down under an anchored thumb on Safari with two windows
- **THEN** the window switcher appears

#### Scenario: The hint names window switching
- **GIVEN** Trackpad Launcher lacks the Accessibility permission
- **WHEN** the user opens the launcher window
- **THEN** the Accessibility hint says switching windows needs the permission

### R15. Clicks, scrolling and system swipes stay blocked during a window swipe
Click blocking MUST apply for the whole of a window swipe, as for a swipe: clicks, scrolling and the system's trackpad swipes are blocked, and the blocking window is held open until both fingers lift. A window swipe MUST end when both fingers lift, and a finger that loses contact and lands again while the other finger is still down, as in a swipe, MUST rejoin it. The thumb lifting during a window swipe MUST change nothing: the switcher stays and the selection keeps following the fingers. It MUST be cancelled when a third finger lands outside the anchor corner while both are down, or a click reaches apps; a cancelled window swipe MUST keep the window in front as it is at that moment, without the lift's reordering, and be silent.

#### Scenario: No scroll under a window swipe
- **GIVEN** Trackpad Launcher has the Accessibility permission, Safari is frontmost with two windows, and the pointer is over a scrollable page
- **WHEN** the user window-swipes down
- **THEN** the page does not scroll

#### Scenario: Third finger cancels
- **GIVEN** Safari is frontmost with two windows
- **WHEN** a third finger lands outside the anchor corner during a window swipe
- **THEN** the switcher disappears, no haptic plays, and nothing more happens until every finger has lifted

#### Scenario: Thumb lifts mid-swipe
- **GIVEN** a window swipe is on, its switcher showing
- **WHEN** the thumb lifts and the fingers keep sliding down
- **THEN** the switcher stays and the selection keeps following the fingers

#### Scenario: Finger rejoins
- **GIVEN** a window swipe is on with the second row selected
- **WHEN** one finger loses contact and lands again while the other is still down
- **THEN** the switcher stays and the window swipe carries on

#### Scenario: Click reaching apps cancels
- **GIVEN** a window swipe is on with the second row selected, so "Mail" is in front
- **WHEN** a click reaches apps
- **THEN** the switcher disappears, "Mail" stays in front without the lift's reordering, and no haptic plays

### R16. The window swipe setting turns it on and off
The *Swipe up or down to switch windows* switch MUST sit in the launcher window's switcher section, below *Thumb tap to swap apps*, and be on by default. While it is off there MUST be no window swipe: two fingers sliding up or down under an anchored thumb scroll once the blocking window has passed, as today, and a slide's direction rules MUST be exactly today's, with no change to the swipe. It MUST be independent of the swipe and swap settings. A change MUST apply to the next slide and be saved at once, so it survives a quit, a force-quit or a Mac restart. Upgrading from a version without the setting MUST leave it on and change no other setting.

#### Scenario: Setting off
- **GIVEN** the window swipe setting is off
- **WHEN** the user anchors the thumb and slides two fingers down, after the blocking window has passed
- **THEN** no switcher appears and the page under the pointer scrolls

#### Scenario: Swipe setting off, window swipe on
- **GIVEN** the swipe setting is off, the window swipe setting is on, and Safari is frontmost with two windows
- **WHEN** the user anchors the thumb and slides two fingers down
- **THEN** the window switcher appears

#### Scenario: Survives a restart
- **GIVEN** the user turned the window swipe setting off
- **WHEN** the Mac restarts
- **THEN** the switch is still off

#### Scenario: Upgrade with the swipe setting off
- **GIVEN** a user upgrades with the swipe setting off
- **WHEN** they open the launcher window
- **THEN** the window swipe switch is on and the swipe switch is still off

### R17. Previews stay private
Window previews MUST be captured only while a window swipe begins, MUST be kept only in memory, and MUST be discarded when the window swipe ends. They MUST never be written to disk.

#### Scenario: Nothing kept after the window swipe (checked in code review)
- **WHEN** a window swipe ends
- **THEN** no preview of any window remains held by Trackpad Launcher, and none was ever written to disk

## Non-goals

- **Windows on other Spaces and full-screen windows other than the front window.** Reaching them makes macOS switch Spaces, and macOS does not reliably reveal them. Deferred.
- **Windows of other apps.** The window swipe stays within the frontmost app; the swipe reaches other apps.
- **Live-updating previews.** A picture from the moment the window swipe begins is enough to recognise a window, and costs far less.
- **Restoring minimised windows while sliding.** The minimise animation is slow; restoring and re-minimising as the fingers pass would look broken.
- **Closing or minimising windows from the switcher.** The switcher only picks a window.
- **Final visual and motion design.** This version uses a best-judgement look and motion; refining it together comes later.
- **Mirroring the switcher to the top-right corner in left-hand mode.** The user asked for top-left.
- **Hidden apps.** The window swipe works on the frontmost app, which is never hidden.
- **Previews of minimised windows.** macOS keeps no current picture of them; their rows show the app icon.
- **Sound effect.** Deferred, as for every gesture.
- **An app whose only window is minimised.** One window is nothing to switch between; the Dock restores it.

## Design

### Problem

The window swipe is a sibling of the swipe, not a second feature beside it. Two fingers under an anchored thumb already
run through one recognizer, one finger session, one blocking rule, one event hop and one model handler, and today a
first drag past 3 mm that is not strictly sideways spoils the pair. The shape is not obvious because the window swipe
brings several firsts: the first effect on the system while the fingers still move (raising windows changes the state
the lift then acts on), the first use of the `AXUIElement` family and of a private window API
(`_AXUIElementGetWindow`), the first second permission (Screen Recording), and the first pictures of other apps'
windows, which arrive after the window swipe began and must go when it ends.

The grounding fixes these constraints, and the design honours each:
- One recognizer and one `.swiping` state; the direction is decided once, in `beginOrSpoil` (`why.md` Preserve 1, 3;
  Avoid 1, 2). Change 1 overturns the original "the recognizer never learns whether the app has windows": a slide up
  or down is a window swipe only when the frontmost app has two or more windows (R13) and Accessibility is granted
  (R14), and otherwise must be exactly the slide the window swipe setting off makes. Only the main actor can read
  windows, so the recognizer learns the verdict as the model's answer to the start, before its next frame.
- Travel crosses the port as one scalar in step millimetres, through the pointer curve installed at begin; 100 cursor
  points make a row (Preserve 4; R9).
- The list is fixed at begin; the system is read at begin and again at the lift; a window closed mid-swipe is the
  analogue of an app that quit; the lift must not depend on what the raises while sliding did (Preserve 5; Risk 4).
- `LauncherCore` imports Foundation and Observation only; framework types (`AXUIElement`, `CGImage`, `NSImage`) never
  cross a port; every port has exactly two adapters; `LauncherUI` cannot see `LauncherPlatform`
  (`docs/architecture.md` Shape; F32, F33).
- A shell asset the model never decides on stays in the shell: plan 008 put icon readiness there because routing it
  through the model "would add state the model never decides on" (`why.md` Q4).
- No timers, no polling: the TCC broadcast, user events and frames are the pushes; `notify_register` is confined to
  one file, and the broadcast names no service (F29, F34).
- AX calls are synchronous IPC bounded by a messaging timeout, set process-wide on the system-wide element (F15,
  `AXUIElement.h`); `AXRaise` fronts, focuses and restores a minimised window (F19, F20); raising back to front
  re-stacks exactly (F22); raising a window on another Space switches Spaces (F24); a closed window answers `-25202`
  (F14); a minimised window's subrole is unreliable (F9); a full-screen front window stands alone on its Space (F10);
  only ScreenCaptureKit can capture (F25); a Screen Recording preflight costs about 4 ms on the calling thread
  (check-1).

### Usage (caller's view)

**README for the next maintainer.** A slide is a *swipe* (more sideways) or a slide up or down (more up or down). The
recognizer decides which on the frame the farthest-moved finger passes 3 mm and holds that until both fingers lift. A
slide up or down is reported as `.windowSwipe(.began)` through the same hop as the swipe's phases, but it is a *window
swipe* only once the model confirms it: `Launcher.windowSwipe(_:)`, the one place a window swipe becomes effects, reads
the frontmost app's windows with `system.frontmostWindows()`, beside `runningApps()` on `SystemActions`, and calls
`hardware.confirmWindowSwipe(on:)` only when the read makes a `WindowSwitcher.Content` (two or more rows). Whatever the
model did, the adapter answers the start once `onEvent` returns, and the recognizer takes the answer before its next
frame: confirmed, the slide blocks until both fingers lift; declined, it becomes the slide the window swipe setting off
would have made. Without Accessibility the recognizers run without the window swipe at all. The confirmed window
swipe's `WindowSwitcher` value has content fixed for the window swipe. Each selection change onto a visible window is
`system.raiseWindows([window])`, beside `bringToFront`. The lift reads the windows again and asks the value for a
`WindowLift`, a pure plan of which windows to raise and whether to pulse. The selection maths is the app switcher's,
extracted into `SwitcherSelection`. The shell draws `launcher.windowSwitcher`. Previews are a shell asset, like icons:
the model says whether rows show previews and which windows; the window switcher's presenter captures those windows
once per window swipe and holds the pictures only while that window switcher is on screen. Both permissions sit behind
one `Permissions` port that owns the one TCC broadcast.

**Call site 1: the model (`Launcher`, `LauncherCore`).**

```swift
/// The one place a window swipe becomes effects.
private func windowSwipe(_ event: SwipeEvent) {
    switch event.phase {
    case .began:
        // A slide up or down is a window swipe only when the one read lists two or more rows (R1, R13). Unconfirmed,
        // the recognizer makes it the slide the setting off would have made, before its next frame.
        guard activity.isActive, let content = WindowSwitcher.Content(system.frontmostWindows()) else { return }
        hardware.confirmWindowSwipe(on: event.trackpad)
        // One switcher at a time: a second trackpad's window swipe runs its course with none, as its swipe would.
        guard shown == nil else { return }
        windowSwipesBegun += 1
        // The grant as the last TCC push left it (R7): a fresh preflight would cost about 4 ms here.
        shown = .windows(WindowSwitcher(
            content, showsPreviews: isScreenRecordingGranted, serial: windowSwipesBegun, trackpad: event.trackpad))
    case .moved(let travel):
        guard case .windows(var open)? = shown, open.trackpad == event.trackpad else { return }
        let crossed = open.selection.follow(travel)
        shown = .windows(open)
        for _ in 0..<crossed { hardware.playFeedback(.lightTick, on: event.trackpad) }
        // Only a visible window comes forward while sliding: raising a minimised one would restore it (R10).
        if crossed > 0, let window = open.selectedVisibleWindow { system.raiseWindows([window]) }
    case .ended:
        guard case .windows(let open)? = shown, open.trackpad == event.trackpad else { return }
        shown = nil
        // The second read: the plan follows the windows as they are now, whatever the raises while sliding did.
        let lift = open.lift(now: system.frontmostWindows())
        if lift.playsHaptic {
            hardware.playFeedback(.gesture, on: event.trackpad)
            window = .closed
        }
        system.raiseWindows(lift.raises)
    case .cancelled:
        // The windows stay as they are: no reordering, silent (R15).
        if case .windows(let open)? = shown, open.trackpad == event.trackpad { shown = nil }
    }
}
```

**Call site 2: the shell (`WindowSwitcherPresenter`, `LauncherUI`), the app switcher's presenter pattern.**

```swift
for await shown in Observations({ launcher.windowSwitcher }) { render(shown) }

private func render(_ switcher: WindowSwitcher?) {
    guard let switcher else {
        capture?.cancel()
        shownSerial = nil
        panel.dismiss()                                   // fades, then `emptied()` drops every picture (R17)
        return
    }
    if switcher.serial != shownSerial { open(switcher) }  // one layout and one capture per window swipe
    panel.show(position: switcher.selection.position, selected: switcher.selection.selected)
    if switcher.selection.stretch != lastStretch, switcher.selection.stretch != 0, !reduceMotion {
        panel.springHighlight(fromY: switcher.selection.stretch * layout.pitch)
    }
    lastStretch = switcher.selection.stretch
}

private func open(_ switcher: WindowSwitcher) {
    let screen = Displays.screen(under: NSEvent.mouseLocation)
    let visible = screen?.visibleFrame ?? .zero
    let scale = screen?.backingScaleFactor ?? 2
    layout = WindowColumnLayout(
        rowCount: switcher.rows.count, widestTitle: panel.widestTitle(switcher.rows), displayHeight: visible.height)
    panel.lay(out: switcher.rows, icon: icons.icon(forSwitcher: switcher.app), layout: layout,
              topLeft: NSPoint(x: visible.minX + WindowColumnLayout.margin, y: visible.maxY - WindowColumnLayout.margin))
    shownSerial = switcher.serial
    lastStretch = 0
    panel.present(animated: !reduceMotion)
    capture?.cancel()
    guard !switcher.previewWindows.isEmpty else { return }
    let serial = switcher.serial, rows = switcher.rows, pixels = layout.previewPixels(scale: Double(scale))
    capture = Task { [weak self] in
        for await (window, picture) in PreviewCapture.pictures(of: switcher.previewWindows, fitting: pixels) {
            guard let self, shownSerial == serial, let row = rows.firstIndex(where: { $0.window == window }) else { return }
            panel.setPreview(picture, row: row, animated: !reduceMotion)
        }
    }
}
```

**Call site 3: tests at the high seam (`World`).** `RecordingSystemActions.windows` is a small window stack that
behaves the way `AXRaise` does: a raised window moves to the front, and a raised minimised window is restored.

```swift
@Test func liftingOnNewsStacksNewsThenTheFrontWindowThenTheRest() {
    let world = World.windowWorld(visible: ["Docs", "Mail", "News"])
    let first = world.windowSwipe(3.5, 24)                       // begin, two rows down, lift
    #expect(world.system.windows.onScreenTitles == ["News", "Docs", "Mail"])
    #expect(world.hardware.lightTicks.count == 2)
    #expect(world.hardware.feedback == [Trackpad.macBook14.id])
    #expect(world.system.launchAnimations.isEmpty)
    world.play(first.land(fingers: 2).slide(byMM: (0, 3.5)))     // the next window swipe, under the same thumb
    #expect(world.launcher.windowSwitcher?.rows.map(\.title) == ["News", "Docs", "Mail"])
}

@Test func aSelectedWindowThatClosesLeavesTheWindowsAsTheyAre() {
    let world = World.windowWorld(visible: ["Docs", "Mail", "News"])
    let hand = world.windowSwipe(3.5, 12, lift: false)
    #expect(world.system.windows.onScreenTitles == ["Mail", "Docs", "News"])
    world.system.windows.close("Mail")                           // Docs is in front again
    world.play(hand.lift())
    #expect(world.system.windows.onScreenTitles == ["Docs", "News"])
    #expect(world.hardware.feedback.isEmpty)
}

@Test func withoutScreenRecordingNoRowAsksForAPreviewAndNothingPrompts() {
    let world = World.windowWorld(visible: ["Docs", "Mail"], minimised: ["Notes"], screenRecording: false)
    let lifted = world.windowSwipe(3.5, lift: false).lift()
    #expect(world.launcher.windowSwitcher?.previewWindows.isEmpty == true)
    world.play(lifted)
    #expect(world.permissions.asks.isEmpty)
    world.permissions.set(.screenRecording, granted: true)       // the TCC push
    world.play(lifted.land(fingers: 2).slide(byMM: (0, 3.5)))
    #expect(world.launcher.windowSwitcher?.previewWindows == [world.window("Docs"), world.window("Mail")])
}
```

**Call site 4: the launcher window (`LauncherUI` views).**

```swift
// SwitcherSection, the third row:
SettingRow(illustration: "window-swipe", title: "Swipe up or down to switch windows",
           isOn: Binding(get: { launcher.isWindowSwipeOn }, set: { launcher.setWindowSwipe(on: $0) }))
// LauncherView, after the Accessibility hint:
if let hint = launcher.screenRecordingHint {
    SettingsNotice(message: Copy.screenRecordingHint, button: Copy.screenRecordingButton(hint)) {
        switch hint {
        case .ask: launcher.askForScreenRecording()
        case .openSettings: actions.openSettings(.screenRecording)
        }
    }
}
```

**Call site 5: the recognizer over scripted frames.**

```swift
@Test(arguments: [(HandMode.right, 10.0), (.left, 114.8)])
func twoFingersSlidingDownPastThreeMillimetresBeginAWindowSwipe(hand: HandMode, thumbX: Double) {
    let frames = TouchScript(.macBook14).thumb(atMM: (thumbX, 10)).land(fingers: 2).slide(byMM: (0, 5)).lift().frames
    #expect(windowPhases(frames, handMode: hand).first == .began)
    #expect(windowPhases(frames, handMode: hand).last == .ended)
    #expect(phases(frames, handMode: hand).isEmpty)
}
```

### Shape

**Data first.** One read of the system, `FrontmostWindows` (the app; its visible windows on the current Space, front
to back; its minimised windows in the app's order), is parsed once at the model's edge into
`WindowSwitcher.Content`: the app and a `WindowList` (`.front(…)` or `.minimisedOnly(…)`) of two to ten windows. The
parse is failable, and its nil is the whole of R13: no frontmost app, or fewer than two rows, so the slide is no window
swipe. Everything else derives from that fixed value: whether the start is confirmed, the rows the presenter draws, the
window a move raises (`selectedVisibleWindow`), the front window (`frontWindow`), the windows the presenter captures
(`previewWindows`), and, given the second read, the lift (`lift(now:)`). Every dominant access reads the one value;
nothing needs an index or a cache.

**Load-bearing decisions.**

- **One recognizer state, kind fixed at begin** (per model-the-domain). `beginOrSpoil` stays the single place a
  slide's direction is decided: `Move.slide` is strict both ways, so a tie spoils, as today; `slides: Set<SlideKind>`
  replaces `swipes: Bool`; `Swipe.kind` is a `let`. `.swiping` is unchanged, so blocking, rejoin, thumb, cancel and end
  apply to both kinds by construction (R15). A pair and `.resting` exist while any kind is on (R16: swipe off with the
  window swipe on); with only one kind on, the other axis spoils exactly as today.
- **A window swipe's start is a question the model answers before the next frame** (change 1; per
  separate-before-serializing-shared-state). Whether a slide up or down is a window swipe depends on the frontmost app's
  windows, which only the main actor reads, while the slide's blocking is decided frame by frame on the frame thread.
  So `beginOrSpoil` still begins a `.swiping` slide for `.windowSwipe` and reports `.windowSwipe(.began)`, but the
  `Swipe` is born unconfirmed: its phases are reported as usual, and it blocks only by the thumb rules, exactly what the
  spoiled slide of the setting off would block on that frame. `GestureRecognizer.answerWindowSwipe(began:isWindowSwipe:)`
  settles it: true confirms it, and from the next frame it blocks like any `.swiping` slide; false turns the state into
  the one `beginOrSpoil` returns with the setting off, `.spoiled` under the slide's thumb, or, once that thumb has gone,
  a rest of every contact down, as the spoiled state's own exit (`restOrIdle`) gives, a thumb that rolled out of the
  corner included. The answer names its start by the frame time it began on, so an answer to an earlier start, one
  after its slide ended and a second answer change nothing. A swipe is born confirmed. On the port, the model calls
  `TrackpadHardware.confirmWindowSwipe(on:)` while it handles the start, and the adapter replies to every start it
  delivers once `onEvent` returns, true only if confirmed: an answer is never forgotten, and nothing but the start's own
  handling can confirm it. That main-actor bookkeeping lives once, in `WindowSwipeConfirmation` in `LauncherCore`, as
  `TrackpadEvent.init(_:on:)` and `TouchFrame.Press.init(holding:buttonDown:)` do for rules both adapters share: each
  adapter hands every event to `onEvent` through it and forwards `confirmWindowSwipe(on:)` to it, so every World row
  runs the same rule the hardware does. The real adapter's `DeviceSession` delivers each start with a reply that writes
  `(began, isWindowSwipe)` into a slot only the main actor writes; its frame callback hands the slot to the recognizer
  before stepping each frame. The answer normally lands between the start frame and the next, so a declined slide is,
  from the next frame on, the very state the setting off would have reached; if the main actor is busy the slide waits,
  unconfirmed, on the frames that keep arriving. No timer, no poll.
- **Without Accessibility there is no window swipe to recognise** (change 1, R14). The model runs the recognizers
  with `settings.slides` minus `.windowSwipe` while the permission is missing, so a slide up or down spoils on the frame
  it passes 3 mm, nothing is read, and nothing hops. A grant already re-runs the trackpads (click blocking follows it),
  so the window swipe returns with the next slide.
- **Phases by kind, same hop** (per type-system-discipline). `Recognition.Event.windowSwipe` and
  `TrackpadEvent.windowSwipe` are new cases, so the compiler routes a window swipe to its own handler and the tests'
  existing `.swipe(...)` phases and injections are untouched; only the frame thread's per-begin travel hook widens, to
  `Recognition.beginsSlide`. The hop, the generation check and `TrackpadEvent.init` are the same code; change 1 adds
  only the reply that follows a window swipe's start back to its session.
- **Travel along the slide.** `PointerCurve.cursorMove` returns both components, scaled by the one speed-dependent
  multiplier; `SwipeTravel.travel(along:)` picks the component. One step is 100 cursor points on either axis: the app
  switcher's icon pitch and R9's row.
- **One selection rule.** `SwitcherSelection` is the app switcher's maths moved out of `Switcher` unchanged and shared
  by both switchers; `follow` returns the items crossed, which is the tick count.
- **At most one switcher.** The model stores `shown: ShownSwitcher?` (`.apps` or `.windows`) and derives `switcher` and
  `windowSwitcher`; `reconcile` clears both with one write (per encode-lessons-in-structure).
- **Content as a construction, not flags** (per type-system-discipline). The front window exists only in `.front`; the
  all-minimised case is its own variant; a content exists only with two or more windows, so the switcher has no message
  rows and every row names a window. The rules live in the one parse: a full-screen front window alone (one row, so no
  content), other full-screen windows left out, visible before minimised, the cut at 10, and nil below two rows (per
  boundary-discipline). The model's confirmation and the switcher's rows come from the same parse of the same read, so
  the count that decides is the count the user sees (R1).
- **The lift is a pure plan from a second read** (per make-operations-idempotent; Risk 4). `lift(now:)` takes the
  windows as they are at the lift and returns which to raise and whether to pulse, so it never depends on what the
  raises while sliding did. The target is the selected window, then the visible windows in their begin order (the
  front window first), minus any that closed; `WindowStack.raises` gives the shortest front part of it that, raised
  back to front, leaves that order (F22): empty when the order already holds, so a lift on the front window that slid
  nowhere raises nothing (R5's focus scenario) and one that slid away and back restores the order. A selected window
  that closed raises nothing; another app in front at the lift raises nothing and is silent. Every R11 and R12 rule is
  in this one pure function; the adapters only raise.
- **Window reads and raises beside their pairs on `SystemActions`** (`why.md` Preserve 7; no new port).
  `frontmostWindows()` sits beside `runningApps()` and `raiseWindows(_:)` beside `bringToFront(_:)`; the real work
  lives in one small platform type, `FrontmostAppWindows`, which `WorkspaceActions` creates once and delegates to, as
  it does `RunningAppsReader`. It holds no window, so its tests construct it alone, and its pure `sort` and
  `number(of:among:)` let them check R4's filter and R3's order without the Accessibility permission.
- **One TCC module.** The `Permissions` port replaces `AccessibilityPermission` and owns both permissions and the one
  `notify_register`; each broadcast re-reads both, and `onChange` runs when either changed (F29; per
  separate-before-serializing-shared-state: one writer of the registration). The R8 hint derives from three facts: the
  setting, the grant, and the persisted `hasAskedForScreenRecording`.
- **Previews are rendered assets, not model state** (per minimize-reader-load; plan 008's icon precedent). No decision
  reads a picture. The model decides whether rows show previews (R7: the grant at begin) and which windows (the visible
  rows, R4). The presenter captures exactly `previewWindows` once per `serial`, so the pictures' lifetime derives from
  the observed value and every exit (lift, cancel, reconcile) discards them by construction: the capture task is
  cancelled at nil, each arrival is checked against the shown serial, and the panel empties its layers once it is out
  (R17). The capture runs only when the model says previews show, and the source policy bans streams, recordings and
  every image encoder.
- **Window identity is the window server's number.** `WindowID` brands the one number AX (`_AXUIElementGetWindow`),
  the window list and ScreenCaptureKit share, stable across the begin and lift reads. It is what lets the shell capture
  with no image channel through the core; the AX handle stays in the adapter.

**Interface depth.** `SystemActions` gains two methods. Behind them: the frontmost pid; AX IPC under a 0.2 s process-wide
messaging timeout, with no further raises to an app after its first timeout; the private window number and its
frame-matching fallback; the current-Space test by the on-screen window list; subrole filtering for visible windows
only (F9); the full-screen flag; closed-element errors; focus; restore by raise. `Permissions` is three members over AX
trust, screen-capture access, both prompts and the shared broadcast. `WindowSwitcher` hides row derivation, naming, the
cut, the two-row threshold, the lift plan and the haptic rule behind a failable parse, reads, `follow` and
`lift(now:)`. `TrackpadHardware` gains one method, `confirmWindowSwipe(on:)`; behind it, `WindowSwipeConfirmation`'s
one rule for when a confirmation counts, the reply each start carries, the answer slot, and the hand-over before the
next frame. The recognizer gains one, `answerWindowSwipe(began:isWindowSwipe:)`;
behind it, the unconfirmed slide's thumb-rule blocking, the stale-answer rule and the conversion to the setting-off
state. The model's public surface grows by `windowSwitcher`, `isWindowSwipeOn` / `setWindowSwipe(on:)` and
`screenRecordingHint` / `askForScreenRecording()`; the grant stays private because the hint and `showsPreviews` carry
it.

**Deliberately not done.** No main-to-frame channel beyond the one answer per window swipe start. No window read on
the frame thread. No window state in the model between window swipes. No restore
while sliding. No raise of an unlisted window. No prompt from a gesture. No live previews, no stream. No attribute
writes: closing, minimising and moving windows are banned by the source policy. No change to the gesture hint text.

#### Module map

| Module | New or changed |
|---|---|
| LauncherCore | `SlideKind`; `GestureRecognizer` (`slides`, `beginOrSpoil`, `Swipe.kind`); `Recognition.Event.windowSwipe`, `Recognition.windowSwipe`, `beginsSlide`; `PointerCurve.cursorMove` (replaces `cursorPoints`), `SwipeTravel.travel(along:)`, `pointsPerStep`; `SwitcherSelection` (new), `Switcher` holds one; `WindowID`, `AppWindow`, `FrontmostWindows`, `WindowStack` (new); `WindowSwitcher`, `WindowLift` (new); `WindowColumnLayout` (new); ports: `SystemActions` +2, `Permission` / `Permissions` (replaces `AccessibilityPermission`), `TrackpadEvent.windowSwipe`, `TrackpadHardware.run(slides:)`; `Settings.isWindowSwipeOn`, `.hasAskedForScreenRecording`, `.slides`; `ScreenRecordingHint`; `Copy` strings; `GestureRules.windowSwitcherMaxRows`; `Launcher` (`shown`, `windowSwipe(_:)`, setters, hint, both grants); the stale `SwipePhase`, `Switcher` and `switcherMaxOvershoot` comments fixed |
| LauncherPlatform | `FrontmostAppWindows` (new, the window read and raise, with its pure `sort` and `number(of:among:)` seams); `WorkspaceActions` delegates the two window methods to it; `SystemPermissions` (was `SystemAccessibilityPermission`); `DeviceSession.receive` installs travel on `beginsSlide`; `MultitouchTrackpads.run(slides:)`; `CursorTravel` and `LaunchTuning` use `pointsPerStep` |
| LauncherUI | `OverlayPanel` (new base for both switcher panels), `Displays.screen(under:)` (moved out of `SwitcherPresenter`); `WindowSwitcherPanel`, `WindowSwitcherPresenter`, `WindowSwitcherLook`, `PreviewCapture` (new); `SwitcherPanel` and `SwitcherPresenter` adopt the base and read `selection`; `SwitcherSection` third row through `SettingRow`; `LauncherView` hint; `SettingsPane.screenRecording`; `MenuBarShell` builds the presenter and adds `screenRecordingHint` to the refit observation |
| App target | `SystemPermissions()` in place of `SystemAccessibilityPermission()`; `assets/window-swipe.svg` |
| Tests | `RecordingSystemActions.windows` (a `FakeWindows` stack), `InMemoryPermissions` (replaces `InMemoryAccessibilityPermission`); `World` (`permissions`, `windowWorld`, `windowSwipe`, `window(_:)`); the `windowPhases` driver; `slides:` at every recognizer construction site; `TouchScript.tap(dragMM:)` takes `(x, y)`; source policy rows |
| Change 1, LauncherCore | `GestureRecognizer.answerWindowSwipe(began:isWindowSwipe:)`; `Swipe.began`, `Swipe.isConfirmed`; an unconfirmed `.swiping` blocks by the thumb rules; `TrackpadHardware.confirmWindowSwipe(on:)`; `WindowSwipeConfirmation` (new, the adapters' shared main-actor half of the answer); `WindowSwitcher.Content` becomes a struct (`app`, `windows`) with a failable parse; `Row` loses `.message`, `window` and `app` stop being optional, `listsWindows` goes; `Copy.untitledWindow(of:position:)`; `Copy.noOpenWindows` and `Copy.accessibilityForWindows` go; `Copy.accessibilityHint` names switching windows; `Launcher.windowSwipe(_:)` confirms only a content and lifts every shown switcher; `reconcile` runs without `.windowSwipe` while Accessibility is missing |
| Change 1, LauncherPlatform | `DeviceSession`: each window swipe start delivered with a reply; the answer slot (writer: main), handed to the recognizer before each step; `MultitouchTrackpads`: hands every event through a `WindowSwipeConfirmation`, calls a start's reply with its answer, and forwards `confirmWindowSwipe(on:)` to it |
| Change 1, LauncherUI | `WindowSwitcherPresenter` and `WindowSwitcherPanel` take the non-optional app and window |
| Change 1, Tests | `InMemoryTrackpads` hands every event through a `WindowSwipeConfirmation`, answers each start between frames and logs it in `windowSwipeAnswers`; the recognizer drivers take `answering: Bool?` (default true: every start confirmed before the next frame; nil: never answered); `DeviceSession` test helpers take the reply |

#### Core types and signatures

```swift
// MARK: Recognition

/// What two fingers sliding under an anchored thumb start. Decided once, on the frame the farthest-moved finger passes
/// 3 mm, and held until both fingers lift.
public enum SlideKind: Hashable, Sendable {
    /// More sideways than up or down: the app switcher. Travel is positive to the right in both hand modes.
    case swipe
    /// More up or down than sideways: the window switcher. Travel is positive downwards in both hand modes.
    case windowSwipe
}

/// A swipe's or a window swipe's progress; the event case says which. (Replaces the three stale comments.)
public enum SwipePhase: Equatable, Sendable {
    /// One of two fingers under an anchored thumb moved past 3 mm. Travel is 0 here: the 3 mm do not count. A window
    /// swipe's start is a question: it is a window swipe only if the model confirms it while handling this phase
    /// (`TrackpadHardware.confirmWindowSwipe(on:)`).
    case began
    /// Travel along the slide since `began`, in step millimetres (12 per item), absolute. Sent only when it changed.
    case moved(travelMM: Double)
    /// Both fingers have lifted.
    case ended
    /// A third finger landed outside the anchor corner while both were down, or a click reached apps.
    case cancelled
}

extension Recognition.Event {
    // New case beside .fired, .swipe and .swap:
    //     case windowSwipe(SwipePhase)
    static func slide(_ kind: SlideKind, _ phase: SwipePhase) -> Self {
        kind == .swipe ? .swipe(phase) : .windowSwipe(phase)
    }
}

extension Recognition {
    public var windowSwipe: SwipePhase? { fatalError("not implemented") }
    /// This frame began a swipe or a window swipe: the frame thread installs the cursor travel now.
    public var beginsSlide: Bool { swipe == .began || windowSwipe == .began }
}

extension GestureRecognizer {
    /// `slides`: the kinds whose setting is on. Empty: a pair's drag spoils like any drag, as with both settings off.
    public init(handMode: HandMode, surface: SurfaceSize, slides: Set<SlideKind>, swaps: Bool, travel: SwipeTravel) {
        fatalError("not implemented")
    }
    // .tapping:   let pair = slides.isEmpty ? nil : Pair(tap, joining: joining)
    //
    // beginOrSpoil, the one place a slide's direction is decided:
    //     guard let pair, let kind = move.slide, slides.contains(kind) else { return (.spoiled(anchor), nil) }
    //     return (.swiping(Swipe(kind: kind, fingers: …, lastTime: time, thumb: anchor)), .slide(kind, .began))
    //
    // Move:       var slide: SlideKind? { abs(dxMM) > abs(dyMM) ? .swipe : abs(dyMM) > abs(dxMM) ? .windowSwipe : nil }
    //
    // .swiping:   travel = swipe.travelMM + self.travel.travel(along: swipe.kind, dxMM: dxMM, dyMM: dyMM, interval: interval)
    //             every phase is emitted as .slide(swipe.kind, phase)
    //
    // Change 1. Swipe gains `let began: FrameTime` and `var isConfirmed: Bool` (true for .swipe, false for
    // .windowSwipe at begin). Blocking: a confirmed .swiping blocks; an unconfirmed one falls to the thumb rules on
    // swipe.thumb, the flags the spoiled slide of the setting off gives on the same frame.

    /// The model's answer to the window swipe start reported on the frame at `began`. true confirms it: from the next
    /// frame it blocks clicks, scrolling and the system's swipes until both fingers lift. false turns the slide into
    /// what the window swipe setting off makes of it: `.spoiled` under the slide's thumb, or, once that thumb has gone,
    /// a rest of every contact down as `restOrIdle` gives it (a thumb that rolled out of the corner counts as one of
    /// them), so it never becomes a swipe and a thumb tap under it may swap as it would there. Changes nothing
    /// unless an unconfirmed slide that began at `began` is in progress: an earlier start's answer, an answer after the
    /// slide ended and a second answer are ignored. (Exactly the setting-off state when it arrives before the next
    /// frame; a thumb that lifted and landed again before a late false is taken as the slide's thumb.)
    public mutating func answerWindowSwipe(began: FrameTime, isWindowSwipe: Bool) { fatalError("not implemented") }
}

extension PointerCurve {
    /// Cursor points the pointer moves along x and y for one report of finger movement: the HID system scales the
    /// whole delta by one speed-dependent multiplier (y by symmetry with x; open question 1). Replaces `cursorPoints`.
    public func cursorMove(dxMM: Double, dyMM: Double, interval: Double) -> (x: Double, y: Double) {
        fatalError("not implemented")
    }
}

public enum SwipeTravel: Equatable, Sendable {
    case linear
    case cursor(PointerCurve, pointsPerStep: Double)
    /// 100 cursor points per step: the app switcher's icon pitch, and the window switcher's row (R9). For rows the
    /// cursor match is not literal, by requirement ("whatever the rows' size on screen").
    public static let shippedPointsPerStep = 100.0
    /// `.linear`: the millimetres along the slide. `.cursor`: the cursor's points along it ÷ pointsPerStep × 12.
    func travel(along kind: SlideKind, dxMM: Double, dyMM: Double, interval: Double) -> Double {
        fatalError("not implemented")
    }
}

// MARK: Selection, shared by both switchers

/// Where the fingers have taken a switcher's selection along its fixed list: the nearest item; hard stops at both
/// ends; a rubber band of at most a quarter step, forgotten the moment the fingers turn back (no dead zone).
/// `Switcher.follow`, `selected`, `position` and `stretch` today, moved here unchanged.
public struct SwitcherSelection: Equatable, Sendable {
    /// At least 1: an app switcher of one icon rubber-bands at both ends. A window switcher has two or more rows.
    public let count: Int
    public package(set) var travelMM: Double = 0
    private var reportedMM: Double = 0
    package init(count: Int) { fatalError("not implemented") }
    /// Takes the slide's absolute travel. Returns how many items the selection crossed: one light tick each.
    @discardableResult package mutating func follow(_ reportedMM: Double) -> Int { fatalError("not implemented") }
    public var selected: Int { fatalError("not implemented") }
    public var position: Double { fatalError("not implemented") }
    public var stretch: Double { fatalError("not implemented") }
}
// Switcher keeps `row`, `startsOnFrontmost`, `selectedApp`, `selectsFrontmost` and `trackpad`; its maths moves into
// `public package(set) var selection: SwitcherSelection`. No forwarding properties: callers read `selection`.

// MARK: Windows

/// The window server's number for one window: the one number the Accessibility API, the window list and screen
/// capture all report, stable for the window's life. (Core comments never spell the confined API names: the source
/// scan reads comments too.)
public struct WindowID: Hashable, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}

/// One of an app's normal document or app windows, as one read found it.
public struct AppWindow: Equatable, Sendable, Identifiable {
    public let id: WindowID
    /// As the app titles it; "" when it has no title.
    public let title: String
    public let isFullScreen: Bool
}

/// One read of the frontmost app's windows.
public enum FrontmostWindows: Equatable, Sendable {
    /// There is no active app, or it is Trackpad Launcher itself.
    case noApp
    /// `visible`: its windows on the current Space, front to back; panels, palettes, sheets and other helpers left
    /// out. `minimised`: its minimised windows, in the order the app lists them. Both empty when it has none, when
    /// Accessibility is missing, or when the app did not answer in time.
    case app(AppEntry, visible: [AppWindow], minimised: [AppWindow])

    public var app: AppEntry? { fatalError("not implemented") }
}

/// How raising windows one at a time, each to the front of its app, reaches an order.
public enum WindowStack {
    /// The shortest front part of `target` (front to back) that, raised back to front, leaves the target windows on
    /// screen in `target` order among themselves, with the first in front of every window of the app. `current`: the
    /// app's visible windows now, front to back, including any that opened since the begin. The first target window is
    /// part of it unless it already leads `current`, so a minimised first window is restored and one opened mid-swipe
    /// is passed; target windows not in `current` other than the first (minimised) are left out, so a later minimised
    /// window is never restored. A window not in `target` keeps its place among the windows not raised, so one opened
    /// mid-swipe in front ends just behind the raised ones. Empty when the order already holds. Total: the whole target
    /// always qualifies. (check-2 runs these rules against R10 to R13.)
    public static func raises(current: [WindowID], target: [WindowID]) -> [WindowID] { fatalError("not implemented") }
}

// MARK: The window switcher

/// The window switcher during one window swipe. Its content is fixed when the window swipe begins: a window that opens
/// later is not added, and one that closes stays listed. The selection follows the travel.
public struct WindowSwitcher: Equatable, Sendable {
    /// What a window swipe lists: the frontmost app and two to ten of its windows. One exists only for a window swipe
    /// (change 1: the old `.noWindows` and `.accessibilityNeeded` message contents are gone).
    public struct Content: Equatable, Sendable {
        /// Whose windows these are; their rows show its icon.
        public let app: AppEntry
        public let windows: WindowList
    }

    /// Two to `GestureRules.windowSwitcherMaxRows` windows in all.
    public enum WindowList: Equatable, Sendable {
        /// The front window, the other visible windows front to back, then the minimised ones in the app's order.
        /// A full-screen front window is alone.
        case front(AppWindow, others: [AppWindow], minimised: [AppWindow])
        /// Every listed window is minimised: there is no front window.
        case minimisedOnly(first: AppWindow, rest: [AppWindow])
    }

    public enum Row: Equatable, Sendable {
        /// Its preview, or the app icon until the preview is ready, and its title.
        case visible(WindowID, title: String)
        /// Dimmed, with the app icon, its title and the "Minimised" badge.
        case minimised(WindowID, title: String)

        public var window: WindowID { fatalError("not implemented") }
        public var title: String { fatalError("not implemented") }
    }

    public let content: Content
    public package(set) var selection: SwitcherSelection
    /// Screen Recording was granted when the window swipe began, so visible rows show previews (R7).
    public let showsPreviews: Bool
    /// The window swipes since launch. Tells one window swipe's switcher from the next, so the presenter lays out and
    /// captures once per window swipe and a picture taken for one never shows in another.
    public let serial: Int
    public let trackpad: TrackpadID

    /// The selection count is `rows.count` (two to ten) and starts on the first row (R9, R11).
    package init(_ content: Content, showsPreviews: Bool, serial: Int, trackpad: TrackpadID) {
        fatalError("not implemented")
    }

    /// Whose windows these are and whose icon the rows show: `content.app`.
    public var app: AppEntry { fatalError("not implemented") }
    /// Top to bottom, two to ten. A window titled "" reads as the app's name followed by " — Window N", N its 1-based
    /// row (`Copy.untitledWindow`; R6).
    public var rows: [Row] { fatalError("not implemented") }
    /// The app's window in front when the window swipe began. nil when every listed window is minimised.
    public var frontWindow: WindowID? { fatalError("not implemented") }
    /// The windows to capture: the visible rows while `showsPreviews`, else none.
    public var previewWindows: [WindowID] { fatalError("not implemented") }
    /// The window that comes to the front while its row is selected. nil on a minimised row (R10).
    public var selectedVisibleWindow: WindowID? { fatalError("not implemented") }

    /// The lift (R11, R12), from the rows fixed at begin and a second read of the frontmost app's windows. Pure.
    /// - `now` is no app or another app → `.nothing`: no raises, silent.
    /// - The selected window has closed → no raises (no reordering); the haptic plays iff a window is in front now and
    ///   it is not `frontWindow`. Every listed window closed is therefore silent.
    /// - Otherwise the target is the selected window, then the visible windows in their begin order (the front window
    ///   first) without it, minus any that closed; `raises` is `WindowStack.raises(current: now's visible, target:)`;
    ///   the haptic plays iff the selected window is not `frontWindow`, which covers restoring a minimised one and every
    ///   row when every window is minimised. Lifting on the front window therefore restores the order, silently.
    public func lift(now: FrontmostWindows) -> WindowLift { fatalError("not implemented") }
}

/// What the lift does: `raises` front to back (the first ends in front with the keyboard focus), and R12's pulse.
public struct WindowLift: Equatable, Sendable {
    public let raises: [WindowID]
    public let playsHaptic: Bool
    public static let nothing = WindowLift(raises: [], playsHaptic: false)
}

extension WindowSwitcher.Content {
    /// The one parse from what the system read to what the switcher lists, and so whether a slide up or down is a
    /// window swipe at all (R1, R13):
    /// - A full-screen front window is the single row; other full-screen windows are left out.
    /// - Visible windows come before minimised ones, and the list is cut at 10.
    /// - nil for `.noApp`, and for fewer than two rows after these rules: one window, an only window minimised, no
    ///   windows, a full-screen front window, or an app that did not answer (its read lists nothing).
    package init?(_ read: FrontmostWindows) { fatalError("not implemented") }
}

/// Where the window switcher's rows and highlight sit: one column of `rowCount` rows on a display whose visible frame
/// is `displayHeight` points tall. The column fits when the panel's height plus `margin` above and below it is at most
/// `displayHeight`; when it would not, rows, gaps, padding and fonts shrink by the one factor that makes it fit (R5).
/// Pure, tested in core like `SwitcherRowLayout`.
public struct WindowColumnLayout: Equatable, Sendable {
    public static let margin = 12.0, panelPadding = 8.0, rowGap = 2.0, rowInset = 6.0
    public static let previewWidth = 120.0, previewHeight = 60.0, iconSide = 44.0, titleGap = 12.0
    public static let minTitleWidth = 180.0, maxTitleWidth = 320.0, titleSize = 13.0
    public let rowCount: Int
    /// 1 when the column fits at full size, otherwise below 1.
    public let scale: Double
    public init(rowCount: Int, widestTitle: Double, displayHeight: Double) { fatalError("not implemented") }
    /// Row height plus gap: the highlight's travel per row.
    public var pitch: Double { fatalError("not implemented") }
    public var panelSize: (width: Double, height: Double) { fatalError("not implemented") }
    /// The top of a row, measured down from the panel's top edge, for a position counted in rows.
    public func rowTop(at position: Double) -> Double { fatalError("not implemented") }
    /// A picture of a window `aspect` (width ÷ height) wide, in the slot: 60 pt tall, or less when 120 pt wide would
    /// not hold it (R6), times `scale`. The slot stays 120 pt wide, so titles never move when a picture lands.
    public func previewSize(aspect: Double) -> (width: Double, height: Double) { fatalError("not implemented") }
    /// The largest picture worth capturing, in pixels at a display's backing `scale`.
    public func previewPixels(scale: Double) -> (width: Int, height: Int) { fatalError("not implemented") }
}

// MARK: Ports

@MainActor public protocol SystemActions: AnyObject {
    // bringToFront(_:), registerLoginItem(), prepareLaunchAnimations(for:), playLaunchAnimation(for:), runningApps():
    // unchanged.

    /// The frontmost app's windows, read now, beside `runningApps()`: about a millisecond, at most one messaging timeout
    /// (0.2 s) when the app does not answer. Reads only. The windows it lists are the only ones a later
    /// `raiseWindows` may name, until the next read.
    func frontmostWindows() -> FrontmostWindows

    /// Raises these windows of the latest `frontmostWindows()` read, the last first, so the first ends in front of its
    /// app with the keyboard focus and the rest behind it in this order; beside `bringToFront`, which is app-level. A
    /// raised minimised window is restored. A window that has closed is skipped; an id the latest read did not list is
    /// skipped, so nothing on another Space is ever raised. About 2 ms per raise; once the app has timed out, no
    /// further calls go to it for that read. [] does nothing.
    func raiseWindows(_ frontToBack: [WindowID])
}

public enum Permission: Hashable, Sendable { case accessibility, screenRecording }

/// The permissions macOS grants the app. Real: SystemPermissions. Test: InMemoryPermissions.
@MainActor public protocol Permissions: AnyObject {
    /// On the main actor after either permission changed, and only then. Carries no data: re-read.
    var onChange: (@MainActor () -> Void)? { get set }
    /// Read fresh. Never prompts. Screen Recording's read costs about 4 ms (check-1), so the model reads it on pushes,
    /// never on a gesture.
    func isGranted(_ permission: Permission) -> Bool
    /// The system's prompt for it. Returns at once; the prompt belongs to another process.
    func ask(_ permission: Permission)
}

// TrackpadEvent gains `case windowSwipe(SwipeEvent)`; `TrackpadEvent.init(_:on:)` maps `.windowSwipe(phase)` to it.
// TrackpadHardware.run(_:handMode:blockClicks:slides:swaps:) replaces `swipes: Bool` with `slides: Set<SlideKind>`.

@MainActor public protocol TrackpadHardware: AnyObject {
    // onEvent, connected(), run(_:handMode:blockClicks:slides:swaps:), playFeedback(_:on:): as above. Change 1:
    // `onEvent`'s doc gains "A `.windowSwipe(.began)` asks whether its slide is a window swipe. Once the call returns,
    // the adapter answers that start, true only if `confirmWindowSwipe(on:)` was called during it, and the trackpad's
    // recognizer takes the answer before its next frame: confirmed, the slide blocks until both fingers lift;
    // declined, it goes on as with the window swipe setting off."

    /// A requirement of the protocol (change 1), so a call through `any TrackpadHardware` reaches the adapter. Only
    /// while `onEvent` is handling a `.windowSwipe(.began)` from `trackpad`: makes that slide a window swipe. Anywhere
    /// else, including an event a test injected, it does nothing.
    func confirmWindowSwipe(on trackpad: TrackpadID)
}

/// The main-actor half of the answer to a window swipe's start, one rule both hardware adapters share (change 1), as
/// they share `TrackpadEvent.init(_:on:)`: every event reaches `onEvent` through `deliver`, and a start comes back with
/// its answer for the adapter to send to that trackpad's recognizer.
@MainActor public final class WindowSwipeConfirmation {
    public init() { fatalError("not implemented") }
    /// Hands `event` to `handler`; nil drops it. For a `.windowSwipe(.began)`, returns whether `confirm(on:)` named the
    /// event's trackpad while `handler` ran, so false when it did not, or `handler` is nil. nil for every other event,
    /// which gets no reply.
    public func deliver(_ event: TrackpadEvent, to handler: (@MainActor (TrackpadEvent) -> Void)?) -> Bool? {
        fatalError("not implemented")
    }
    /// What the adapter's `confirmWindowSwipe(on:)` calls. Counts only while `deliver` hands over a start from
    /// `trackpad`; any other call does nothing, and nothing carries over to the next start.
    public func confirm(on trackpad: TrackpadID) { fatalError("not implemented") }
}

// MARK: Model additions

extension Settings {
    // public var isWindowSwipeOn = true                 // decodeIfPresent ?? true: an upgrade leaves it on (R16)
    // public var hasAskedForScreenRecording = false     // the hint's first press asked macOS (R8)
    /// Derived, never stored.
    public var slides: Set<SlideKind> { fatalError("not implemented") }
}

public enum ScreenRecordingHint: Equatable, Sendable {
    /// Never asked: the button asks macOS.
    case ask
    /// Asked before and still missing: the button opens System Settings on the Screen Recording page.
    case openSettings
}

extension Launcher {
    // init: `access: any AccessibilityPermission` becomes `permissions: any Permissions`; nothing else changes.
    // private enum ShownSwitcher: Equatable { case apps(Switcher), windows(WindowSwitcher) }
    // private var shown: ShownSwitcher?            // written only by swipe(_:), windowSwipe(_:) and reconcile()
    // private var isScreenRecordingGranted = false // read with Accessibility in reconcile, on every push, before the
    //                                              // Run guard; a Screen Recording change never restarts trackpads
    // @ObservationIgnored private var windowSwipesBegun = 0
    public var switcher: Switcher? { fatalError("not implemented") }
    /// Non-nil for the whole of a window swipe, unless another trackpad's switcher was already up when it began.
    public var windowSwitcher: WindowSwitcher? { fatalError("not implemented") }
    public var isWindowSwipeOn: Bool { fatalError("not implemented") }
    /// nil while the window swipe setting is off or Screen Recording is granted (R8).
    public var screenRecordingHint: ScreenRecordingHint? { fatalError("not implemented") }
    /// Saved at once. The recognizers are rebuilt, so the next slide obeys it and a window swipe in progress ends.
    public func setWindowSwipe(on: Bool) { fatalError("not implemented") }
    /// Only while the hint is `.ask`. Records the ask and saves, then asks: a crash in between never asks twice.
    public func askForScreenRecording() { fatalError("not implemented") }
    // start(): onEvent routes `.windowSwipe(let e)` to windowSwipe(e); permissions.onChange = { reconcile() };
    //          the first-launch prompt becomes permissions.ask(.accessibility).
    // reconcile(): Run.slides = settings.slides, minus .windowSwipe while Accessibility is missing (change 1, R14):
    //             without it no window can be read, so a slide up or down spoils as with the setting off.
}

// GestureRules: windowSwitcherMaxRows = 10.
// Copy: minimisedBadge, untitledWindow(of:position:) ("Preview — Window 2"),
//       screenRecordingHint ("Window previews need Screen Recording."),
//       screenRecordingButton(_:) ("Allow Screen Recording…" for .ask, "Open System Settings…" for .openSettings),
//       accessibilityHint ("Clicks and scrolling aren't blocked during gestures, and windows can't be switched. Allow
//       Accessibility access to do both."; change 1, R14). Change 1 removes noOpenWindows and accessibilityForWindows.
```

#### Platform and shell signatures

```swift
/// The whole window read and raise behind `SystemActions.frontmostWindows()` and `raiseWindows(_:)`, over the
/// Accessibility element API and the window list. `WorkspaceActions` creates one and delegates both methods to it, as it
/// does `runningApps()` to `RunningAppsReader`. Holds no window, so its tests construct it alone. The only file that may
/// name `AXUIElement` (and so `_AXUIElementGetWindow`) or `CGWindowList`.
@MainActor final class FrontmostAppWindows {
    static let messagingTimeout: Float = 0.2
    /// Sets the messaging timeout once on the system-wide element (process-wide; set on any other element it covers
    /// that element only, `AXUIElement.h`), resolves `_AXUIElementGetWindow` with dlsym, and pays the window list's
    /// first-call cost (about 50 ms) off the main actor now, not at the first window swipe.
    init() { fatalError("not implemented") }
    func read() -> FrontmostWindows {
        // 1. NSWorkspace.frontmostApplication, not this process → RunningApp.entry(for:), else .noApp.
        // 2. AXUIElementCreateApplication(pid), kAXWindowsAttribute. Any error (not trusted, cannot complete) →
        //    .app(entry, [], []).
        // 3. Per window, one AXUIElementCopyMultipleAttributeValues: role, subrole, title, minimised, AXFullScreen,
        //    position, size. Stop at the first cannot-complete; the listing is then marked unanswering.
        // 4. Number: _AXUIElementGetWindow, else Self.number(of:among:) against the pid's window-list entries.
        // 5. On screen: CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements]), the pid's layer-0
        //    numbers, front to back.
        // 6. Self.sort(raw, onScreen:); keep [WindowID: AXUIElement] for the listed windows as what `raise` may name.
        fatalError("not implemented")
    }
    func raise(_ frontToBack: [WindowID]) {
        // Unanswering listing → nothing. For each id, last first: unlisted → skip; kAXRaiseAction on its element
        // (it restores a minimised window, F20); kAXErrorInvalidUIElement (closed, F14) → skip; kAXErrorCannotComplete
        // → mark the listing unanswering and stop.
        fatalError("not implemented")
    }

    /// The adapter's internal seam, pure and tested in LauncherPlatformTests: R4's filter and R3's order from raw
    /// facts. Visible: role AXWindow, subrole AXStandardWindow, not minimised, on screen now (so on this Space, F10), in
    /// the window list's order. Minimised: kAXMinimized alone, because a minimised window reports AXDialog (F9), in AX
    /// order. A window with no number is left out.
    nonisolated static func sort(_ windows: [RawWindow], onScreen: [UInt32]) -> (visible: [AppWindow], minimised: [AppWindow]) {
        fatalError("not implemented")
    }
    /// The fallback without the private symbol, pure: the pid's window-list entry with the same frame, and the same
    /// title where the list names windows. nil when none, or more than one, matches.
    nonisolated static func number(of window: RawWindow, among listed: [ListedWindow]) -> UInt32? {
        fatalError("not implemented")
    }
}

struct RawWindow: Sendable {
    var number: UInt32?; let title: String; let role: String?; let subrole: String?
    let isMinimised: Bool; let isFullScreen: Bool; let frame: CGRect?
}
struct ListedWindow: Sendable { let number: UInt32; let frame: CGRect; let name: String? }

// WorkspaceActions: `private let windows = FrontmostAppWindows()`; frontmostWindows() → windows.read();
// raiseWindows(_:) → windows.raise(_:).

// Change 1: the answer to a window swipe start, the one thing that hops from the main actor to a frame thread.

/// The answer to one window swipe start: the frame time the start was reported on, and whether it is a window swipe.
struct WindowSwipeAnswer: Sendable { let began: FrameTime; let isWindowSwipe: Bool }

final class DeviceSession: Sendable {
    /// `deliver` now also carries, for a frame that reported `.windowSwipe(.began)`, the reply for that start: called
    /// once on the main actor, it records `WindowSwipeAnswer(began: frame.time, isWindowSwipe:)`. nil for every other
    /// event.
    init(trackpad: TrackpadID, recognizer: GestureRecognizer, pointerCurves: [PointerCurve.Point], clickTap: ClickTap?,
         deliver: @escaping @Sendable (TrackpadEvent, _ reply: (@Sendable (Bool) -> Void)?) -> Void) {
        fatalError("not implemented")
    }
    // Writer: the main actor, through a reply. Reader: this device's frame callback, which reads it before taking the
    // recognizer's lock and hands it to `answerWindowSwipe(began:isWindowSwipe:)` before `step`. Never cleared: the
    // recognizer ignores an answer it has already taken or that names another start.
    // private let answer = Mutex<WindowSwipeAnswer?>(nil)
}

// MultitouchTrackpads, on the main actor in the hop: `let answer = confirmation.deliver(event, to: onEvent)`, then
// `reply?(answer)` when both exist; `confirmWindowSwipe(on:)` forwards to `confirmation.confirm(on:)`. An event from
// a replaced run is dropped before `deliver`, as today, reply and all: its session is gone.
// InMemoryTrackpads does the same between frames, giving the answer straight to the running recognizer with the
// start frame's time and appending it to `windowSwipeAnswers`; `inject(_:)` also goes through `deliver`, and its
// answer goes nowhere.

/// Permissions over AX trust, screen-capture access and tccd's one broadcast (about 30 ms after a change, main queue,
/// no payload, no service named): both are re-read on every post, and `onChange` runs only when either changed. The
/// only file that may name `AXIsProcessTrusted`, `notify_register` or `ScreenCaptureAccess`.
@MainActor public final class SystemPermissions: Permissions {
    /// Both reads are injectable for the adapter's own test, which flips them and posts the notification itself.
    public init(
        trusted: @escaping @Sendable () -> Bool = { AXIsProcessTrusted() },
        capturing: @escaping @Sendable () -> Bool = { CGPreflightScreenCaptureAccess() }
    ) { fatalError("not implemented") }
    public var onChange: (@MainActor () -> Void)?
    public func isGranted(_ permission: Permission) -> Bool { fatalError("not implemented") }
    /// .accessibility: AXIsProcessTrustedWithOptions with the prompt key. .screenRecording: CGRequestScreenCaptureAccess().
    public func ask(_ permission: Permission) { fatalError("not implemented") }
}
```

```swift
/// Both switchers' window: borderless, non-activating, click-through, screen-saver level on every Space and beside
/// full-screen apps, never key. Its content is Liquid Glass under `roundedClip`. Presents at once or with a short
/// appear animation; dismisses with a 150 ms fade (at once with Reduce motion) unless presented again meanwhile.
class OverlayPanel: NSPanel {
    init(cornerRadius: CGFloat, content: NSView) { fatalError("not implemented") }
    func present(animated: Bool) { fatalError("not implemented") }
    func dismiss() { fatalError("not implemented") }
    /// Runs once the panel is out. The window switcher drops every picture here (R17).
    func emptied() {}
}

/// AppKit's rule for which display holds the pointer, the nearest when none does. Moved out of SwitcherPresenter.
enum Displays { static func screen(under pointer: NSPoint) -> NSScreen? { fatalError("not implemented") } }

/// The window switcher: one `.regular` glass panel, ten pre-created rows, one `.clear` glass highlight inside the panel
/// glass's content. The presenter decides what shows; every look and motion number is in `WindowSwitcherLook`.
final class WindowSwitcherPanel: OverlayPanel {
    /// The widest title at full size, measured with the row font.
    func widestTitle(_ rows: [WindowSwitcher.Row]) -> Double { fatalError("not implemented") }
    func lay(out rows: [WindowSwitcher.Row], icon: NSImage?, layout: WindowColumnLayout, topLeft: NSPoint) {
        fatalError("not implemented")
    }
    /// The highlight sits `position` rows from the top, with actions disabled; the selected title takes `labelColor`.
    func show(position: Double, selected: Int) { fatalError("not implemented") }
    func springHighlight(fromY offset: Double) { fatalError("not implemented") }
    /// Crossfades the row's slot from the icon to the picture, sized by `layout.previewSize(aspect:)`.
    func setPreview(_ picture: CGImage, row: Int, animated: Bool) { fatalError("not implemented") }
    override func emptied() { /* every slot layer's contents = nil */ }
}

/// Pictures of windows, taken off the main actor. The one file that captures the screen, for previews only.
enum PreviewCapture {
    /// Yields each window's picture as it is taken: SCShareableContent once (on-screen windows, about 14 ms), then one
    /// SCScreenshotManager capture per window, concurrently (F27), through SCContentFilter(desktopIndependentWindow:),
    /// sized to the window's proportions within `fitting` pixels, with `scalesToFit`, no cursor and no shadow. A window
    /// that cannot be captured yields nothing. Cancelling the consuming task stops the captures. Called only for a
    /// window switcher whose `showsPreviews` is true, so it never prompts.
    nonisolated static func pictures(of windows: [WindowID], fitting: (width: Int, height: Int))
        -> AsyncStream<(WindowID, CGImage)> { fatalError("not implemented") }
}

/// The look and motion, in one value whose defaults are the shipped look, as `LaunchTuning` is for the launch
/// animation: refining it later together touches no policy. Sizes that decide fit live in WindowColumnLayout.
struct WindowSwitcherLook: Sendable {
    var panelRadius = 22.0, highlightRadius = 14.0           // highlight = panel radius − padding: concentric
    var previewRadius = 6.0, minimisedAlpha = 0.55, badgeSize = 10.0
    var titleWeight = NSFont.Weight.medium
    var appearDuration = 0.1, appearScale = 0.96, previewCrossfade = 0.15, dismissFade = 0.15
    var springStiffness = 420.0, springDamping = 22.0
    static let shipped = WindowSwitcherLook()
}

/// Renders `launcher.windowSwitcher` and holds nothing the model holds. Owned by MenuBarShell beside SwitcherPresenter.
/// The panel is created now, so a window swipe never pays the first window's cost. Its own `AppIcons` takes the
/// frontmost app's icon from the running app (about 0.1 ms), so it needs none of the swipe setting's icon passes.
final class WindowSwitcherPresenter {
    // panel; icons = AppIcons(side: WindowColumnLayout.iconSide); capture: Task<Void, Never>?; shownSerial: Int?;
    // layout; lastStretch. render(_:) and open(_:) as in call site 2.
    init(launcher: Launcher) { fatalError("not implemented") }
}
```

**The look and motion** are best judgement, kept in `WindowSwitcherLook` (shell) and `WindowColumnLayout` (core
geometry):
- The panel is `.regular` glass, radius 22, its top-left corner 12 pt inside the pointer display's `visibleFrame`:
  below the menu bar and clear of a left Dock, in both hand modes. Each row is 72 pt: a 120 × 60 pt slot with radius 6
  holding the picture, 60 pt tall or less when 120 pt wide would not hold it, or a 44 pt app icon centred until the
  picture is ready; then the title on one line, 13 pt medium, truncated at the end, `labelColor` when selected and
  `secondaryLabelColor` otherwise. The column is as wide as the widest title, clamped to 180 to 320 pt, so a short
  list stays compact. A minimised row sits at 55 % alpha with a 10 pt "Minimised" capsule.
- The highlight is one `.clear` glass view, radius 14, concentric with the panel's padding (the macOS 26 SDK has no
  `cornerConfiguration`, so concentricity is by these numbers). It follows the travel 1:1 with actions disabled and
  springs on `position.y` past the ends, as the app switcher's does on `position.x`.
- The panel appears with 0.1 s of opacity and a spring from 0.96 scale anchored at its top-left corner, at once with
  Reduce motion; a picture arrives with a 0.15 s crossfade; the panel leaves with the shared 150 ms fade. Shrinking
  scales fonts with the rows.

**Degraded cases.**

| Case | Behaviour | Where |
|---|---|---|
| No Accessibility | No window swipe: the recognizers run without `.windowSwipe`, so a slide up or down spoils on its first frame past 3 mm, exactly as with the setting off; nothing is read and nothing hops (R14). | model's `Run` |
| App does not answer | The read lists nothing, so the start is declined and the slide goes on as with the setting off. The decision waits up to one messaging timeout (0.2 s), during which the slide blocks only by the thumb rules. A timeout during `raiseWindows` stops raises to that app for this read. | adapter; parse |
| Main actor busy past the next frame | The start waits, unconfirmed: its phases are reported, and it blocks only by the thumb rules, until the answer reaches the frame thread on a later frame. A declined slide is then spoiled from that frame; a thumb that lifted and landed again meanwhile is taken as the slide's thumb, so it cannot swap until the fingers lift. | recognizer; `DeviceSession` |
| Window closed | A raise changes nothing. The lift does no reordering, with the haptic only if another window is now in front (R10, R11). | adapter; `lift(now:)` |
| Every listed window closed | Nothing is in front: the lift is silent. | `lift(now:)` |
| Another app in front at the lift | Nothing is raised; silent. | `lift(now:)` |
| No `_AXUIElementGetWindow` | Numbers come from frame matching; an unmatched window is not listed. | adapter |
| No Screen Recording | `previewWindows == []`: nothing captures, rows show the icon, nothing prompts (R7). | model; shell |
| Capture fails for a window | Its row keeps the icon. | shell |
| No frontmost app | No window swipe: the parse gives nothing and the start is declined (R13). | model parse |
| Another trackpad's switcher is up | A slide down over an app with two or more windows is confirmed and runs its course blocked with no switcher of its own, as a second trackpad's swipe does; one with fewer is declined. | model |

#### Requirement trace

| R | Carried by |
|---|---|
| R1 | `beginOrSpoil` (`Move.slide`, `slides.contains`); pair and `.resting` exist while `!slides.isEmpty`; `dragThresholdMM` shared; the edge filter; `.windowSwipe(.began)` → `windowSwipe(_:)` confirms only a `Content` (two or more rows, the same parse the rows come from) and shows the switcher in that main turn; `answerWindowSwipe` |
| R2 | `Swipe.kind` fixed at begin; phases emitted by kind (`.slide(kind, _)`); a slide never re-enters `beginOrSpoil`, and a declined one is `.spoiled` |
| R3 | Current Space and window-list order in `FrontmostAppWindows.sort`; `Content.init?(_:)`: the full-screen front window alone (so nil), visible before minimised, the cut at 10; `content` is a `let` |
| R4 | `FrontmostAppWindows.sort` (standard visible windows on screen; minimised by `kAXMinimized` alone); `Row.minimised` drawn dimmed with the badge and the icon |
| R5 | `Displays.screen(under:)` + `visibleFrame` top-left with `margin`; `WindowColumnLayout.scale`; `OverlayPanel` (never key, click-through); `dismiss()` on nil |
| R6 | `rows` titles (`Copy.untitledWindow`); `WindowColumnLayout.previewSize(aspect:)`; the icon until `PreviewCapture` yields; one capture per `serial` at the open; the panel shown in the begin turn |
| R7 | `showsPreviews` from the pushed grant at begin; `previewWindows` empty otherwise; the capture called only then; `onChange` → `reconcile` |
| R8 | `screenRecordingHint` (setting, grant, `hasAskedForScreenRecording`); `askForScreenRecording()` → `permissions.ask(.screenRecording)`; `SettingsPane.screenRecording`; the TCC push → reconcile → refit |
| R9 | `SwipeTravel.travel(along: .windowSwipe)`, `pointsPerStep` 100; `SwitcherSelection.follow`; travel 0 at begin |
| R10 | `selectedVisibleWindow` + `system.raiseWindows([window])` in `.moved`; row 0 is the front window, so sliding back raises it; nothing when every window is minimised; a closed window is skipped by the adapter |
| R11 | the second read; `lift(now:)` and `WindowStack.raises` (restore of the first only, closed selected → no reordering); `system.raiseWindows(lift.raises)`; `window = .closed` on a changing lift |
| R12 | Ticks = `follow`'s return; `WindowLift.playsHaptic`; `windowSwipe(_:)` never calls `playLaunchAnimation` |
| R13 | `Content.init?` nil below two rows or with no app; no confirmation, so `answerWindowSwipe(…, false)` turns the slide into the setting-off `.spoiled` before the next frame; the unconfirmed start frame blocks by the thumb rules; one read at the start, never repeated in the slide; "a haptic MUST NOT play" read as the slide's own, a swap under its fingers keeping its haptic as with the setting off (open question 17) |
| R14 | `Run.slides` without `.windowSwipe` while Accessibility is missing; `Copy.accessibilityHint` names switching windows |
| R15 | `.swiping` unchanged once confirmed, blocking from the frame after the start; `.cancelled` → `shown = nil` with no read and no raise |
| R16 | `Settings.isWindowSwipeOn`, `slides`, `Run.slides`, `setWindowSwipe(on:)`, the third `SwitcherSection` row |
| R17 | One capture per `serial`, only at the open; cancelled at nil; arrivals checked against the shown serial; `emptied()`; no image type in the core; bans on streams, recordings, image encoders and file writes |

#### Testing seams

| Seam | Scenarios | Handles a test holds |
|---|---|---|
| The recognizer over `TouchScript` (`windowPhases`, `phases`, `perFrame`) | R1, R2, R15 (blocking, rejoin, thumb lift, third finger, click), R16 (each kind alone, both, neither); the old vertical-spoil rows flipped to "window swipe off"; change 1: the answer to a start (confirmed, declined, late, unanswered, stale) against the setting-off recognizers (`[.swipe]`, and `[]` with the swipe off) as the reference | the frame clock; `answering:` on the drivers, or `answerWindowSwipe` called by hand between frames |
| `World`: the real `Launcher`, recognizer and filters inside `InMemoryTrackpads`, `RecordingSystemActions` with its `FakeWindows`, `InMemoryPermissions` | R3/R4 as the fake lists them, R6 titles, R7 (`showsPreviews`, `previewWindows`, no ask), R8, R9 (linear), R10, R11, R12, R13, R14, R15 (cancel, no scroll), R16 (persistence, upgrade with the frozen record); change 1: a world with the window swipe setting off as the reference for "exactly as with the setting off" | `system.windows.set(visible:minimised:fullScreenFront:)`, `close(_:)` / `open(_:)` between `play` pieces, `answers = false`, `dropsRaises`, `onScreenTitles`, `minimisedTitles`, `raised`, `reads`; `hardware.windowSwipeAnswers` (each start's answer, in order); `permissions.set(_:granted:)` (the push) and `set(_:granted:push: false)` (a withheld push), `asks`, `onAsk`; `World.playFrameByFrame(_:)` for "on every frame" rows |
| Pure values | `SwitcherSelection`, `Content.init`, `rows` and titles, `lift(now:)`, `WindowStack.raises`, `WindowColumnLayout` (scale, `previewSize`), `cursorMove` y, `Copy`; change 1: `WindowSwipeConfirmation`'s edges no model produces (a confirmation outside a hand-over, for another trackpad, or around a non-start event) | none |
| `LauncherPlatformTests` | `FrontmostAppWindows.sort` and `number(of:among:)` over raw facts (R3, R4 filters and order); `SystemPermissions` re-reads both on a posted broadcast and pushes only on a change (injected closures); `DeviceSession.receive` installs the cursor travel when a window swipe begins; change 1: a reply reaches the recognizer before the session's next frame, and a stale one does nothing | the posted notification; the reply `deliver` hands over; `blocksClicks` as the click tap reads it |
| By hand | The glass, placement on two displays, shrink, motion; real AX across apps (Spaces, full screen, restore, focus, Chromium and Electron); previews arriving with the icon until then, and R17 by code review (LauncherUI has no test target); the TCC prompt and the Settings page; any relaunch; a hung app (`kill -STOP`); the periodic capture alert (F31) | none |

`FakeWindows`, held by `RecordingSystemActions` as `windows`, is a small window stack that does what `AXRaise` does and
nothing more: `raiseWindows` moves each window, last first, to the front and restores a minimised one, skipping closed
and unlisted ids, and records each call in `raised`; `frontmostWindows()` answers from the existing `frontmost` field
and the stack, so a second window swipe sees the first one's order (R11's toggle scenario). All policy stays in the
model's pure functions, so the fake carries none. The rest of `RecordingSystemActions` is unchanged.

#### Source policy and docs

- Confined, each to one file: `AXIsProcessTrusted`, `notify_register` and `ScreenCaptureAccess` (the preflight and the
  request) to `SystemPermissions.swift`; `AXUIElement` (which covers `_AXUIElementGetWindow`) and `CGWindowList` to
  `FrontmostAppWindows.swift`; `ScreenCaptureKit`, `SCShareableContent` and `SCScreenshotManager` to
  `PreviewCapture.swift`.
- Banned: `SCStream(` and `SCRecordingOutput` (pictures, never a stream or a recording; `SCStreamConfiguration(` does
  not match); `CGImageDestination`, `representation(using` and `tiffRepresentation` (a picture is never encoded or
  written); `AXUIElementSetAttributeValue` and `kAXPressAction` (the switcher only picks a window). None of these
  appears in the sources today. The "R9 only Accessibility" labels become "no Input Monitoring or event posting". The
  scan matches comments, so no other file may spell a confined name, even in a doc comment.
- `docs/architecture.md`: Shape names the Accessibility element API and the private window number among
  `LauncherPlatform`'s frameworks, and ScreenCaptureKit in `LauncherUI` for window previews. Concurrency: a window
  swipe's phases hop like a swipe's; the window reads and raises are synchronous AX IPC on the main actor under a short
  timeout; the window list's first call is paid off the main actor at launch; previews are captured off the main actor.
  Privacy: two optional permissions and what each is used for; previews in memory only; the private window number with
  its fallback; the confinement sentence covering the AX element API, the window list and capture.
- `docs/domain-model.md`: the plan's new terms (window swipe, window switcher, window, front window, window swipe
  setting, screen recording hint) and the changed entries.
- Change 1, updated with this plan: `docs/architecture.md` Concurrency gains the one answer that hops back to a frame
  thread, and Privacy says windows are read when a slide up or down begins; `docs/domain-model.md`'s *Window swipe*,
  *Window switcher*, *Tap*, *Swipe*, *Frontmost app*, *Feedback* and *Accessibility hint* entries follow R1, R3, R6,
  R13 and R14. `docs/product-overview.md` follows the requirements' Documentation section in S6.

### Synthesis decision

**The arena.** Three candidates answered the same task and grounding. Candidate-2 (Fable) and candidate-1 (Opus) come
from the earlier run; candidate-1's runner finished after that run's architect stopped on a Fable quota error, so this
run believed it missing and dispatched an Opus runner, which wrote candidate-3 over candidate-1's path. The judged
candidate-1 was restored verbatim and the late package kept as candidate-3. Fable being out of quota, the cross-judge
ran on Opus, the model behind candidates 1 and 3; my own criterion-by-criterion pass is the check on that bias.

**Scores** (rubric C1 to C5, 0 to 3 each):

| | C1 | C2 | C3 | C4 | C5 | Judge | Mine |
|---|---|---|---|---|---|---|---|
| candidate-1 | 3 | 2 | 2 | 2 | 3 | 12 | 12 |
| candidate-2 | 2 | 2 | 2 | 3 | 2 | 11 | 11 |
| candidate-3 | 2 | 3 | 2 | 2 | 2 | 13 | 11 |

The row scores are mine. The judge gave candidate-3 a 3 on C1 and C5 where I give 2: it changes the gesture hint and
closes the launcher window on the ask, neither asked for, and its all-minimised case is an optional rather than a
variant.

**Base: candidate-1**, for its content types (`.front` / `.minimisedOnly`, the `Row` enum, the per-swipe `serial`)
and its event shape. The judge recommended candidate-1 over candidate-2, then candidate-3 once it had scored it, mainly
because candidate-3 already ran the lift's policy in the model over a second read and kept the window methods on
`SystemActions` (Preserve 5 and 7). Both of those are grafted below, which leaves two differences to carry the label.
The event shape: candidate-1's `.windowSwipe` case leaves the 78 bare `.began` uses in 18 files untouched, where
`.began(axis)` would change every one, and gives each action its own handler. The content types: the judge also
preferred candidate-1's.

**Grafted.**
- From candidate-3:
  - the lift as a pure plan over a second read in the model (`lift(now:)`, `WindowLift`), the adapter only raising and
    the fake only emulating `AXRaise`;
  - the window read and raise on `SystemActions`, with the work in one platform type;
  - the adapter's pure `sort` and `number(of:among:)`;
  - `previewSize(aspect:)` and `previewPixels(scale:)`;
  - the encoder bans;
  - the open question on a window opened mid-swipe.
- From candidate-2:
  - one look value with `.shipped`;
  - separate button titles for asking and for opening System Settings;
  - the open question on a minimised window that belongs to another Space.
- From the judge's review of candidate-1:
  - the messaging timeout set once on the system-wide element (`AXUIElement.h`: per element otherwise);
  - a lift with no window in front is silent;
  - R11's rules in one pure function rather than in both adapters, which the candidate-3 lift settles.
- From verification:
  - `WindowStack.raises` compares against every visible window of the app now, so the selected window ends in front
    even past one opened mid-swipe;
  - core comments never spell a confined name;
  - the usage's second window swipe continues the first hand's script, as `World.play` requires.

**Convergence**, shipped as consensus:
- All three agree on:
  - one `.swiping` state, with the kind fixed at begin and a set of enabled kinds;
  - the selection maths extracted and shared;
  - one stored enum for the open switcher;
  - only visible windows raised while sliding;
  - `AXRaise` to restore;
  - the on-screen window list for the current Space;
  - `_AXUIElementGetWindow` with frame matching;
  - the TCC push;
  - the panel at the top-left of `visibleFrame`;
  - 100 points per row and the cut at ten rows;
  - a persisted "asked" flag.
- Candidates 1 and 3 agree on previews in the shell, one `Permissions` port and a shared `OverlayPanel`.

**A disagreement, resolved.** My first draft grafted candidate-2's capture port, which carried previews as bytes
through the model. The judge recommended keeping previews in the shell, citing plan 008's icon decision, and
candidate-3 chose the same on its own. A preview is to a `WindowID` what an icon is to an `AppEntry`, no decision reads
it, and live previews would later mean frames through the model, so the shell keeps them. The cost is that preview
arrival is checked by hand, as is all `LauncherUI` rendering. I declined the judge's suggested fresh grant read at each
begin, because a preflight costs about 4 ms on the calling thread (check-1). The judge agreed.

**Rejected.**
- From candidate-2:
  - the capture port and the bitmap type;
  - `.began(axis)`;
  - the missing full-screen rule;
  - the World test that contradicted its own lift.
- From candidate-3:
  - `.began(axis)`;
  - the optional front window and the per-row minimised flag;
  - a timeout that stops only the current call;
  - comparing content instead of using a per-swipe serial;
  - closing the launcher window on the ask.
- From candidate-1:
  - `stack` deciding and answering from inside the adapter, which now lives in the model;
  - the separate `AppWindows` port, which loses to Preserve 7.
- From candidates 2 and 3: the gesture hint change, which no requirement asks for.

### Tradeoffs accepted

- We accept AX calls synchronously on the main actor (about a millisecond to read, about 2 ms per raise), bounded by a
  0.2 s process-wide messaging timeout with no further raises to an app after its first timeout, in exchange for a
  synchronous model and model tests with no held reads. An app that hangs mid-swipe can stall the main actor for up to
  0.2 s at the raise that meets it and again at the lift's read; one that hangs before the begin costs 0.2 s once, and
  the slide is then no window swipe.
- We accept a second window read at the lift (about a millisecond) in exchange for a lift that follows the windows as
  they are, whatever the raises while sliding did, with every R11 and R12 rule in one pure function.
- We accept that preview arrival, the icon until a picture is ready, and the discard are checked by hand and in code
  review, as every other `LauncherUI` rendering is, in exchange for pictures with one owner, a lifetime derived from
  the model value, and no image channel through the core.
- We accept ScreenCaptureKit in `LauncherUI`, a first permission-gated API outside `LauncherPlatform`, in exchange for
  keeping a rendered asset beside the icons it stands in for; the capture runs only when the model says so, and its
  names are confined to one file.
- We accept gating previews on the grant the last TCC push left, not a fresh read at each begin (about 4 ms, check-1):
  a revocation reaches the model through the push within about 30 ms.
- We accept two more methods on `SystemActions`, delegated by `WorkspaceActions` to `FrontmostAppWindows` as
  `runningApps()` is to `RunningAppsReader`, and a window stack inside the recording fake, in exchange for no new port
  (`why.md` Preserve 7) and the window knowledge in one platform type its tests construct alone. The ordering rule
  "`raiseWindows` names windows of the latest read" is stated on both methods.
- We accept renaming `AccessibilityPermission` to `Permissions` across the tests and the composition root in exchange
  for one module that owns the one TCC broadcast; on a burst of broadcasts each post re-reads both grants (about 4 ms
  for Screen Recording), which happens only while someone changes a permission.
- We accept that a lift on the front window may raise windows when the user slid away and back, in exchange for one
  lift rule that restores the order the user left.
- We accept `WindowID` being the window server's number: a macOS without `_AXUIElementGetWindow` falls back to frame
  matching and leaves unmatched windows out.
- We accept one `pointsPerStep` (100) for both slides, so the Debug tuner moves them together.
- We accept that a lift that changes the window in front closes the launcher window, as the swipe's lift does,
  because a key launcher window would otherwise keep the keyboard from the raised window.
- We accept both presenters waking on every write to `shown` (the idle one sees nil and returns) in exchange for "at
  most one switcher" being a property of the type.
- We accept, with the window swipe setting on, that two fingers sliding up or down under an anchored thumb over an
  app with two or more windows no longer scroll after the blocking window: R16's switch is the way out (`why.md`
  Risk 1). Over an app with fewer, they scroll as before (R13).
- Change 1. We accept a window swipe's blocking starting on the frame after its start, about 10 ms later, in exchange
  for a declined slide being exactly the setting-off slide: on the start frame the slide blocks only by the thumb
  rules, which is what a declined slide must have blocked, because a scroll the filter has once stilled stays stilled
  until the fingers lift. After the 3 s blocking window, a scroll in that frame reaches apps and is stilled from the
  next, as a scroll that began before any window swipe is; a press in it reaches apps and cancels the window swipe
  (T35). Within the blocking window nothing changes, since the thumb rules already block.
- Change 1. We accept one main-to-frame answer per window swipe start, through a slot only the main actor writes and a
  reply only the adapter calls, in exchange for every window read staying on the main actor and the frame thread never
  waiting on another app.
- Change 1. We accept one window read on the main actor for every slide up or down, declined or not (about a
  millisecond), in exchange for the confirmation and the rows coming from one read, so the count that decides is the
  count the user sees (R1).
- Change 1. We accept that a busy main actor delays the decision: the slide waits unconfirmed, blocking only by the
  thumb rules, and a thumb that lifts and lands again before a late decline cannot swap until the fingers lift. A
  window swipe's switcher already waited on the same main actor before change 1.
- Change 1. We accept that an app that stops answering partway through the begin read can delay a switcher past R1's
  50 ms, by up to the 0.2 s messaging timeout, when the windows read before the stop still make two rows; an app that
  stops before the read makes the slide no window swipe after the same wait.
- Change 1. We accept that a second trackpad's slide down, while another switcher is up, is read and, over two or more
  windows, confirmed and blocked with no switcher of its own, as R1's "start rules otherwise match the swipe's" and the
  second trackpad's swipe precedent ask.

### Alternatives considered

- **Previews through the model behind a capture port.** The Screen Recording permission and capture as one port
  delivering bitmap bytes, held in the `WindowSwitcher` value. It gives `World` a handle on arrival and checks the
  grant at the OS boundary, but it exposes a capture method and a push on a port, a domain bitmap type, a relay in the
  model, and state no decision reads; it repeats what plan 008 refused for icons; and live previews would then mean
  frames through the model. Lost on depth and locality.
- **`stack(order)` converging inside the adapter and answering the window in front.** A deeper-looking port, but its
  answer is itself a prediction (raises land in the window server after the call returns), it puts R11's closed and
  minimised rules inside both adapters, and it cannot see another app having come forward. Lost on locality.
- **A separate two-method `AppWindows` port.** It keeps the window knowledge and the "latest read" rule on a module of
  its own with its own fake and no delegation in `WorkspaceActions`, but it is a new port for what is a read beside
  `runningApps()` and an effect beside `bringToFront`, the shape the grounding asks to preserve. Lost narrowly.
- **A separate Screen Recording permission port beside `AccessibilityPermission`, with a shared TCC listener.** No
  rename, but two ports of the same shape over one broadcast, each re-reading on every post. Lost on depth.
- **One `.swipe(.began(kind))` event and one model handler.** One fewer enum case, but every phase in the model then
  branches on what is open, and every `.began` site in the tests changes. Lost on reader load.
- **A second recognizer state or recognizer for vertical slides.** Duplicates rejoin, cancel, thumb and blocking, and
  makes two places decide direction (`why.md` Avoid 1). Rejected.
- **Raises on a serial background queue, or an async window read.** The main actor would never wait on another app,
  but the model would gain a loading state and a lift that can arrive before the read lands. For a read of about a
  millisecond, bounded timeouts instead.
- **Change 1: read the windows on the frame thread at the start frame.** The recognizer would decide on the very frame,
  with no answer and no unconfirmed state, and blocking would start on time. But the frame thread would make AX calls
  into another app, waiting up to the 0.2 s timeout with every trackpad's recognition stalled; `FrontmostAppWindows`
  and its raise handles would be shared across threads; the touch adapter would depend on the window reader and the
  read would ride a touch event to the model. Lost on locality and on the frame thread's promise never to wait.
- **Change 1: a window count the frame thread reads, kept current by pushes.** Accessibility observers on the
  frontmost app for windows created, closed, minimised and restored, plus activation and Space notifications. No round
  trip, but no push exists for a window entering full screen or moving Space, Chromium and Electron trees are
  unreliable observers, a read would run on every window change even when no slide happens, and a pushed count could
  disagree with the begin read's rows, which R1 forbids. Rejected.
- **Change 1: read when the pair lands, decide at the start.** The answer would usually be ready before the start
  frame, but a pair may rest for seconds (R1 has no time limit), so the count would not be the one at the decision
  (R13), and every 2-finger tap under the thumb would pay a read. Rejected.
- **Change 1: start blocked, and release on a decline.** Simpler blocking, but the scroll filter never relaxes a
  scroll it has stilled, so a declined slide after the blocking window would stop scrolling (R13's "One window scrolls
  after the blocking window"), and presses in the gap would be withheld. Rejected.
- **Change 1: the answer as `onEvent`'s return value, or as a reply handle inside the event.** Both enforce the reply by
  type, but the first gives every event a result only one ever has, and the second puts a capability in a domain value
  that tests also inject. One `confirmWindowSwipe(on:)` with the adapter guaranteeing the reply after `onEvent` keeps one
  handler and one event shape; its timing rule is stated on the port. Lost narrowly.

### Open questions and risks

1. Does vertical pointer acceleration use the same multiplier on `dy` (O1)? The sketch assumes symmetry; the first
   hardware check should compare a vertical slide's feel with a sideways one at the same tracking speed.
2. A minimised window may belong to another Space, and restoring it on the lift may switch Spaces (F24). Is that
   acceptable because the user picked that window?
3. Answered by change 1: one minimised window and nothing else is no window swipe (R13's "Only window minimised",
   the Non-goal); R11's all-minimised rule holds from two minimised windows.
4. Edge readings of R11 and R12 the design makes, for you to confirm: when the front window closes mid-swipe and the
   user lifts on its row, the haptic plays because another window is now in front; when every listed window has
   closed, the lift is silent; when the app opens a window in front mid-swipe, the lift brings the selected window back
   above it and leaves the new window just behind, above the other listed windows (R3 does not list it, so R11's order
   binds only the listed ones); when another app is in front at the lift, nothing is raised. And R11's "Lifting on the
   front window MUST change nothing" is read as "leaves the windows as they were before the window swipe": after
   sliding away and back, the lift raises windows to restore that order, silently. T49(b) and T52(b) flip if you
   answer otherwise.
5. Is 0.2 s the right AX messaging timeout? Apps whose accessibility tree wakes on the first query (Chromium, O5) may
   read as having no windows on the first slide down, which is then no window swipe and scrolls after the blocking
   window.
6. Since macOS 15, capture without the system picker can bring a periodic system alert (F31). Acceptable for a few
   pictures per window swipe, or should previews wait for a product decision?
7. If macOS needs a relaunch after the grant (F30), the hint stays until the relaunch. Acceptable under R8?
8. Without Accessibility, thumb plus two fingers sliding up or down may open Mission Control, since Dock-swipe blocking
   needs the event tap (`why.md` Risk 2). It is no window swipe then, so it does what it does with the setting off.
   Should R14 say so?
9. Two-finger taps that drift up or down past 3 mm over an app with two or more windows will flash the window
   switcher, as sideways drift already flashes the app switcher (`why.md` Risk 3); three-finger taps never start one.
10. Should the launcher window's gesture hint mention the window swipe? The design leaves it unchanged.
11. `AXRaise` restoring a minimised window was probed on TextEdit only, and the source policy bans attribute writes; an
    app whose raise does not restore would need that ban lifted deliberately.
12. R15's scenario "Click reaching apps cancels" cannot happen on hardware as written: raising "Mail" needs
    Accessibility, and with Accessibility every press during a confirmed window swipe is blocked, so none reaches apps;
    without it there is no window swipe (R14). A click can reach apps only in the frame between a window swipe's start
    and its blocking, after the 3 s blocking window, before any row but the first is selected. The cancel rule itself
    stands and is tested through that click (T35), a third finger after raises (T56) and the recognizer (T10). Should
    the scenario be reworded?
13. The real adapter's messaging timeout and its stop after a timed-out raise have no automated test: faking the AX
    calls would test our model of the Accessibility API rather than the API, so they are checked by hand (M18), and the
    model's handle on an app that does not answer is `FakeWindows.answers`. Acceptable?
14. Change 1: a window swipe blocks from the frame after its start (about 10 ms later), so after the 3 s blocking
    window a scroll or press in that one frame reaches apps, and the press cancels the window swipe (Tradeoffs). The
    alternative, blocking on the start frame, would make a declined slide stop scrolling, which R13 forbids. Acceptable?
15. Change 1: a hung frontmost app delays the decision by up to the 0.2 s messaging timeout, and one that hangs
    partway through the read can show a switcher past R1's 50 ms. Acceptable as a degraded case, or should R1 name it?
16. Change 1: with a switcher already up on one trackpad, a slide down on another trackpad over an app with two or more
    windows is confirmed and blocks until it lifts, with no switcher of its own, as that trackpad's swipe would. Is a
    blocked slide with nothing on screen the behaviour you want there, or should it be declined and scroll?
17. Change 1: R13's "a haptic MUST NOT play" is read as "the slide itself plays none". A thumb tap under the declined
    slide's resting fingers is a swap with its gesture haptic, as it is with the window swipe setting off, which R13
    also asks for (T70's hand h4). Is that the reading you meant?

### Next implementation step

S1 to S4 are built. Next is slice S5, the change-1 prefactor with no visible change: the recognizer's unconfirmed
window swipe and `answerWindowSwipe(began:isWindowSwipe:)` test first (T67), `WindowSwipeConfirmation` (T73), the
`DeviceSession` reply and answer slot (T68), `TrackpadHardware.confirmWindowSwipe(on:)` in both adapters through the
confirmation, the drivers' `answering:` default, and the model confirming every start, so the existing suite keeps its
meaning with T11 moved to the frame after the start.

## Testing Decisions

### Strategy

The window swipe is proven at the five places the swipe already is, with one fake added inside an existing in-memory adapter and no new port, seam or test target.

- **World** (`LauncherKit/Tests/LauncherCoreTests/World.swift`) carries most rows: the real `Launcher`, the real recognizer, click filter and scroll filter inside `InMemoryTrackpads`, a throwaway settings suite. It observes what the user would: `launcher.windowSwitcher` and `launcher.switcher` frame by frame, the haptic pulses in order, the press and scroll verdicts, the hint, the store, and the fake window stack with its log of raises and reads. It misses the AX adapter, the panel, the presenter and capture. New rows resemble `SwitcherOnScreenTests.swift`, `ScrollSuppressionTests.swift`, `SwipeSettingTests.swift`, `PersistenceTests.swift` and `AccessibilityTests.swift`.
- **The recognizer over scripted frames** (`TouchScript`, `HandFrames`, the drivers in `Fixtures.swift`), for what only the frame thread decides: the direction, the travel along the slide and the blocking flags on every frame. It is the only seam where a wrongly emitted phase shows, because the model's begin guard (`shown == nil`) would hide a stray `.swipe(.began)` during a window swipe. Rows resemble `SwipeRecognizerTests.swift`, `SwipeTravelAndExitTests.swift` and `EdgeContactRecognizerTests.swift`.
- **Pure values in `LauncherCore`**, only where World cannot reach: `WindowColumnLayout` (only the shell reads it), the pointer curve's vertical component (World runs `.linear` travel), the badge and hint copy. Like `SwitcherRowLayoutTests.swift`, `PointerCurveTests.swift` and `CopyTests.swift`. The existing `SwitcherTests.swift` rows move onto `SwitcherSelection` unchanged and keep the exact 6 mm boundary.
- **`LauncherPlatformTests`**, for the three adapter internals the design gives a handle: `FrontmostAppWindows.sort` and `number(of:among:)` over raw facts copied from the probes' printed output; `SystemPermissions` over injected reads and a really posted `com.apple.tcc.access.changed`, like `SystemPermissionsTests.swift` (named `SystemAccessibilityPermissionTests.swift` before S1); `DeviceSession.receive` over two sessions, which proves the frame thread installs cursor travel when a window swipe begins.
- **The source scan** (`SourcePolicyTests.swift`) gains confined and banned rows.

Faked, and only these boundaries:
- *The frontmost app's windows.* `FakeWindows`, held by `RecordingSystemActions` as `windows`, does what probe 2 printed `AXRaise` doing: `raiseWindows` raises its ids last first, each to the front, restoring a minimised one and skipping closed ids and ids the latest read did not list; `frontmostWindows()` answers `.noApp` while `frontmost` is nil, otherwise `.app(frontmost, visible:, minimised:)` from the stack (the stack belongs to whichever app is frontmost). Handles: `set(visible:minimised:fullScreenFront:)` by title (one fixed id per title; `World.window(_:)` returns it), `open(_:)` (a new window in front), `close(_:)`, `answers = false` (reads list nothing and raises change nothing: an app that does not answer), `dropsRaises` (raises are logged and change nothing: an app that ignores them), `onScreenTitles`, `minimisedTitles`, `raised` (every call in order, empty ones included) and `reads`.
- *The permissions.* `InMemoryPermissions` replaces `InMemoryAccessibilityPermission` and `World.permissions` replaces `access`: `set(_:granted:)` changes a grant and pushes only on a change; `set(_:granted:push: false)` changes it silently (a withheld TCC broadcast); `asks` lists each `ask(_:)`; `onAsk` runs inside `ask`, so a row can read the store at that moment.
- *The trackpads and the clock.* `InMemoryTrackpads` as today. The design adds no timer or poll; its one deadline, the AX messaging timeout, lives inside the system call and is checked by hand (M18). The only clock a test owns is `TouchScript`'s frame clock (10 ms frames), and rows about the 3 s blocking window and the 400 ms tap window advance it past them (`wait(.seconds(4))`). The one wait in the suite is the platform row's bounded wait for the real TCC broadcast, as the existing adapter test does.

Helpers: every recognizer driver takes `slides:` (default both kinds, the shipped default); `windowPhases(_:handMode:surface:slides:)`; `perFrame` returns `(swipe, windowSwipe, blocks)`. World gains `windowWorld(visible:minimised:fullScreenFront:frontmost:accessGranted:screenRecording:)` (started; Safari frontmost and both permissions granted unless a row says otherwise), `windowSwipe(_ slidesMM: Double..., lift:)` (thumb at (10, 10), two fingers, each slide straight down, positive down; returns its script) and `playFrameByFrame(_:)`, which delivers one frame at a time and records `(windowSwitcher, switcher)` after each, so the "at no moment" and "on every frame" rows check the whole history.

Not tested by code: everything in `LauncherUI` (no test target: the panel, the presenter, capture, the hint view, the switch row), the real AX adapter talking to other apps (raise, restore, focus, Spaces, the messaging timeout), ScreenCaptureKit, the TCC prompt and the System Settings page, and haptics on hardware. Each is under Verified without a test with exact steps.

**Change 1.** The same seams prove that a slide up or down is a window swipe only over two or more windows with Accessibility, and is otherwise exactly the setting-off slide; no new seam, port or fake.

- **World** carries the product rules. Its oracle for R13 and R14's "exactly as with the window swipe setting off" is a second world built the same way with the setting off, played the same hand frame by frame: that world's behaviour is today's, pinned by T37 and the pre-plan rows, so the expected values come from it, never from the decline code. A probe after every frame, an unphased scroll (decided on the merged blocking flag alone, with no state of its own), makes the per-frame blocking visible at World; press verdicts, pulses, apps brought to front, raises and fired gestures are compared at the end. `InMemoryTrackpads` answers each start the way the real adapter does, once `onEvent` returns and before the next frame, and logs it in `windowSwipeAnswers`, so rows can say a start was confirmed or declined. New rows resemble `WindowSwitcherOnScreenTests.swift`, `WindowSwipeBlockingTests.swift` and `AccessibilityTests.swift`.
- **The recognizer** carries the answer protocol, the one place where a late, missing, stale or second answer can be fed: World's in-memory adapter always answers before the next frame, and only the real adapter can lag. Its reference is the setting-off recognizer: `slides: [.swipe]`, or `[]` beside `[.windowSwipe]` when the swipe setting is off too. The drivers in `Fixtures.swift` take `answering: Bool?`, default true (every start confirmed before the next frame), so every existing recognizer row keeps its meaning; nil leaves starts unanswered. Rows resemble `WindowSwipeRecognizerTests.swift`.
- **`LauncherPlatformTests`** carries the hop's frame-thread half: `DeviceSession` delivers a start with its reply and hands the slot to the recognizer before the next step, observed through `blocksClicks` as the click tap reads it, like `DeviceSessionTravelTests.swift`. The main-actor half is `WindowSwipeConfirmation` in `LauncherCore`, which both adapters run, so every World row exercises it; what is left in `MultitouchTrackpads` is wiring that needs real devices, checked by code review (M21).
- **Pure values**: the Accessibility hint's copy, and `WindowSwipeConfirmation` driven directly for the edges no model produces, like `CopyTests.swift` in shape.

Nothing new is faked: the window reads are `FakeWindows` as before, and the answer protocol runs for real inside both adapters.

### Test scenarios

| ID | Requirements | Seam | Given / When / Then | Source of truth for the expected value |
|----|--------------|------|---------------------|----------------------------------------|
| T1 | R9 | Pure: `PointerCurve`, `SwipeTravel` | Given the built-in curves at the default tracking speed. When `cursorMove(dxMM: 0, dyMM: 25.4 / 400, interval: 1 / 120)`, `cursorMove(dxMM: 3, dyMM: 4, …)` and `cursorMove(dxMM: 5, dyMM: 0, …)`. Then the first's y is f(67/400) × 96/67 and its x is 0; the diagonal's x : y is 3 : 4 and its length equals the 5 mm sideways move's x; `.cursor(curve, pointsPerStep: 100).travel(along: .windowSwipe, dxMM: 0.3, dyMM: -3, …)` is that move's y points × 0.12, negative; `.linear.travel(along:dxMM: 3, dyMM: 9, …)` is 9 for `.windowSwipe` and 3 for `.swipe`. | IOHIDFamily's acceleration formula as hand-computed in `PointerCurveTests`; R9 "100 points" per row = 12 step mm; open question 1's symmetry assumption. |
| T2 | R1 | Recognizer | Given a thumb at (10, 10) and two fingers. When they slide straight down, and in a second argument up, by 2.9 mm or 3.1 mm within 100 ms, then lift. Then at 2.9 there is no window swipe phase and `fired == [.two]`; at 3.1 the first window swipe phase is `.began`, nothing fires and no swipe phase appears. | R1 "one of them moves more than 3 mm". |
| T3 | R1, R9 | Recognizer | Given right hand (thumb x 10) and left hand (thumb x 114.8 on the MacBook, 150 on the Magic Trackpad), on both surfaces. When a window swipe begins with 3.5 mm down, then slides 12 mm down, or 12 mm up, then lifts. Then the last `.moved` travel is 12.35, or −11.65; the last phase is `.ended`; no swipe phase. | R9 "Sliding down MUST move it to the next row ... in both hand modes" and "the 3 mm that start it do not count"; the sideways row's 12.35 and −11.65 in `SwipeTravelAndExitTests` (0.35 mm of the 3.5 mm slide comes after the begin frame). |
| T4 | R1, R2 | Recognizer | Given both kinds on. When a pair slides (2.9, 3.0), (3.0, 2.9) or (3.0, 3.0) mm, then 20 mm down, then lifts, then taps two fingers. Then (2.9, 3.0) gives window swipe phases only; (3.0, 2.9) swipe phases only; the tie neither, the 20 mm down begins nothing, and the 2-finger tap after the lift fires `.two`. | R1 "more up or down than sideways"; R2 "The first movement past 3 mm MUST decide"; strict, as today's sideways row. |
| T5 | R1 | Recognizer | Given two fingers resting 2 s, and 4 s, under the anchored thumb. When they slide 5 mm down. Then a window swipe begins in both and nothing fires. | R1 "There MUST be no time limit". |
| T6 | R1 | Recognizer | Given an anchored thumb. When (a) one finger, (b) three fingers slide 20 mm down; (c) two fingers land, the thumb anchors 50 ms later, and the fingers slide 20 mm down (hand frames). Then no window swipe phase in any, and a 1-finger tap afterwards fires `.one`. | R1 scenarios "Fingers first, then thumb" and "Three fingers". |
| T7 | R1 | Recognizer | When (a) a finger and an edge contact in the bottom band slide 10 mm up together under the thumb; (b) an edge contact lands during a window swipe; (c) a window swipe finger lifts, then an edge contact lands. Then (a) no window swipe; (b) no `.cancelled` and the travel goes on; (c) the edge contact does not rejoin: the travel follows the remaining finger and `.ended` comes with its lift. | R1 "Edge contacts ... MUST neither start nor join a window swipe"; glossary *Edge contact*; the swipe rows in `EdgeContactRecognizerTests`. |
| T8 | R2 | Recognizer, every frame | When (a) a window swipe begins with 3.5 mm down, drifts 20 mm sideways, slides 12 mm down and lifts; (b) a swipe begins with 3.5 mm right, drifts 20 mm down, slides 12 mm right and lifts. Then over every frame (a) has no `.swipe` phase and its last travel is 12.35 (the drift adds nothing); (b) has no `.windowSwipe` phase and its last travel is 12.35. | R2 "A window swipe MUST never turn into a swipe, nor a swipe into a window swipe". |
| T9 | R1, R15 | Recognizer, per kind | When each existing `.swiping` row runs once per kind, the slide turned vertical for the window swipe: the thumb lifts and lands again mid-slide; the thumb rolls out of the corner; the thumb lifts and stays away; one finger lifts and the other keeps steering; a finger drops out and returns with a new id; the whole hand lifts at once. Then each gives the swipe row's phase sequence and travel values in its own event case, no `.cancelled`, and the tap after it fires as in the swipe row. | R15 "as in a swipe"; R1 "the thumb may stay, lift, leave the corner or land again, and nothing MUST change"; the worked phases in `SwipeTravelAndExitTests`. |
| T10 | R15 | Recognizer, hand frames | Given a window swipe. When a third finger lands outside the corner while both are down; a press frame is sampled `.click`; a press is sampled `.blocked`; a third finger lands on the frame both fingers lift; a click comes on the frame both lift. Then `[.began, .cancelled]`; `[.began, .cancelled]`; the travel goes on to `.ended`; `[.began, .ended]`; `[.began, .cancelled]`; after each cancel nothing until the fingers lift, then a tap fires. | R15 "cancelled when a third finger lands outside the anchor corner while both are down, or a click reaches apps"; the interleavings recorded for the swipe in `SwipeTravelAndExitTests`. |
| T11 | R15 | Recognizer, every frame | When window swipes begin 4 s after the thumb landed, with the thumb lifting and landing again, or rolling out of the corner, mid-slide, each start confirmed before the next frame. Then on the `.began` frame `blocksClicks` is false and `blocksDockSwipes` is true (the thumb rules: the thumb is anchored and other fingers are down); both are true on every frame after it up to the frame before `.ended`; `blocksClicks` is false from `.ended` on. | R15 "the blocking window is held open until both fingers lift"; glossary *Blocking window*; the design's answer rule (a window swipe blocks from the frame after its start; the start frame blocks as the setting off would). |
| T12 | R16 | Recognizer | When the same hands run with `slides` `[]`, `[.swipe]`, `[.windowSwipe]` and both: a pair sliding 20 mm down; 20 mm right; resting 1 s then sliding down; each followed by a 2-finger tap. Then `[]`: no phase of either kind and the resting pair never begins; `[.swipe]`: the vertical slides spoil, and today's vertical-spoil rows pass unchanged under it; `[.windowSwipe]`: the sideways slide spoils and the next tap fires, while both vertical hands begin; both: each hand begins its own kind. | R16 "a slide's direction rules MUST be exactly today's"; the pre-plan rows in `SwipeRecognizerTests` as the record of today. |
| T13 | R5, R6 | Pure: `WindowColumnLayout` | When (a) `previewSize(aspect:)` at scale 1 for aspects 2, 1.6, 3 and 0.5; (b) a 10-row layout at H, the full-size column's panel height plus a margin above and below, and at H − 1; (c) `previewPixels(scale: 2)` at scale 1. Then (a) 120 × 60, 96 × 60, 120 × 40, 30 × 60; (b) scale 1 at H; at H − 1 scale below 1, the panel height plus two margins at most H − 1 and above H − 2, and `pitch` and `previewSize` shrunk by that same factor; (c) 240 × 120. | R6 "60 points tall, keeping the window's proportions, at most 120 points wide"; R5 "the rows MUST shrink by one factor so the whole column fits"; probe 3's 240 × 120 px capture box. |
| T14 | R4 | Pure: `Copy` | When `Copy.minimisedBadge` is read. Then "Minimised". | R4 "a "Minimised" badge". |
| T15 | R3, R4 | Platform: `FrontmostAppWindows.sort` | Given raw facts from the probes. When sorted: (a) probe 2 after its minimise: Gamma 6863 and Alpha 6865 (AXWindow, AXStandardWindow), Beta 6864 (AXWindow, AXDialog, minimised), on screen [6863, 6865]; (b) the same with the AX list in the order Alpha, Gamma; (c) probe 5's full-screen Space: an untitled AXUnknown 6903 and Beta 6895 (AXStandardWindow, full screen), both on screen; (d) a standard window neither on screen nor minimised; (e) on-screen AXFloatingWindow, AXSystemFloatingWindow and AXDialog windows; (f) a window with no number; (g) two minimised windows. Then (a) visible [Gamma, Alpha], minimised [Beta]; (b) the same, in the window list's order; (c) visible [Beta], full screen; (d), (e), (f) left out; (g) in AX order. | probe-2 and probe-5 outputs (F9, F10, F11); R4's exclusions. |
| T16 | R3, R4 | Platform: `FrontmostAppWindows.number(of:among:)` | Given probe 2's window list: 6863 at (210, 131), 6864 at (181, 102), 6865 at (152, 73), each 656 × 422 and named. When Alpha (152, 73, 656 × 422, "Alpha.txt") is matched: as listed; with every name absent; against two unnamed entries at its frame; against two entries at its frame named "Alpha.txt" and "Other"; with no entry at its frame; with no frame. Then 6865; 6865; nil; 6865; nil; nil. | probe-2 output; `docs/architecture.md` Privacy "a window that matches none is not listed" (F12). |
| T17 | R9 | Platform: `DeviceSession.receive` | Given two sessions on the built-in curves, each recognizer for both kinds starting `.linear`. When hand-built 10 ms frames slide session A's fingers 3.5 mm then 12 mm down and session B's the same distances right at the same times. Then every `.windowSwipe(.moved)` travel A delivers equals B's `.swipe(.moved)` travel on the same frame, within 1e-9. | R9 "as the cursor would travel ... with macOS's own pointer acceleration"; the swipe's cursor travel as the reference; open question 1. |
| T18 | R3, R4 | Source scan | When the sources are scanned. Then `AXUIElement` and `CGWindowList` appear only in `FrontmostAppWindows.swift`, comments included. | `docs/architecture.md` Privacy: the Accessibility element API with the window list confined to one file. |
| T19 | R1, R3, R6 | World, frame by frame | Given Safari frontmost with windows, front to back, "Docs", "Mail", "News". When the thumb anchors and two fingers slide 5 mm down, one frame at a time. Then before the crossing frame `windowSwitcher` is nil and nothing was read; on the frame the window swipe begins, rows read "Docs", "Mail", "News", the first is selected, `frontWindow` is Docs, `app` is Safari, `switcher` is nil, `reads == 1` and the start is answered true (`windowSwipeAnswers == [true]`). | R3 scenario "Front-to-back order"; R6 "The switcher MUST appear in the same movement that starts the window swipe"; R1 scenario "Slide down starts a window swipe". |
| T20 | R5, R17 | World, frame by frame | Given Safari frontmost with three windows. When a window swipe slides 24 mm down and 12 mm up and lifts, one frame at a time, and a second window swipe follows under the same thumb. Then `windowSwitcher` is non-nil on every frame from the begin frame to the frame before the lift and nil from the lift frame on; its `serial` is the same on every frame of one window swipe and larger on the second. (Change 1 drops the old no-windows, no-app and no-Accessibility worlds: T69, T70 and T72 cover them.) | R5 "MUST disappear when the window swipe ends"; R17 "discarded when the window swipe ends" (the presenter drops pictures on nil and on a new serial). |
| T21 | R3 | World | Given (visible, minimised) counts (14, 0), (10, 0), (11, 0), (9, 3) and (0, 12), titled W1, W2, … in order. When a window swipe begins. Then the rows are the 10 frontmost; all 10; the first 10; the 9 visible then the first minimised; the first 10 minimised in the app's order. | R3 "cut the list at 10", scenario "More than 10 windows"; R4 "Minimised windows MUST come after the visible ones". |
| T22 | — | — | Retired by change 1 (S6): a full-screen front window is no window swipe, so there is no one-row switcher to rubber-band; T69 and T70 prove what replaced it. | — |
| T23 | R3 | World | Given a window swipe on "Docs", "Mail". When mid-swipe the app opens "Draft", "Mail" closes and Notes becomes the frontmost app, and the fingers slide on. Then the rows still read "Docs", "Mail" and the selection still follows. | R3 scenario "Window opens during the window swipe"; R3 "one that closes stays listed". |
| T24 | R4 | World | Given Finder frontmost with two visible windows and one minimised. When a window swipe begins. Then three rows, the minimised one last as `Row.minimised` with its title, the other two `Row.visible`. | R4 scenario "Minimised window". |
| T25 | R6 | World | Given Preview frontmost with (a) two untitled windows, (b) "Notes.pdf" then an untitled window. When a window swipe begins. Then (a) "Preview — Window 1", "Preview — Window 2"; (b) "Notes.pdf", "Preview — Window 2". (Change 1 drops the one-untitled-window case: one window is no window swipe.) | R6 scenario "Untitled windows"; R6 "followed by " — Window N", N being its position in the list". |
| T26 | R9, R12 | World | Given "Docs", "Mail", "News". When a window swipe begins with 3.5 mm down and slides until the travel after the begin frame is 5.9 mm, then 6.1, then 18.1, then back up 12; and, in a second world, slides 24 mm within one frame. Then 5.9: first row, no tick; 6.1: second, one tick; 18.1: third, two ticks; back up: second, three ticks; the one-frame slide: third row and two ticks on that frame. | R9 "one row for every 100 points" (12 step mm under `.linear`) and "the selection changes halfway to the next row"; R12 "one light tick"; glossary *Light tick* "one per icon or row the highlight crosses". |
| T27 | R9 | World | Given two windows. When a window swipe reaches the second row, pushes 30 mm further down, turns up 5.9 mm, then 0.2 mm more; and, in a second world, pushes 30 mm up from the first row and turns down 6.1 mm. Then past the bottom the second stays selected with `stretch` above 0 and no further tick; after 5.9 mm up still the second; after 6.1 mm up the first, with one more tick. Past the top `stretch` is below 0, and 6.1 mm down selects the second. | R9 scenario "Turning back at the end" ("after half a row of travel up, not more"); glossary *Switcher* rubber band. |
| T28 | — | — | Retired by change 1 (S6): one window is no window swipe, so there is no one-row switcher; T70 proves what replaced it. | — |
| T29 | — | — | Retired by change 1 (S6): no windows, no frontmost app or an app that does not answer make no window swipe and no "No open windows" row; T69 and T70 prove what replaced it. | — |
| T30 | — | — | Retired by change 1 (S6): without Accessibility there is no window swipe and no Accessibility row; T72 proves what replaced it. | — |
| T31 | R2 | World, frame by frame | When (a) a window swipe on "Docs", "Mail", "News" reaches Mail, then the fingers drift 20 mm sideways; (b) an app switcher swipe reaches Mail, then the fingers drift 20 mm down. Then over every frame (a) `switcher` is nil and the window switcher stays on Mail with no further tick; (b) `windowSwitcher` is nil and the app switcher stays on Mail. | R2 scenarios "Sideways wobble during a window swipe" and "Vertical drift during a swipe". |
| T32 | — | — | Retired by change 1 (S6): a slide down over an app with no windows is no window swipe and no longer runs its course blocked; T70 proves what replaced it. | — |
| T33 | R15 | World | Given Accessibility. When (a) a fresh thumb's window swipe slides 3.5 + 12 mm down and lifts; (b) with the thumb rested 4 s, the fingers move 2 mm down, then 10 mm more, then lift with a press. Then (a) a scroll's may-begin, changed, ended and momentum are all dropped, and a new scroll after the lift passes; (b) a scroll beginning before the window swipe passes, its changed, ended and momentum pass stilled, and both press edges are dropped. | R15 scenario "No scroll under a window swipe"; glossary *Click blocking*. |
| T34 | R1, R15 | World | Given a window swipe on "Docs", "Mail", "News" at Mail. When the thumb lifts and the fingers slide 12 mm on; then one finger lifts and a new finger lands while the other is down, and they slide 12 mm up. Then the window switcher stays throughout, News is selected after the thumbless slide, and Mail after the rejoined slide. | R15 scenarios "Thumb lifts mid-swipe" and "Finger rejoins". |
| T35 | R15 | World | Given Accessibility, Notes on the 1-finger gesture and "Docs", "Mail", "News". When (a) with the thumb rested 4 s, a window swipe starts and a press comes on the very next frame, the fingers slide on and lift, then a 1-finger tap; (b) a press is held while a window swipe slides from Mail to News, then the fingers lift. Then (a) the press passes (its edge is decided on the start frame's flags, which block nothing 4 s after the thumb landed), the window switcher is gone on that frame with no pulse, nothing more happens until every finger lifts, and the tap's gesture fires; (b) both press edges are dropped and the window switcher stays and follows to News. | R15 "It MUST be cancelled when ... a click reaches apps"; the design's blocking from the frame after the start (open question 14); glossary *Click blocking*. |
| T36 | R15, R16 | World | Given a window swipe at Mail. When (a) `setWindowSwipe(on: false)`, (b) `setSwipe(on: false)`, (c) the Mac wakes; then the fingers slide on and lift; then a 1-finger tap. Then `windowSwitcher` is nil at once; the slide and lift give no tick, no pulse and no further read; the tap fires its gesture. | R16 "A change MUST apply to the next slide"; `aReconcileMidSwipeRemovesTheSwitcher…`. |
| T37 | R16 | World | Given Accessibility and the window swipe setting off. When (a) with a fresh thumb two fingers slide 20 mm down; (b) with the thumb rested 4 s, the same with a press. Then no window switcher in either; (a) the scroll is dropped; (b) the scroll and both press edges pass; `reads == 0` and no pulse. | R16 scenario "Setting off"; `withTheSwipeOffASlideShowsNothingAndScrollsOnlyAfterTheBlockingWindow`. |
| T38 | R16 | World | When (a) with the swipe off and the window swipe on, a vertical and a sideways slide; (b) with the window swipe off and the swipe on, a sideways slide; (c) the window swipe setting toggled off and on; (d) with the window swipe off, a swap. Then (a) the window switcher for the vertical slide and no switcher for the sideways; (b) the app switcher; (c) `isSwipeOn` and `isSwapOn` unchanged; (d) Mail comes to the front. | R16 scenario "Swipe setting off, window swipe on"; R16 "independent of the swipe and swap settings". |
| T39 | R16 | World and store | When (a) first launch; (b) the setting is turned off and the app relaunched; (c) the frozen `savedSettings` record (swipe off, no window swipe key) loads; (d) the plan 002 record loads; (e) every settings field with `isWindowSwipeOn` false goes through the store; (f) a record holding only `isWindowSwipeOn` false loads. Then (a) on; (b) off; (c) on, with the swipe still off and every other value as recorded; (d) on; (e) equal; (f) every other field at its default. | R16 scenarios "Survives a restart" and "Upgrade with the swipe setting off"; the frozen records, never regenerated. |
| T40 | R1, R2 | World, two trackpads | Given the MacBook and the Magic Trackpad, and "Docs", "Mail", "News". When (a) a window swipe on the MacBook selects Mail and the Magic Trackpad injects `.swipe(.began)`, `.windowSwipe(.moved(24))`, `.windowSwipe(.ended)` and `.windowSwipe(.cancelled)`; (b) an app switcher is up on the MacBook and, on the Magic Trackpad, the thumb anchors and two fingers slide 20 mm down, frame by frame. Then (a) no app switcher, Mail still selected, no further tick, and the MacBook's lift ends it; (b) no window switcher on any frame, the app switcher stays as it was, and the Magic Trackpad's start is read once and answered true, so it runs its course blocked with no switcher of its own. | R1 "The start rules MUST otherwise match the swipe's" (one switcher at a time; a second trackpad's swipe runs its course unseen); `aSwipeOnASecondTrackpadWhileOneSwitcherIsUpIsIgnored`; open question 16. |
| T41 | R1 | World | Given Tap to click on, so gestures are inactive. When two fingers slide down under the thumb, and then an in-flight `.windowSwipe(.began)` is injected. Then no window switcher and nothing read. | R1 "While ... gestures are active"; glossary *Gestures active / inactive*. |
| T42 | R1 | World, frame by frame | Given Mail on the 2-finger gesture. When the thumb anchors and two fingers tap, drifting 2 mm down before lifting. Then Mail comes to the front with the gesture haptic, `windowSwitcher` is nil on every frame and nothing is read. | R1 scenario "A tap that drifts stays a tap". |
| T43 | R1, R9 | World | Given Left hand and "Docs", "Mail". When the thumb anchors at (114.8, 10) and two fingers slide 3.5 mm, then 12 mm down. Then the window switcher appears and Mail is selected with one tick. | R1 scenario "Left-hand mode"; R9 "in both hand modes". |
| T44 | R10 | World | Given "Docs", then "Mail". When a window swipe slides one row down, then back up. Then before any lift Mail leads the stack and `raised == [[Mail]]`; after sliding back Docs leads and `raised == [[Mail], [Docs]]`. | R10 scenarios "Live switch" and "Slide back". |
| T45 | R10 | World, frame by frame | Given A and B visible and M minimised. When a window swipe slides onto M, then back to A. Then over every frame `raised` never names M, M stays minimised, and the stack does not change between reaching B and reaching M. | R10 scenario "Passing a minimised window"; R10 "Selecting a minimised window MUST NOT restore it while sliding". |
| T46 | R10 | World | Given "Docs", "Mail", "News" and a window swipe at Mail. When News closes and the fingers slide onto its row. Then the stack stays [Mail, Docs], the move ticks once, and the rows still list News. | R10 "Selecting a window that has closed MUST change nothing on screen"; R3 "one that closes stays listed". |
| T47 | R10, R11, R12 | World | Given the launcher window open and Finder with only X and Y, both minimised. When (a) a window swipe slides to Y and back to X and lifts; (b) slides to Y and lifts. Then nothing is raised while sliding; (a) X is restored and in front, Y still minimised, the gesture haptic plays and the launcher window closes; (b) Y is restored and in front. (Change 1 drops the one-minimised-window case: it is no window swipe, T69.) | R11 scenario "Every window minimised"; R10 "When there is no front window, sliding back to the first row MUST change nothing"; R12. |
| T48 | R11, R12 | World | Given the launcher window open and "Docs", "Mail", "News". When a window swipe slides 24 mm down and lifts, then a second window swipe begins under the same thumb. Then the stack is [News, Docs, Mail]; the pulses are light tick, light tick, gesture; no launch animation; the launcher window is closed; the second window swipe's rows read "News", "Docs", "Mail", with News selected. | R11 scenario "Toggle between the last two windows"; R12 scenario "Lift on another window". |
| T49 | R5, R11, R12 | World | Given the launcher window open. When (a) on "Docs", "Mail", "News" a window swipe lifts without leaving the first row; (b) it slides 24 mm down within one frame and 24 mm up within one frame (stack [Docs, News, Mail]) and lifts. Then (a) every `raised` call is empty, no gesture haptic, the launcher window stays open; (b) the stack is [Docs, Mail, News], silent, the window open. (Change 1 drops the full-screen and one-window cases: neither is a window swipe, T69 and T70.) | R11 "Lifting on the front window MUST change nothing and be silent" and its order rule; R5 scenario "Focus stays put"; open question 4 for (b) ("the lift raises windows to restore that order, silently"). |
| T50 | R11, R12 | World | Given A and B visible and M minimised. When a window swipe slides onto M and lifts. Then M is restored and in front, the stack is [M, A, B], and the gesture haptic plays. | R11 scenario "Lift on a minimised window" and its order rule. |
| T51 | R11, R12 | World | Given "Docs", "Mail", "News". When (a) a window swipe slides to Mail, Mail closes (Docs leads again) and the fingers lift; (b) it slides 24 mm down and 12 mm up (stack [Mail, News, Docs]), Mail closes and the fingers lift. Then the lift's raise call is empty in both; (a) the stack is [Docs, News] and the lift silent; (b) the stack is [News, Docs] and the gesture haptic plays. | R11 scenario "Selected window closes". |
| T52 | R11, R12 | World | Given "Docs", "Mail", "News". When (a) a window swipe slides to Mail, the app opens "Draft" in front, the fingers lift; (b) no slide, "Draft" opens in front, the fingers lift. Then (a) the stack is [Mail, Draft, Docs, News] and the gesture haptic plays; (b) the stack is [Docs, Draft, Mail, News], silently. | R11 "the selected window, then the front window, then the others in their order from before" for the listed windows; open question 4 ("leaves the new window just behind, above the other listed windows") for where Draft lands and for (b)'s silence; check-2's worked stack. |
| T53 | R11 | World | Given "Docs", "Mail", "News". When the fake drops raises (`dropsRaises`) while a window swipe slides to Mail, so Docs still leads; then raises work again; the fingers lift. Then the stack is [Mail, Docs, News], `reads == 2`, and the gesture haptic plays. | R11 order rule; the design's Risk 4 ("the lift must not depend on what the raises while sliding did"). |
| T54 | R11, R12 | World | Given the launcher window open and a window swipe at Mail. When (a) the app stops answering; (b) Notes becomes the frontmost app; (c) every listed window closes; then the fingers lift. Then the lift's raise call is empty, no gesture haptic, and the launcher window stays open. | R11 "Lifting on a window that has closed MUST leave the windows as they are"; R12's haptic rule; the design's degraded cases. |
| T55 | — | — | Retired by change 1 (S6): with no windows, no frontmost app or no Accessibility there is no window swipe and so no lift; T70 and T72 prove those slides change nothing and pulse nothing. | — |
| T56 | R15 | World | Given Accessibility and "Docs", "Mail", "News". When a window swipe slides 24 mm down and 12 mm up (stack [Mail, News, Docs]), a third finger lands at (86, 45), the fingers slide on and lift, then a 1-finger tap. Then `windowSwitcher` is nil on the third finger's frame, the stack stays [Mail, News, Docs], no gesture haptic, `reads == 1`, nothing more until every finger has lifted, and the tap's gesture fires. | R15 scenario "Third finger cancels"; R15 "keep the window in front as it is at that moment, without the lift's reordering, and be silent". |
| T57 | R10, R11 | Source scan | When the sources are scanned. Then `AXUIElementSetAttributeValue` and `kAXPressAction` appear nowhere. | Non-goal "Closing or minimising windows from the switcher"; R10: only a raise changes a window, so nothing restores while sliding. |
| T58 | R7, R17 | World | Given Screen Recording missing, "Docs", "Mail" visible and "Notes" minimised. When (a) a window swipe slides and lifts; (b) the TCC push grants and the next window swipe begins. Then (a) `showsPreviews` false, `previewWindows` empty and `permissions.asks` empty; (b) `showsPreviews` true, `previewWindows` the Docs and Mail ids (Notes left out), `asks` still empty. | R7 scenarios "Permission missing" and "Permission granted later"; R17 "captured only while a window swipe begins" (only the open switcher's visible rows). |
| T59 | R6, R7 | World | Given a window swipe at Mail without Screen Recording. When the push grants mid-swipe, the fingers slide on and lift, and the next window swipe begins. Then the trackpads are not re-run, the open window switcher keeps `showsPreviews` false and its serial, the selection keeps following, and the next window swipe shows previews. | R7 "the next window swipe ... MUST show previews"; R6 "Previews MUST show the window as it looked when the window swipe began". |
| T60 | R7 | World | When (a) the grant changes with its TCC push withheld, then a trackpad preference notification that changes nothing arrives; (b) the app relaunches with Screen Recording already granted. Then the next window swipe shows previews in both. | R7 "after any relaunch macOS requires"; the design reads both grants on every push, before the run guard. |
| T61 | R8 | World | Given Screen Recording missing and never asked for. When the window swipe setting goes off, then on; the push grants; the push revokes. Then the hint is `.ask`, nil, `.ask`, nil, `.ask`. | R8 scenarios "Setting off hides the hint" and "Permission granted". |
| T62 | R8 | World and store | Given the hint `.ask`. When `askForScreenRecording()` runs twice, the app relaunches, then the push grants. Then `asks == [.screenRecording]` after both calls; inside the ask the store already holds `hasAskedForScreenRecording` true; the hint is `.openSettings` after the first call and after the relaunch, and nil after the grant; a settings record with `hasAskedForScreenRecording` true survives the store with every other field. | R8 "The first press MUST ask macOS", "Any later press ... MUST open the Screen Recording page"; the design's "a crash in between never asks twice". |
| T63 | R8 | Pure: `Copy` | When the hint copy is read. Then `screenRecordingHint` is "Window previews need Screen Recording.", `screenRecordingButton(.ask)` "Allow Screen Recording…" and `screenRecordingButton(.openSettings)` "Open System Settings…". | R8 "a hint saying window previews need Screen Recording"; the design's copy. |
| T64 | R7, R8 | Platform: `SystemPermissions` | Given injected `trusted` and `capturing` reads. When `com.apple.tcc.access.changed` is posted with neither changed, then with `capturing` flipped, then with `trusted` flipped. Then no `onChange` within 1 s for the first; `onChange` within 5 s for each flip, with `isGranted` reading the new values. | probe 6 (the broadcast fires on a Screen Capture change and carries no payload); `SystemPermissionsTests` (named `SystemAccessibilityPermissionTests` before S1). |
| T65 | R7, R17 | Source scan | When the sources are scanned. Then `AXIsProcessTrusted`, `notify_register` and `ScreenCaptureAccess` appear only in `SystemPermissions.swift`; `ScreenCaptureKit`, `SCShareableContent` and `SCScreenshotManager` only in `PreviewCapture.swift`; `SCStream(`, `SCRecordingOutput`, `CGImageDestination`, `representation(using` and `tiffRepresentation` nowhere; the "R9 only Accessibility" labels read "no Input Monitoring or event posting". | R17 "They MUST never be written to disk"; `docs/architecture.md` Privacy ("never streamed, recorded, encoded or written to a file"). |
| T66 | R14 | Pure: `Copy` | When `Copy.accessibilityHint` is read. Then "Clicks and scrolling aren't blocked during gestures, and windows can't be switched. Allow Accessibility access to do both." | R14 "The launcher window's existing Accessibility hint MUST also say that switching windows needs the permission"; the design's copy. |
| T67 | R1, R2, R13, R15 | Recognizer, every frame, against a setting-off recognizer | Given a recognizer with both kinds on and, as the reference, one with `slides: [.swipe]`; and again one with `[.windowSwipe]` against one with `[]` (the swipe setting off in both); each pair stepped through the same frames: the thumb landed just now, or 4 s ago; two fingers slide 5 mm down; then (i) 20 mm more down and lift; (ii) 20 mm sideways and lift; (iii) the thumb lifts, taps the corner while the fingers rest, and the fingers lift; (iv) on the frame after the start the thumb rolls 20 mm out of the corner, then a new thumb taps the corner while the fingers rest, and they lift. When the start is (a) answered false before the next frame; (b) answered true before the next frame; (c) never answered; (d) answered false three frames later; (e) answered true before the next frame, but naming the start of an earlier slide down that lifted under the same thumb; (f) answered true only after the fingers lifted; (g) answered true, then false a frame later. Then (a) from the start frame on, every recognition equals the reference's, the start's own `.windowSwipe(.began)` aside: (ii) begins no swipe and (iii) swaps in both; (b) both flags are true on every frame after the start up to the frame before `.ended`; (c), (e), (f) on hands (i) and (ii), both flags equal the reference's on every frame, and the window swipe phases still run to `.ended` (on hand (iii) an unanswered start cannot swap, as the design's degraded case says); (d) both flags equal the reference's on every frame, and from the answer's frame on every recognition does, so on (iv), where the answer comes after the thumb has gone, the rolled thumb counts among the rest's fingers and the new thumb's tap swaps in neither; (g) as (b). | R13 "MUST then behave exactly as it does with the window swipe setting off" and "it never becomes a swipe"; R2 "The decision MUST hold until both fingers lift"; R15 "the blocking window is held open until both fingers lift"; the setting-off recognizers (`[.swipe]`, and `[]` with the swipe off) as the reference; the design's answer rule ("an answer names its start") for (e) to (g). |
| T68 | R1, R13, R15 | Platform: `DeviceSession` | Given a session on the built-in surface with both kinds on and hand-built 10 ms frames: the thumb rested 4 s, two fingers slide 3.5 mm down, then 12 mm more, then lift; a second such slide follows under the same thumb. When the reply delivered with the first start is called (a) with true before the next frame; (b) with false before the next frame; (c) not at all; (d) with true, but only after the second slide's start, whose own reply is never called. Then exactly one delivered event per start carries a reply, and no other event does; `blocksClicks`, read as the click tap reads it after each frame, is (a) true from the frame after the start until the lift; (b), (c) false on every frame; (d) false on every frame of the second slide. | R15 "Click blocking MUST apply for the whole of a window swipe"; R13 "behave exactly as ... with the window swipe setting off" (a thumb rested 4 s blocks no click); the design's answer rule. |
| T69 | R1, R3, R13 | World, frame by frame | Given the frontmost app's read listing, as (visible, minimised): (1, 1); (2, 0); (0, 2); (14, 0); (1, 0); (0, 1); (0, 0); a full-screen front window with two visible windows and one minimised behind it; two windows from an app that does not answer (`answers = false`). When the thumb anchors and two fingers slide 5 mm down. Then the first four answer the start true and show 2, 2, 2 and 10 rows from the start frame; the other five answer it false and show no window switcher on any frame; each reads once. | R1 "The window count MUST be the number of rows the switcher shows, so a switcher never appears with fewer than two rows"; R3 "When the front window is full screen, it MUST count as the app's only window"; R13 scenarios "One visible and one minimised window", "Only window minimised" and "No windows"; the design's degraded case for an app that does not answer. |
| T70 | R2, R3, R12, R13 | World, frame by frame, against a reference world | Given Notes on the 1-finger gesture, Mail on the 2-finger gesture, and four worlds: TextEdit with one window; Finder with no windows; no frontmost app; Safari with its front window "Film" full screen and "Docs" and "Mail" behind it. Each is built twice: the window swipe setting on and, as the reference, off; and every pair again with the swipe setting off in both. When each pair plays the same hands frame by frame, probing with an unphased scroll after every frame: (h1) the thumb anchors, two fingers slide 20 mm down, press, lift; (h2) the thumb rests 4 s, two fingers slide 2 mm, then 18 mm down, press, lift; (h3) two fingers slide 5 mm down, then 20 mm sideways, lift; (h4) two fingers slide 5 mm down, the thumb lifts and taps the corner while they rest, they lift. Then in every pair and hand the setting-on world's probes, `windowSwitcher` and `switcher` on every frame, and its press verdicts, pulses, apps brought to front, raises and fired gestures, equal the reference's; `windowSwitcher` and `switcher` are nil on every frame; each start is answered false (`windowSwipeAnswers` all false) and each hand reads once; in TextEdit's and the full-screen pairs, (h1)'s probes drop from the fingers' landing to their lift, no gesture fires, nothing is raised and nothing pulses, and (h2)'s probes pass; (h4) swaps in both worlds, the same app with one gesture haptic. | R13 "MUST then behave exactly as it does with the window swipe setting off (R16)" and its scenarios "One window", "One window scrolls after the blocking window", "Sideways after down stays no swipe" and "No windows"; R3 scenario "Full-screen front window"; R12 and R13's "a haptic MUST NOT play" for the slide itself, read with the swap under its resting fingers playing its own as with the setting off (open question 17); the setting-off world as the reference, itself pinned by T37. |
| T71 | R13 | World, frame by frame | Given TextEdit frontmost with one window. When two fingers slide 5 mm down under the anchored thumb, TextEdit then opens a second window, the fingers slide 20 mm more and lift, and a new pair then slides 5 mm down under the same thumb. Then no window switcher on any frame of the first slide and `reads == 1` until it lifts; the second slide's start is answered true and its switcher lists both windows. | R13 scenario "Window opens mid-slide"; R13 "The count MUST be fixed when the direction is decided". |
| T72 | R14 | World | Given Safari frontmost with "Docs" and "Mail", and Accessibility missing. When two fingers slide 24 mm down under the anchored thumb and lift; then the TCC push grants Accessibility, and the next slide down begins. Then the first slide shows no window switcher on any frame, reports no start (`windowSwipeAnswers` empty) and reads nothing; after the grant the trackpads re-run and the next slide shows the window switcher with "Docs" and "Mail". | R14 scenarios "Accessibility missing" and "Accessibility granted later". |
| T73 | R1, R13 | Pure: `WindowSwipeConfirmation` | Given a confirmation and a handler that records what it is handed. When it delivers (a) a `.windowSwipe(.began)` from the MacBook whose handler confirms the MacBook; (b) one whose handler confirms the Magic Trackpad; (c) one whose handler confirms nothing; (d) one with a nil handler; (e) a `.swipe(.began)`, a `.windowSwipe(.moved(travelMM: 12))` and a fired gesture, each with a handler that confirms the MacBook; (f) a start after `confirm(on:)` named the MacBook between two deliveries. Then the handler receives each event exactly once; the answer is (a) true; (b), (c), (d) false; (e) nil for each; (f) false. | The port's rule for `confirmWindowSwipe(on:)` ("only while `onEvent` is handling a `.windowSwipe(.began)` from `trackpad` ... anywhere else it does nothing"); R13 (a start nobody confirmed is no window swipe). |

### Verified without a test

Every manual check runs a Debug build from Xcode, right hand, all three switches on, the default tracking speed, Accessibility and Screen Recording granted unless a step says otherwise. Each entry names the part of a requirement no test can observe (real apps, the screen, the hardware, real time); the rest of that requirement is proved by its test rows.

- **The build and the suite (no requirement on its own).** `swift build` and `swift test` in `LauncherKit` pass, every pre-plan row included (R16 "no change to the swipe"); `xcodegen` then `xcodebuild` builds the app with `SystemPermissions()` at the composition root and `window-swipe.svg` among its resources.
- **R4, R5, R6 on screen: real windows, the glass panel, real pictures (M1).** Open Safari with windows "A", "B", "C" front to back and a minimised "D"; pointer on the main display; anchor the thumb top-left, slide two fingers 5 mm down and hold. Expect a Liquid Glass panel whose top-left corner sits 12 pt below the menu bar and 12 pt from the display's left edge (right of a left-side Dock); four rows A, B, C, D, A under a glass highlight; A to C with pictures 60 pt tall and at most 120 pt wide, their titles to the right on one line; D at reduced opacity with Safari's icon and a "Minimised" badge. On the first window swipe after launch the rows show Safari's icon first, then crossfade to pictures. Lift: the panel fades. Repeat in Left hand: same corner.
- **R5, the second display (M2).** Pointer on a second display, repeat M1: the panel sits at that display's top-left.
- **R5, shrinking on a real display (M3).** System Settings › Displays › Larger Text; TextEdit with 10 windows; window swipe: all 10 rows show, each the same smaller height, the last row above the bottom of the screen.
- **R5, real focus and clicks (M4).** Type in a TextEdit document; window swipe and lift without moving; type again: the text goes on in the same document. While the panel shows, clicking on it does not focus it or reach the window under it.
- **R6, the drawn ellipsis (M5).** A Safari tab whose title is longer than the row: the row's title ends in "…".
- **R6, a picture that stays as it began (M6).** A window playing a video: window swipe and hold 3 s: its picture does not change.
- **R7, no system prompt on screen (M7).** `tccutil reset ScreenCapture com.domasgru.TrackpadLauncherApp`, relaunch, five window swipes: rows show the app icon with each title, and no system dialog appears. Note whether macOS shows its periodic screen-access alert (F31).
- **R8, the real prompt and System Settings page (M8).** Continuing from M7, open the launcher window: after the Accessibility hint's place, "Window previews need Screen Recording." with "Allow Screen Recording…". Press it: macOS asks whether Trackpad Launcher may record the screen; deny. Reopen the launcher window: the button reads "Open System Settings…"; press it: System Settings opens on the screen recording page of Privacy & Security. Allow Trackpad Launcher, quit and reopen if macOS asks; reopen the launcher window: no hint; the next window swipe shows pictures (R7). Reset again and turn the window swipe switch off: no hint.
- **R9, the real pointer acceleration (M9, open question 1).** At the default tracking speed, compare the finger distance for one icon of the app switcher sideways with one row of the window switcher down, at the same pace: about the same. At the fastest tracking speed: both shorter.
- **R10, R11 on real windows and focus (M10).** Safari "Docs", "Mail", "News": slide down one row and hold: Mail fully in front behind the panel; continue to News and lift; press ⌘L: News's address bar takes the focus; window swipe again: rows read News, Docs, Mail.
- **R11, restoring in real apps (M11, open question 11).** In TextEdit, Finder, Safari, Google Chrome and Visual Studio Code in turn, minimise a window; slide past its row: it stays minimised; lift on its row: it is restored and in front.
- **R12, the haptics as felt (M12).** Slide across two rows: two light ticks; lift on another window: one firm click; lift on the first row: nothing.
- **R14, a real revocation and the hint view (M13).** Remove Trackpad Launcher from Accessibility; with Safari in front with two windows over a long page, anchor the thumb, wait 4 s and slide two fingers down: no panel appears, and the slide does what the same slide does with the window swipe switch off (turn the switch off, repeat, and compare: both scroll the page, or both open Mission Control, open question 8). Turn the switch back on. Open the launcher window: the Accessibility hint reads "Clicks and scrolling aren't blocked during gestures, and windows can't be switched. Allow Accessibility access to do both." Allow Trackpad Launcher again in System Settings, without relaunching: the next slide down shows the panel with both windows.
- **R15, real scrolling and Mission Control (M14).** Safari with two windows, the pointer over a long page. Within 3 s of anchoring the thumb, window swipe down and up: the page does not scroll and Mission Control does not open. Again with the thumb anchored 4 s first: the page may move during the first 3 mm, as it did before change 1, then stays still until the fingers lift (the scroll is stilled, as in T33(b)), and Mission Control does not open. During a window swipe land a third finger: the panel disappears and no click reaches the page.
- **R16, the switch row and its illustration (M15).** Launcher window: a third row "Swipe up or down to switch windows" below "Thumb tap to swap apps", with the window swipe illustration (the thumb in the corner, two fingers, an up-and-down arrow, in the style of `swipe.svg`), mirrored in Left hand. Switch it off, anchor the thumb, wait 4 s, slide two fingers down over a page: the page scrolls and no panel shows. Quit and reopen: still off.
- **R17, the presenter's pictures (M16).** Code review of `WindowSwitcherPresenter`, `WindowSwitcherPanel` and `PreviewCapture`: capture starts only in `open(_:)` and only for a non-empty `previewWindows`; the task is cancelled on nil; every arrival checks the shown serial; `emptied()` clears every slot layer's contents; no `CGImage` lives in any other property, cache or static. Then Instruments › Allocations: mark a generation, run five window swipes with pictures, wait 1 s after the last fade, mark again: no persistent `CGImage` or `IOSurface` growth from `PreviewCapture`.
- **R17, the capture race (M17).** Right after launch, window swipe on Safari and lift within a fraction of a second, then at once window swipe on TextEdit: no Safari picture ever shows in TextEdit's rows.
- **The messaging timeout and the unanswering app (M18).** TextEdit with two windows; in Terminal run `sleep 5; kill -STOP $(pgrep -x TextEdit)` and click TextEdit within 5 s; after it stops, slide two fingers down under the thumb: no panel appears, the slide behaves as with the window swipe switch off, and the pointer stalls at most once, for a fraction of a second. `kill -CONT $(pgrep -x TextEdit)`. Again, but start the window swipe before the stop and keep sliding across rows past it: at most one short hitch, then no further hitches; lift: nothing changes, no haptic. `kill -CONT`.
- **The private window number's fallback.** Code review: `FrontmostAppWindows` resolves `_AXUIElementGetWindow` once with `dlsym` and, when it is missing, numbers windows only through `number(of:among:)` (T16), leaving unmatched windows out; the window list's first call runs off the main actor in `init()`.
- **The app switcher after the prefactor (M19).** The sideways swipe's panel looks, centres, follows (one icon per 100 cursor points) and fades as before.
- **R1, the 50 ms bound, and R13, real apps' window counts (M20, change 1).** World proves only that the model shows the switcher in the main-actor turn that handles the start (T19); the bound runs from the movement to the panel on screen, so it is timed end to end on video, since sampling profilers cannot time one interval and the logging ban rules out signposts. Draw a mark on the trackpad 3 mm below where two fingers will land; film the trackpad and the screen's top-left corner together at 240 fps (one frame per 4.2 ms); with Safari frontmost with 10 windows, anchor the thumb, land two fingers above the mark and slide them firmly down past it. Count video frames from the first frame the leading fingertip covers the mark to the first frame the panel shows: at most 12 (50 ms) on each of five runs, and again five runs with the launcher window open. Compare with the app switcher, filmed the same way with a sideways mark: the window switcher is at most two video frames slower. Then, each with the thumb anchored 4 s before sliding two fingers down over a long document: TextEdit with one window: the document scrolls and no panel shows; Finder with no windows, Finder with its only window minimised, and Safari with its only window full screen: no panel; Finder with one visible and one minimised window: the panel shows two rows. In TextEdit with one window, slide down and, while still sliding, press ⌘N: no panel until the fingers lift; the next slide shows two rows.
- **The real adapter's wiring of the answer (M21, change 1).** Code review of `MultitouchTrackpads`: every event reaches `onEvent` through its `WindowSwipeConfirmation` (T73 proves the rule, and every World row runs it through `InMemoryTrackpads`); a start's reply is called once, with the confirmation's answer; `confirmWindowSwipe(on:)` only forwards; events of a replaced run are dropped before the confirmation, reply included. No timer, queue or wait is added. Why not a test: what is left is wiring around real multitouch devices.
- **Documentation.** `docs/product-overview.md` describes the window swipe beside the swipe, "when the frontmost app has two or more windows", extends the silent-lift exception to it without the old clause about a "No open windows" or Accessibility message, and its privacy note says the app may ask for Screen Recording, used only to draw window previews while the window switcher shows.

## Slices

S1 to S4 are built and committed, and describe the requirements as they stood then. Change 1 (a window swipe only with two or more windows) follows as S5 and S6, which change the built code.

### S1: Make the change easy: one selection rule, two-axis travel, slide kinds, one permissions port, one overlay panel

**What to build:** Nothing the user can see changes. The app switcher's selection maths moves unchanged into `SwitcherSelection` (`Switcher` holds one; its presenter reads `selection`). `PointerCurve.cursorMove(dxMM:dyMM:interval:)` replaces `cursorPoints`, and `SwipeTravel.cursor(_:pointsPerStep:)`, `shippedPointsPerStep` and `travel(along:dxMM:dyMM:interval:)` replace the icon-named forms, with `CursorTravel`, `LaunchTuning` and the Debug tuner following. `SlideKind` and `slides: Set<SlideKind>` replace `swipes: Bool` on `GestureRecognizer.init`, `TrackpadHardware.run`, both hardware adapters, the model's `Run` and every driver, with `Settings.slides` derived from the swipe setting alone: `[.swipe]` behaves exactly as `true` did and `[]` as `false`. The `Permissions` port (`onChange`, `isGranted(_:)`, `ask(_:)`, with `Permission.accessibility`) replaces `AccessibilityPermission`; `SystemPermissions` replaces `SystemAccessibilityPermission`, `InMemoryPermissions` and `World.permissions` replace their counterparts, and the confined rows follow the file rename. `OverlayPanel` and `Displays.screen(under:)` come out of the app switcher's panel and presenter. `TouchScript.tap` and `thumbTap` take an `(x, y)` drag. The stale `SwipePhase`, `Switcher` and `switcherMaxOvershoot` comments are fixed.

**Blocked by:** None (can start immediately).

**Requirements:** R9 (the pointer curve's vertical component).

**Test scenarios:** T1.

- [ ] T1 green.
- [ ] The existing suite passes with its meaning unchanged: the `SwitcherTests` rows run against `SwitcherSelection`, today's vertical-spoil rows run under `slides: [.swipe]`, and `AccessibilityTests` read `permissions.asks`.
- [ ] The app builds with `SystemPermissions()` at the composition root.
- [ ] M19 by hand: the app switcher unchanged.

### S2: Sliding up or down shows the frontmost app's windows

**What to build:** With the new *Swipe up or down to switch windows* switch on (the default, below *Thumb tap to swap apps*, with a new `window-swipe.svg` illustration in the style of `swipe.svg`: the thumb in the corner, two fingers, an up-and-down arrow), two fingers sliding up or down under an anchored thumb show the window switcher in the top-left corner of the pointer's display: the frontmost app's windows as the window swipe begins, front window first, visible then minimised, cut at 10, a full-screen front window alone, each row with the app's icon and its title (untitled windows named after the app), or a single "No open windows" or "Allow Accessibility to switch windows" row. The highlight follows the fingers one row per 100 cursor points with a light tick per row and a rubber band at both ends; clicks, scrolling and system swipes stay blocked for the whole window swipe; it ends when both fingers lift and is cancelled by a third finger or a click. Lifting changes nothing yet. The recognizer decides the kind once (`Move.slide`, `beginOrSpoil`, `Swipe.kind`) and emits `.windowSwipe` phases (`Recognition.windowSwipe`, `beginsSlide`, the frame thread's travel hook, `TrackpadEvent.windowSwipe`); `Settings.isWindowSwipeOn` joins `Settings.slides`; `Launcher` gains `shown`, `windowSwitcher`, `windowSwipe(_:)` (begin, moves with ticks, end and cancel clearing), `isWindowSwipeOn` and `setWindowSwipe(on:)`; the core gains `WindowID`, `AppWindow`, `FrontmostWindows`, `WindowSwitcher` (`Content`, `WindowList`, `Row`, `rows`, `app`, `frontWindow`, `listsWindows`, `serial`, `selection`), `Content.init(_:)`, `GestureRules.windowSwitcherMaxRows`, the row copy and `WindowColumnLayout`; `SystemActions.frontmostWindows()` reads through `FrontmostAppWindows.read()` with its `sort` and `number(of:among:)`, and `FakeWindows` answers reads; the shell gains `WindowSwitcherPanel`, `WindowSwitcherPresenter` (icons and titles, no capture), `WindowSwitcherLook`, `SettingRow` and the `MenuBarShell` wiring. The source scan confines the element API and the window list.

**Blocked by:** S1.

**Requirements:** R1, R2, R3 (the list), R4, R5, R6 (titles, the icon in place of a preview, appearing in the movement that starts it), R9, R12 (ticks), R13 (the rows), R14 (the row), R15, R16, R17 (the switcher's lifetime).

**Test scenarios:** T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20, T21, T22, T23, T24, T25, T26, T27, T28, T29, T30, T31, T32, T33, T34, T35, T36, T37, T38, T39, T40, T41, T42, T43.

- [ ] T2 to T43 green, and the existing suite green.
- [ ] M1 (with the app icon in place of every picture), M2, M3, M4, M5, M9, M12 (ticks), M13, M14 and M15 by hand.
- [ ] The private window number's fallback passes code review.

### S3: Sliding brings each window forward and lifting keeps it

**What to build:** Each time the selection lands on a visible window, that window comes to the front at once (`WindowSwitcher.selectedVisibleWindow`, `SystemActions.raiseWindows(_:)` through `FrontmostAppWindows.raise(_:)`, and the fake's `AXRaise`-like stack); a minimised row is never restored while sliding. The lift reads the windows again and carries out `WindowSwitcher.lift(now:)` → `WindowLift` (`WindowStack.raises`): the selected window in front with the keyboard focus, then the front window, then the rest, a minimised selection restored, R12's gesture haptic and the launcher window closing only when the window in front changed; message rows read nothing more and stay silent; a cancel leaves the windows as they are. The source scan bans attribute writes and presses. `docs/product-overview.md` gains the window swipe beside the swipe, and its silent-lift exception extends to the window swipe.

**Blocked by:** S2.

**Requirements:** R3 (the full-screen lift), R5 (focus stays put), R10, R11, R12 (the haptic), R13 and R14 (silent lifts), R15 (a cancel keeps the window in front).

**Test scenarios:** T44, T45, T46, T47, T48, T49, T50, T51, T52, T53, T54, T55, T56, T57.

- [ ] T44 to T57 green, and the earlier rows still green.
- [ ] M10, M11, M12 (the haptic) and M18 by hand.
- [ ] `docs/product-overview.md` describes the window swipe and its silent lift.

### S4: Window previews and the screen recording hint

**What to build:** Rows of visible windows show a picture of each window as it looked when the window swipe began, once Trackpad Launcher has Screen Recording; until then, and for minimised windows, the app icon. The launcher window shows the screen recording hint while the permission is missing and the window swipe setting is on: its button asks macOS the first time and opens the Screen Recording page of System Settings after that; the hint goes once the permission is granted. A window swipe never asks. `Permission.screenRecording` joins the port; `SystemPermissions` reads capture access, re-reads both grants on every broadcast and asks with `CGRequestScreenCaptureAccess()`; `Launcher` keeps the grant from the pushes, sets `showsPreviews` on each window switcher and exposes `screenRecordingHint` (`ScreenRecordingHint`) and `askForScreenRecording()`; `Settings.hasAskedForScreenRecording`; `WindowSwitcher.previewWindows`; the hint copy; `LauncherView`'s `SettingsNotice`, `SettingsPane.screenRecording` and the refit observation; `PreviewCapture` and the presenter capture once per serial, crossfade each picture in, and drop every picture when the window switcher goes (`emptied()`). The source scan confines the permission checks and capture, and bans streams, recordings and encoders. `docs/product-overview.md`'s privacy note says the app may ask for Screen Recording, used only to draw window previews while the window switcher shows.

**Blocked by:** S2 (it can run beside S3).

**Requirements:** R6 (previews), R7, R8, R17.

**Test scenarios:** T58, T59, T60, T61, T62, T63, T64, T65.

- [ ] T58 to T65 green, and the earlier rows still green.
- [ ] M1 with pictures, M6, M7, M8, M16 and M17 by hand.
- [ ] `docs/product-overview.md`'s privacy note names Screen Recording for previews only.

### S5: Make the change easy: a window swipe's start waits for the model's answer

**What to build:** Nothing the user can see changes, except one thing: a window swipe now blocks clicks and scrolling from the frame after its start, not on it. The system's swipes stay blocked on that frame, because the thumb is still anchored there. The recognizer begins a slide up or down unconfirmed: its phases are reported as today, and it blocks only by the thumb rules until `answerWindowSwipe(began:isWindowSwipe:)` settles it.
- True confirms it, and it blocks from the next frame until both fingers lift, as today.
- False turns it into the setting-off state: `.spoiled` under the slide's thumb or, once that thumb has gone, a rest of every contact down as `restOrIdle` gives it.
- An answer naming another start, arriving after the slide ended, or coming second changes nothing.

A swipe is born confirmed. `TrackpadHardware` gains `confirmWindowSwipe(on:)` as a protocol requirement. `WindowSwipeConfirmation` in `LauncherCore` holds the one main-actor rule for when a confirmation counts. Both adapters hand every event to `onEvent` through it and forward `confirmWindowSwipe(on:)` to it, and so answer every window swipe start once `onEvent` returns. In the real adapter, `DeviceSession` delivers the start with a reply that fills its answer slot (the main actor is the one writer), and the frame callback hands the slot to the recognizer before each step; `MultitouchTrackpads` calls the reply with the confirmation's answer. In memory, `InMemoryTrackpads` gives the answer to the running recognizer between frames and logs it in `windowSwipeAnswers`. The model confirms every window swipe start as the first thing it does with it, which keeps today's behaviour, message rows and all. The recognizer drivers take `answering:` (default true), and the `DeviceSession` test helpers take the reply. `docs/architecture.md` already describes the answer hop (updated with this plan).

**Blocked by:** S4.

**Requirements:** R1, R2, R13 and R15, in the part the answer protocol carries: a start answered once, by its own handling; a declined slide exactly the setting-off slide, at the recognizer; blocking once confirmed, from the frame after the start.

**Test scenarios:** T67, T68, T73, then T11, T19 and T35 as revised.

- [ ] T67, T68 and T73 green; T11 green in its revised form (blocking from the frame after the start); T19 asserts the start is answered true; T35's new case (a), a press on the frame after the start passing and cancelling, green beside the old no-Accessibility click case, which S6 deletes.
- [ ] The existing suite green with its meaning unchanged: every other recognizer row runs with starts confirmed before the next frame, and every World row passes as before.
- [ ] M21 passes code review; the app builds.
- [ ] M14 by hand, both runs.

### S6: A slide up or down is a window swipe only with two or more windows

**What to build:** Over an app with two or more windows, and with Accessibility, a slide up or down is a window swipe as before. Otherwise nothing shows, nothing pulses, and the slide behaves exactly as with the window swipe switch off. That covers one window, an only window minimised, no windows, a full-screen front window, no frontmost app, an app that does not answer, and no Accessibility. Such a slide scrolls once the blocking window has passed, never becomes a swipe, lets a thumb tap under its resting fingers swap, and stays no window swipe if a window opens before the fingers lift. In the model:
- `windowSwipe(_:)` confirms a start only while gestures are active and `WindowSwitcher.Content(system.frontmostWindows())` exists.
- It shows the switcher only when none is up, so a second trackpad's window swipe runs its course with none.
- It lifts every switcher it shows.
- `reconcile` runs the recognizers without `.windowSwipe` while Accessibility is missing.

In the core:
- `WindowSwitcher.Content` becomes a struct (`app`, `windows`) with the failable parse: nil below two rows or with no app.
- `Row` loses `.message`; `Row.window` and `WindowSwitcher.app` stop being optional; `listsWindows` goes.
- `Copy.untitledWindow(of:position:)` always numbers ("Preview — Window 2").
- `Copy.noOpenWindows` and `Copy.accessibilityForWindows` go.
- `Copy.accessibilityHint` names switching windows.

The presenter and panel take the non-optional app and window. These tests are deleted or rewritten as their rows now read: those that proved the retired T22, T28, T29, T30, T32 and T55; T35's old no-Accessibility click case; and the old one-row, message-row and one-untitled-window cases of T20, T25, T47 and T49. `docs/product-overview.md` follows the requirements' Documentation section.

**Blocked by:** S5.

**Requirements:** R1 (only over two or more windows, the count being the rows), R2 (a slide that is no window swipe never becomes a swipe), R3 (the full-screen front window), R6 (untitled windows always numbered), R12 (no haptic without a window swipe), R13, R14.

**Test scenarios:** T69, T70, T71, T72, T66, then T20, T25, T40, T47 and T49 as revised; T22, T28, T29, T30, T32 and T55 retired.

- [ ] T66, T69, T70, T71 and T72 green; T20, T25, T40, T47 and T49 green as revised; no test still expects a "No open windows" or Accessibility row; and every earlier row still green.
- [ ] M13, M18 and M20 by hand; M1 to M4 and M10 still pass on apps with two or more windows.
- [ ] `docs/product-overview.md` says the window swipe works "when the frontmost app has two or more windows", and its silent-lift exception no longer mentions a "No open windows" or Accessibility message.
