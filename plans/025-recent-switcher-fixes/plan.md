# Plan: Trackpad Launcher is in its own switcher while its settings window is open

## Problem statement

Trackpad Launcher never shows in the switcher. The user opens its settings window, so it sits in the Dock like any app, switches to another app, and swipes. ⌘-Tab would offer Trackpad Launcher; the switcher does not. A swap cannot get back to it either. Plans 008 (R14) and 021 (R15) left it out with no product reason on record.

## Solution

While its settings window is open, Trackpad Launcher is an app like any other in the switcher, the frontmost app and the swap.

## Requirements

### R1. Trackpad Launcher is a running app while its settings window is open
Trackpad Launcher MUST count as one of the running apps, in its ⌘-Tab place, while its Dock icon shows. Its Dock icon shows while the settings window is open, including while it is minimised or hidden. That holds for the switcher's row and for the swap target. While the window is closed it MUST NOT count, as today.

#### Scenario: Swiping from another app back to the settings
- **GIVEN** the settings window is open, the user clicked Safari, and Mail and Notes run too, used longer ago; no gesture is assigned to any of them
- **WHEN** the user swipes
- **THEN** the row shows Safari, Trackpad Launcher, Mail, Notes, and lifting on Trackpad Launcher brings the settings window to the front with the gesture haptic

#### Scenario: Swapping from another app back to the settings
- **GIVEN** the settings window is open and the user clicked Safari
- **WHEN** the user rests two fingers and taps the thumb once
- **THEN** the settings window comes to the front with the gesture haptic

#### Scenario: Window closed
- **GIVEN** the settings window was open, then closed, and Safari and Mail are running
- **WHEN** the user swipes
- **THEN** the row shows Safari and Mail only

### R2. Trackpad Launcher can be the frontmost app
While the settings window is the active window, Trackpad Launcher MUST be the frontmost app: first in the row and selected when the swipe begins.

#### Scenario: Swiping from the settings window
- **GIVEN** the settings window is in front, and Safari, then Mail, were used before it
- **WHEN** the user swipes
- **THEN** the row shows Trackpad Launcher, Safari, Mail with Trackpad Launcher selected

#### Scenario: Lifting on Trackpad Launcher
- **GIVEN** the settings window is in front
- **WHEN** the user swipes and lifts without leaving the first icon
- **THEN** nothing changes and no haptic plays

#### Scenario: Swapping from the settings window and back
- **GIVEN** the settings window is in front and Safari was used before it
- **WHEN** the user rests two fingers and taps the thumb twice
- **THEN** the first tap brings Safari to the front, and the second brings the settings window back to the front

#### Scenario: Trackpad Launcher and Finder only
- **GIVEN** the settings window is in front and Finder is the only other app ⌘-Tab shows
- **WHEN** the user swipes
- **THEN** the switcher shows Trackpad Launcher, Finder

#### Scenario: Sliding down over the settings window
- **GIVEN** the settings window is in front and the window swipe setting is on
- **WHEN** the user slides two fingers down under the thumb
- **THEN** no window switcher shows and no haptic plays, since the settings window has only one window and a window swipe needs two

## Non-goals

- **Input blocking during a swipe** (holding back scrolling until the slide's direction is decided, stopping momentum, cancelling a system swipe already under way, holding the pointer). The original report came mostly from testing without the Accessibility permission. A full design and implementation was built, then left out of this change as more than the remaining, rare leaks justify. It is kept on the local branch `backup/025-full-blocking` for reference, to revisit if needed.
- **Special rules for an assigned Trackpad Launcher.** The gesture pickers list it. Assigned to a gesture, it follows the rule for every assigned app: left out of the row unless frontmost, still reachable by a swap.

## Implementation

The membership rule lives in the platform adapters, where LaunchServices already knows the ⌘-Tab order:
- The "never this process" filters in `LaunchServicesOrder`, `RunningAppsReader`'s fallback, `ActivationTracker` and `SwitcherPresenter` are removed. LaunchServices lists the app exactly while it is a regular (Dock) app, in its ⌘-Tab place.
- `RunningAppsReader.frontmost` is the one self rule: Trackpad Launcher is the frontmost app while it is listed. Active without its Dock icon (the move dialog, the Debug animation tuner), it stands for the app in front before it, as before.
- `FrontmostAppWindows` answers its own windows as an empty list, so a slide up or down over the settings window is no window swipe.
- Bringing it to front goes through the existing bring-to-front path, which reopens and activates it.

Tests: `SettingsWindowAsAppTests` (the row, the frontmost app, the swap, the closed window), `FrontmostAppRuleTests`, and `RunningAppsReaderTests` (the pure `LaunchServicesOrder.entries(_:)` parse keeps this process's entry).
