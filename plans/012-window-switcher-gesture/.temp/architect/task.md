# Task: design the window swipe (plan 012)

## The artifact

One candidate design package for the *window swipe* and its *window switcher*, shaped per the Design package template
in the shared reference, written to your output path and nothing else. It is a sketch: types, function signatures,
class shapes and module boundaries with `not implemented` bodies and pseudocode, plus the one page of prose the
template asks for. The usage section comes first and the type sketch is derived from it.

## What the design must address

The requirements are R1 to R17 in `plans/012-window-switcher-gesture/plan.md`, with their scenarios. The design must
carry every one of them end to end, and must say, for each requirement, which usage lines and signatures carry it.
Concretely the package has to cover:

1. **Recognition** on the multitouch thread: a vertical first drag past 3 mm starts a window swipe while the window
   swipe setting is on, direction decided once from that first drag, vertical travel through the pointer acceleration
   curve (100 cursor points per row), the start rules otherwise identical to the swipe's, the swipe setting and the
   window swipe setting independent (R16: swipe off, window swipe on, and the reverse), and what the recognizer emits.
2. **The model**: the window switcher value (rows fixed at begin, the selection following travel with the switcher's
   hard stops and rubber band, one light tick per row crossed), raising the selected visible window at once while
   sliding, never restoring a minimised one while sliding, the lift (selected window in front with keyboard focus,
   minimised restored, the final order "selected, front window, the others as before", the silence rules, the haptic
   rule of R12), cancellation, the one-row cases (one window, no windows, no frontmost app, no Accessibility), and the
   fixed-at-begin list (a window closing or opening mid-swipe).
3. **Ports and adapters**: what the model needs from the system (the frontmost app's windows with title, minimised
   state and order; raise; restore; re-stack; previews that arrive later; the Screen Recording permission: current
   state, a request, the push on change; the System Settings page) and how each real adapter over the Accessibility
   API, CGWindowList and ScreenCaptureKit is shaped, including degraded cases (not trusted, an app that does not answer
   in time, a window that closed, no private symbol).
4. **Previews** (R6, R7, R17): captured when the window swipe begins, off the main actor, filling in afterwards, icon
   until ready, never on disk, discarded at end; who owns the images given that framework types never cross a port.
5. **The shell**: a Liquid Glass panel in the top-left corner of the pointer's display just below the menu bar, one
   column of rows (60 pt preview keeping the window's proportions, at most 120 pt wide, title to the right truncated,
   untitled naming, the glass highlight on the selected row, dimmed rows with a "Minimised" badge and the app icon,
   the "No open windows" and "Allow Accessibility to switch windows" rows), shrink-to-fit, never taking focus or
   clicks, appearing in the same movement that starts the window swipe; the third switch in the switcher section; the
   screen recording hint with its button (first press asks macOS, later presses open System Settings; hidden when the
   permission is granted or the setting is off).
6. **Settings**: the window swipe setting, on by default, saved at once, upgrade leaves it on.
7. **The source policy and the docs**: which files own the AX element family, the window list and the capture APIs,
   how the `Confined` table changes, and what `docs/architecture.md` Privacy and `docs/domain-model.md` need to say.
8. **Testing seams**: name the seam each requirement's scenarios run at, and give a test a handle on everything a test
   cannot wait for or provoke (previews arriving later, the permission changing, a window closing between frames, an
   app that does not answer).

## Constraints the grounding settled

Read `plans/012-window-switcher-gesture/.temp/architect/grounding/index.md` first and then `how.md` and `why.md` in the
same directory, in full. Every design decision rests on facts there; the index gives each fact's standing. In
particular: the architecture's rules in `docs/architecture.md` (one model owns every decision, ports with exactly two
adapters, framework types never cross a port, `LauncherCore` imports Foundation and Observation only, no timers or
polling, work that would delay a click runs off the main actor, no logging, no files other than settings); the source
policy scan; the `why.md` Preserve / Change / Avoid / Risk set.

## What the human asked for that bears on the design

Verbatim: "Make the UI modern, use liquid glass UI patterns and the axiom macos skill. If app does not have multiple
windows, the windows switcher still should be shown so you are sure that the feature is working, but it should just
not switch apps and indicate only once screen. When the app has multiple windows the switcher should show them and let
you swipe to them. It should show the window preview and some title helping to indicate the window. For the UI/UX,
interactions and animations for now use your best judgement, later we will refine it more together."

So: Liquid Glass through AppKit's `NSGlassEffectView`/`NSGlassEffectContainerView` as the existing panels do (Apple's
AppKit Liquid Glass guide is cited in the index); the visual and motion parameters concentrated where they can be
refined later without touching policy; your own judgement on the look and motion, stated as decisions.

## Discipline

Follow the runner prompt in the shared reference. Prefer one deep module per body of knowledge over layers; the window
switcher and the app switcher share one recognizer state, one selection policy and one presenter pattern wherever the
knowledge is the same, and differ only where the domain differs. Do not design a second state machine, a second event
hop or a second blocking mechanism. Name modules, not file paths.
