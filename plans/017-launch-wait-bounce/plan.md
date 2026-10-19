# Plan: Launch bounce

## Problem statement

A gesture for an app that is not running launches it. A cold launch takes 1 to 4 seconds, sometimes longer. Today the launch animation plays at once and is gone within a third of a second. Then the only feedback until the app's window shows is the Dock's own bounce, and that is often hidden, on another display, or far from the pointer. The user cannot tell whether the app is still coming or the gesture did nothing. They tap again, or reach for the Dock.

## Solution

When a gesture fires for an app that is not running, its icon bounces above the pointer instead. The bounce feels like the Dock's: the icon jumps up, falls back with gravity, and jumps again. The icon is glued to the pointer, so it stays in view wherever the user moves it. When the app's window shows, the bouncing icon plays the launch animation from wherever it is and floats away. If the app never gets going, the icon fades out quietly instead.

Apps that are already running keep the launch animation exactly as today.

The debug animation tuner gains a launch bounce section, so the bounce's feel can be tried and tweaked live.

## Requirements

### R1. The launch bounce plays for a gesture that launches its app
The launch bounce MUST play when a gesture fires for an assigned, present target app that is not running, while the launch animation setting is on. Not running means macOS reports no process for the app when the gesture fires. An app already launching from the Dock or Finder therefore counts as running and gets the launch animation (R2). The bounce MUST appear no later than the haptic feedback. It MUST replace the launch animation for that gesture: no launch animation plays when the gesture fires.

#### Scenario: Assigned app that is not running
- **GIVEN** the 2-finger gesture is assigned to Figma, and Figma is not running
- **WHEN** the user makes the 2-finger gesture
- **THEN** Figma's icon appears above the pointer and starts bouncing at once, with the gesture haptic, no icon floats up, and Figma launches

### R2. Running apps keep the launch animation
A gesture whose target app is already running MUST play the launch animation exactly as today, with no launch bounce, unless that app's launch bounce is still playing (see R14). This holds whether or not the app has a window.

#### Scenario: Running app
- **GIVEN** the 1-finger gesture is assigned to Arc, and Arc is running
- **WHEN** the user makes the 1-finger gesture
- **THEN** Arc's icon floats up from the pointer as today, and no icon bounces

#### Scenario: Running app with no window
- **GIVEN** the 3-finger gesture is assigned to Mail, Mail is running, and all its windows are closed
- **WHEN** the user makes the 3-finger gesture
- **THEN** the launch animation plays, and no icon bounces

#### Scenario: App launching from the Dock
- **GIVEN** the 2-finger gesture is assigned to Figma, and the user opened Figma from the Dock a second ago and it is still starting up
- **WHEN** the user makes the 2-finger gesture
- **THEN** Figma's icon floats up from the pointer as the launch animation, and no icon bounces

### R3. Only gestures bounce
A swipe, a window swipe and a swap MUST never play the launch bounce. Nothing else plays it either: an unassigned gesture, a missing assignment, gestures inactive, or the launch animation setting off.

#### Scenario: Launch animation setting off
- **GIVEN** the launch animation setting is off, and the 2-finger gesture is assigned to Figma, which is not running
- **WHEN** the user makes the 2-finger gesture
- **THEN** no icon appears at any point, the gesture haptic plays, and Figma launches

#### Scenario: Missing assignment
- **GIVEN** the 4-finger gesture is assigned to Spotify, and Spotify has been moved to the Trash
- **WHEN** the user makes the 4-finger gesture
- **THEN** no icon appears

### R4. The bouncing icon is the target app's icon, the same size as the launch animation's icon
The bouncing icon MUST be the target app's own icon, the one Finder shows for it, the same size as the launch animation's icon: 60 × 60 points as shipped. It MUST show no blur or pixelation at any point of the bounce.

#### Scenario: Retina display
- **GIVEN** the pointer is on a Retina display, and the 2-finger gesture is assigned to Figma, which is not running
- **WHEN** the user makes the 2-finger gesture
- **THEN** a 60-point Figma icon bounces, sharp at every height

### R5. The icon rests just above the pointer
This applies to a single bouncing icon, except as the edge-of-display rule (R6) and the row rule (R13) say. At rest, between jumps, the icon MUST sit centred horizontally on the pointer's tip, its bottom edge 8 points above the tip. It MUST jump upward from there and never cover the pointer.

#### Scenario: Resting spot
- **GIVEN** the pointer's tip is at the middle of the display
- **WHEN** a launch bounce starts
- **THEN** the icon's horizontal centre is on the tip, and at rest its bottom edge is 8 points above it

### R6. The icon stays above the pointer at the display's edges
The icon, or the whole row of icons (R13), MUST always rest and bounce above the pointer, wherever the pointer is. Near the top edge, the part that does not fit MUST be cut off by the edge; the icon MUST NOT move below the pointer or onto another display. Near the left or right edge, it MUST slide sideways just enough to stay entirely on the pointer's display.

