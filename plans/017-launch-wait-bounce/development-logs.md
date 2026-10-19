# Development logs: Launch bounce

## Specify
- R2 (running apps float up) contradicted R13 (a repeat gesture during a bounce plays nothing) once the app had started up → R2 now defers to the same-app rule (R14), with a scenario.
- "Not running" was undefined for an app already launching from the Dock → R1 defines it as no process when the gesture fires; such an app gets the launch animation, with a scenario.
- The problem statement claimed nothing shows during a cold launch, but the Dock bounces → reworded; "Suppressing the Dock's own bounce" added to non-goals.
- R7/R8 forbade trailing and squash that the tuner offers → scoped to the shipped tuning.
- R5 "centred on the tip" clashed with the edge and row rules → R5 covers a single icon, except as R6 and R13 say.
- R6 below-pointer mode was ambiguous → rests 8 pt below the arrow and jumps downward; scenario for crossing onto the menu bar mid-bounce; the rule covers the whole row.
- "Finished starting up" was not observable → R10's scenario uses the Dock's bounce stopping as the proxy.
- The overall cap was implicit → new R12: 10 s from the gesture; a late window plays nothing.
- R13's gap closing could be instant or animated → slides over about 0.2 s.
- R14's "bring to front as usual" was unclear for a launching app → asks macOS to open it again, nothing visible changes.
- R4 stated the size twice → "the launch animation's icon size, 60 pt as shipped".
- R1 never asserted the app launches → added; R14 asserts the window shows.
- Missing scenarios → crash during startup, and the first-launch "are you sure" dialog (accepted to run to the cap).
- The tuner requirement bundled five → split into R17 (knobs), R18 (preview), R19 (presets); the tuner's purpose stated.
- Rejected: "gestures inactive" is undefined (it is in the glossary); dropping the squash and trailing knobs (the user asked for them); dropping the 2 s grace after start-up (the user confirmed it); fading the icon when the setting turns off mid-bounce (the setting applies to the next gesture, as the glossary says).
- User review: the icon always stays above the pointer → R6 drops the below-the-pointer mode; at the top edge the icon is cut off by the edge instead.
