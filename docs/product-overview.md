# Product Overview

Trackpad launcher is an app to launch apps on MacOS using gestures on trackpad. The app is displayed in the menubar only, you never see it in the dock. Menubar window design - [image](./menubar-window.png). In menubar window you can select an app for each available gesture. Trackpad launcher has 2 modes left hand and right hand (which toggle is currently missing in design) and 5 tap gestures: thumb held on the top left corner (right hand mode), or top right corner (left hand mode) and tapping the rest of the trackpad with 1, 2, 3, 4 or 5 fingers - each gesture should launch or focus / open / maximise the app selected in the window - plus the swipe: with the thumb held in the corner, sliding two fingers sideways shows up to 10 running apps like ⌘-Tab (the switcher), the app in front first and the others from most to least recently used; sliding right reaches older apps, and lifting brings the selected one to the front - and the swap: resting two fingers on the trackpad and tapping the thumb in the corner swaps the two most recently used apps, like a quick ⌘-Tab, with nothing shown on screen; while the fingers stay down, each further thumb tap swaps back again. The swipe and the swap each have their own switch in the window.

### Additional notes
- After installation trackpad should continously run in the background
- Trackpad launcher should be as performant as possible, consuming the least possible resources as it's technically possible. We don't need performance tests, but we should just pick the most performant technical path available when doin technical research.
- Trackpad launcher should be secure and privat - it should do 0 network calls, no logging.
- Each gesture, should be followed by a smooth haptic feedback and a subtle gentle sound effect (the sound effect is still deferred). The one exception: a swipe lift or a thumb tap that changes nothing is silent, whether the user lifts on the starting app, on an app that quit, or with no switcher showing, or taps the thumb with nothing to swap to.
- We should use the latest liquid glass human interface design.
- All the design assets needed for this app are kept in /assets directory.