#### Scenario: Pointer at the top of the display
- **GIVEN** the pointer rests on the menu bar
- **WHEN** a launch bounce starts
- **THEN** the icon bounces above the pointer, cut off by the top edge of the display, and never below the pointer

#### Scenario: Pointer at the right edge
- **GIVEN** the pointer's tip is 10 points from the right edge of its display
- **WHEN** a launch bounce starts
- **THEN** the icon is entirely on the display, its right edge at the display's edge

### R7. The icon follows the pointer
While it bounces, the icon MUST move with the pointer on every frame, with no lag the user can see. With the shipped tuning it MUST not trail behind the pointer; the tuner may set trailing for experiments. It MUST follow the pointer onto another display.

#### Scenario: Moving the pointer while the app launches
- **GIVEN** Figma's icon is bouncing
- **WHEN** the user moves the pointer across the screen and onto a second display
- **THEN** the icon stays just above the pointer the whole way, and keeps bouncing on the second display

### R8. The bounce feels like the Dock's
Each bounce MUST rise quickly to about half the icon's height, slow at the top, and fall back with gravity, about 0.7 seconds per bounce, repeated until the bounce ends. With the shipped tuning the icon MUST keep its size and shape while it bounces; the tuner may set squash for experiments.

#### Scenario: Side by side with the Dock
- **GIVEN** the 2-finger gesture is assigned to Figma, which is not running
- **WHEN** the user makes the gesture, and then opens a second app that is not running from the Dock
- **THEN** both icons bounce at a similar height and rhythm

### R9. The bounce ends when the app's window shows
When a window of the launching app first shows on screen, on any display, the bounce MUST end within 50 milliseconds. A splash screen counts as a window. The icon MUST then play the launch animation, starting from wherever it is at that moment, even mid-jump. From then on it no longer follows the pointer.

#### Scenario: Window shows mid-jump
- **GIVEN** Figma's icon is bouncing and is near the top of a jump
- **WHEN** Figma's window shows
- **THEN** the icon floats away from that spot, and moving the pointer afterwards does not move it

#### Scenario: Splash screen
- **GIVEN** a gesture is launching an app that shows a splash screen before its main window
- **WHEN** the splash screen shows
- **THEN** the bounce ends with the launch animation

### R10. The bounce ends when the app starts up without a window
When the app has finished starting up and no window of it has shown within 2 seconds after that, the bounce MUST end with the launch animation, or earlier at the 10-second cap (R12). This covers menu bar apps, apps that open no window, and apps whose window opens on another Space.

#### Scenario: Menu bar app
- **GIVEN** the 5-finger gesture is assigned to a menu bar app that is not running
- **WHEN** the user makes the 5-finger gesture
- **THEN** the icon bounces until 2 seconds after the Dock stops bouncing its icon, then floats away

### R11. The bounce fades quietly when the launch goes nowhere
The bounce MUST end without the launch animation when the app fails to launch, quits before a window shows, or is still starting up at the 10-second cap (R12). The icon MUST then fade out in place within about 0.2 seconds.

#### Scenario: App fails to launch
- **GIVEN** the 2-finger gesture is assigned to an app that macOS refuses to open
- **WHEN** the user makes the 2-finger gesture
- **THEN** the icon bounces until macOS reports the failure, then fades out where it is, with no float-up

#### Scenario: App crashes during startup
- **GIVEN** a gesture is launching an app that crashes while starting up
- **WHEN** the app quits
- **THEN** the icon bounces until that moment, then fades out where it is, with no float-up

#### Scenario: App still starting after 10 seconds
- **GIVEN** a gesture is launching an app that takes 15 seconds to start up
- **WHEN** 10 seconds have passed since the gesture fired
- **THEN** the icon fades out where it is, and the app's window still shows when it is ready

#### Scenario: First launch of a downloaded app
- **GIVEN** a gesture is launching a downloaded app for the first time, and macOS asks whether the user is sure they want to open it
- **WHEN** the user has not answered 10 seconds after the gesture fired
- **THEN** the icon keeps bouncing until then, because that dialog is not the app's window, and then fades out where it is; this is accepted

### R12. No bounce lasts longer than 10 seconds
No icon MUST bounce longer than 10 seconds after its gesture fired. At the cap, if the app has finished starting up, the icon MUST play the launch animation. If the app is still starting up, the icon MUST fade out quietly (R11). A window that shows after the bounce has ended MUST play nothing.

#### Scenario: App started up late without a window
- **GIVEN** a gesture is launching a menu bar app that finishes starting up 9 seconds after the gesture fired
- **WHEN** 10 seconds have passed since the gesture fired
- **THEN** the icon floats away from where it is

### R13. Several launches bounce side by side
Each gesture that launches a different app MUST get its own bouncing icon. Bouncing icons MUST sit in one row centred above the pointer, newest on the right, 12 points apart. When one ends, the others MUST slide to their new places over about 0.2 seconds. Each ends on its own app's events.

