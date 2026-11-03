# Task: design in-app updates for Trackpad Launcher (plan 022)

## The artifact

One candidate **design package** for plan 022, shaped exactly per the *Design package template* in the shared design reference (`## Design` with Problem, Usage, Shape with the type sketch, an empty Synthesis decision, Tradeoffs accepted, Alternatives considered, Open questions and risks, Next implementation step), in Swift, against this codebase. Write it to your output path and nothing else.

## Inputs

- Requirements R1-R14, the Solution and the Non-goals: `plans/022-in-app-updates/plan.md`. Every `R<N>` and each of its scenarios must be traceable through your usage and signatures.
- The grounding: start at `plans/022-in-app-updates/.temp/architect/grounding/index.md`. It lists every fact with its standing (probed / sourced / open) and points to `how.md` (the traced model of the code), `why.md` (the rationale and its Preserve / Change / Avoid / Risk constraints, which the design must answer to) and the probes. Read the code the design touches where a decision rests on it.
- `docs/architecture.md`, `docs/domain-model.md`, `docs/product-overview.md`.

## What the human asked for

"I am against network requests, but the app updates would be exception. I want trackpad launcher app to be able to receive an update. When update is available I would like to show the CTA as in this design" (Figma node 2143-1845: the update card at the top of the settings window). After reviewing the requirements: "go ahead". The network exception must stay as narrow as R1-R3 state.

## What the design must address

1. **Ownership and seams.** Where the update lives relative to `Lifecycle` (owns the process: start, reopen, quit, the move) and `Launcher` (owns gestures, settings, the window's open/closed state). The update spans both: it is triggered by the window's closed→open transition and shows in the window, yet it quits and replaces the process and changes the quit policy. Name the module(s), their interfaces, and what they hide.
2. **Data shapes.** The version, a release as the app understands it (parsed from the wire at the adapter), the offer, and the card's states (available, downloading with progress, installing, failed) as types that make illegal states unrepresentable. Where the running version, this Mac's macOS version, the team identifier and "release build in /Applications" come from (E2, O7, O8).
3. **The check (R1, R2, R4, R6).** Exactly one check per closed→open opening, none on a re-front, none at a login start, none while closed, none in a development build or outside /Applications or while the move dialog asks; a check in flight when the window closes is dropped and its result never kept. Choosing the offer (R4) as pure policy.
4. **The request (R3).** Its exact URL and headers given G1-G6 and N1-N4 (GitHub demands a User-Agent; URLSession leaks versions and languages by default; no query string; ephemeral session; nothing written to disk but the update).
5. **The download (R7, R12).** Progress, *Cancel*, the 30-second no-progress rule without any timer of the app's own (N3), deleting the file on cancel, failure and success, *Try again*.
6. **Genuineness (R8).** Same Developer ID team, notarised, same bundle identifier, the offered version; where this check lives given the confinement rules (V1-V4, E14).
7. **Installing and relaunching (R9, R11, R13).** The swap into /Applications (unprivileged and administrator paths, E7, E8, R-1, R-5), what a restart mid-install leaves (R13), a cancelled admin prompt returning to the available state (R11; the move ends the process instead), stopping the old version and opening the new one with its settings window open (R-2, R-3, R-4: a self-relaunch with the default open configuration only reopens the old process).
8. **Carry-over (R10).** Settings, starting at login (E9, O2), permissions (V5, O3); no first-run step.
9. **Quit and close (R13).** Close or Quit during a download; Quit disabled and every ordinary quit only closing the window while installing; logout/restart still ending the process.
10. **The card (R5, R7, R12).** Where it sits in `SettingsView`, how the window resizes when it appears (E10), the disabled Quit button's look.
11. **Ports, adapters and the source policy.** New ports with their real and in-memory adapters (two each), how asynchronous delivery keeps model tests synchronous, which tokens move from `banned` to confined and in which file, which new confinements the update adds, and the `docs/architecture.md` / product-overview / glossary changes.
12. **The release process (R14).** How a release is published so every older version finds it: the tag and version, the asset and its format (O6), the minimum-macOS declaration (O5), and the changes to `Scripts/release.sh`.
13. **Testing seams.** The one high seam the requirement scenarios run at, and a handle for every boundary a test cannot wait for or provoke (each completion held, each push withheld or injected). Say what stays manual.

Out of scope: anything the Non-goals exclude.
