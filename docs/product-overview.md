# Product Overview

Trackpad launcher is an app to launch apps on MacOS using gestures on trackpad. The app is displayed in the menubar only, you never see it in the dock. Menubar window design - [image](./menubar-window.png). In menubar window you can select an app for each available gesture. Trackpad launcher has 2 modes left hand and right hand (which toggle is currently missing in design) and 4 gestures: thumb held on the top left corner (right hand mode), or top right corner (left hand mode) and tapping the rest of the trackpad with 1, 2, 3 or 4 fingers - each gesture should launch or focus / open / maximise the app selected in the window.

### Additional notes
- After installation trackpad should continously run in the background
- Trackpad launcher should be as performant as possible, consuming the least possible resources as it's technically possible. We don't need performance tests, but we should just pick the most performant technical path available when doin technical research.
- Trackpad launcher should be secure and privat - it should do 0 network calls, no logging.
- Each gesture, should be followed by a smooth haptic feedback and a subtle gentle sound effect.
- We should use the latest liquid glass human interface design.
- All the design assets needed for this app are kept in /assets directory.