#### Scenario: Two cold launches
- **GIVEN** the 1-finger gesture is assigned to Xcode and the 2-finger gesture to Slack, neither running
- **WHEN** the user makes the 1-finger gesture, then the 2-finger gesture while Xcode's icon still bounces
- **THEN** Xcode's and Slack's icons bounce side by side above the pointer, Slack's on the right

#### Scenario: One of two ends
- **GIVEN** Xcode's and Slack's icons are bouncing side by side
- **WHEN** Slack's window shows first
- **THEN** Slack's icon floats away, and Xcode's icon moves to the centre above the pointer and keeps bouncing

### R14. Firing the same app again keeps one bounce
A gesture for an app whose launch bounce is still playing MUST NOT start a second bounce or restart the first. The gesture haptic MUST play, and the gesture's usual bring-to-front action MUST happen; for a launching app it asks macOS to open the app again, which changes nothing visible. No launch animation plays for that repeated gesture.

#### Scenario: Impatient second tap
- **GIVEN** Figma's icon is bouncing
- **WHEN** the user makes Figma's gesture again
- **THEN** the gesture haptic plays, one Figma icon keeps bouncing without a jump in its rhythm, and Figma's window shows when it is ready

#### Scenario: Menu bar app started up, still bouncing
- **GIVEN** a menu bar app has started up, and its icon is still bouncing
- **WHEN** the user makes its gesture again
- **THEN** no icon floats up, and the one icon keeps bouncing

### R15. Reduce motion pulses instead of bouncing
With the system's Reduce motion setting on, the icon MUST stay at its resting spot above the pointer and gently pulse its opacity instead of bouncing. It MUST still follow the pointer. Every ending MUST fade it out in place, as the launch animation does under Reduce motion.

#### Scenario: Reduce motion on
- **GIVEN** Reduce motion is on, and the 2-finger gesture is assigned to Figma, which is not running
- **WHEN** the user makes the 2-finger gesture and Figma's window later shows
- **THEN** Figma's icon pulses above the pointer without moving up or down, then fades out in place when the window shows

### R16. The bounce never gets in the way
The bouncing icon MUST never take focus or receive clicks. Clicks, scrolling and every gesture, swipe, window swipe and swap MUST work exactly as when no icon shows. The launcher window MUST close on the gesture as today.

#### Scenario: Clicking under the icon
- **GIVEN** Figma's icon is bouncing above the pointer
- **WHEN** the user moves the pointer up so the icon's area covers a button, and clicks the button
- **THEN** the button receives the click

### R17. The animation tuner can tweak the bounce
The bounce's feel cannot be pinned down in numbers up front, so the debug tuner lets it be tried live. Debug builds' animation tuner MUST have a launch bounce section. It MUST offer a control for each of: the jump height, the time up, the time down, the rest between bounces, the squash on landing (none by default), the resting gap above the pointer, the horizontal offset from the pointer, trailing behind the pointer (none by default), the gap between icons, and the fade out on a quiet end. Changes MUST apply to the next launch bounce. Release builds MUST play the shipped bounce and show no tuner.

#### Scenario: Trying a higher jump
- **GIVEN** the tuner is open in a Debug build, and the 2-finger gesture is assigned to Figma, which is not running
- **WHEN** the user raises the jump height and makes the 2-finger gesture
- **THEN** Figma's icon bounces higher above the pointer

### R18. The tuner previews the bounce
The tuner's launch bounce section MUST have a preview button. It MUST bounce Finder's icon at the pointer for 3 seconds, then end it as a window showing would.

#### Scenario: Previewing the bounce
- **GIVEN** the tuner is open in a Debug build
- **WHEN** the user presses the preview button
- **THEN** Finder's icon bounces above the pointer for 3 seconds, then floats away

### R19. Presets carry the bounce knobs
Tunings and presets MUST save and load the bounce knobs together with the existing ones.

#### Scenario: Older saved preset
- **GIVEN** a preset saved before the launch bounce existed
- **WHEN** the user loads it
- **THEN** the launch animation knobs take the preset's values, and the bounce knobs keep the shipped values

## Non-goals

- **A bounce for running apps without a window.** Bringing such an app to front opens a window almost at once, so a bounce would only flash.
- **A bounce for swipes, window swipes and swaps.** They only reach running apps, so they never launch one.
- **A separate setting for the bounce.** The launch animation setting covers both; one switch keeps the window simple.
- **Bouncing for launches Trackpad Launcher did not start.** The bounce answers a gesture. A launch from the Dock, Spotlight or Finder has no gesture to answer. A gesture made while such a launch is starting finds the app running (R1) and plays the launch animation.
- **Suppressing the Dock's own bounce.** It is macOS's to show. Both bouncing for the same launch does no harm.
- **A sound.** Gesture sounds are still deferred for the whole product.
- **Showing progress or an estimated time.** macOS reports no launch progress; the bounce only says "still coming".
