# Task: design the liquid app switcher (plan 024)

## The artifact

One candidate **design package** for plan 024, shaped per the Design package template in `/Users/dominykasgrubys/code/skills/plugins/dev-workflow/references/design-reference.md`. It contains Problem, Usage (caller's view), Shape (type sketch in Swift with `fatalError("not implemented")` bodies and pseudocode), Tradeoffs accepted, Alternatives considered, Open questions and risks, and Next implementation step. Leave Synthesis decision empty. Write it to your output path and nothing else. It will be compared against another runner's package and then synthesized into `plans/024-fluid-app-switcher/plan.md` under `## Design`.

## Inputs

- Requirements: `plans/024-fluid-app-switcher/plan.md`, R1 to R17, with their scenarios and non-goals.
- `docs/architecture.md`, `docs/domain-model.md`, `docs/performance.md`, `docs/product-overview.md`.
- Grounding: start at `plans/024-fluid-app-switcher/.temp/architect/grounding/index.md`. It indexes `how.md`, `why.md` (with its Preserve / Change / Avoid / Risk constraint set), the raw explorer files, and the probes in `grounding/probes/`. The probes include their sources, their printed output, and window captures under `probes/captures/`. Look at the captures. Facts marked *probed* were measured on this machine today.
- The code under `LauncherKit/Sources` and `LauncherKit/Tests` wherever your design touches it.

## What the human asked for (verbatim)

> "I want to create a more joyful app switcher when swiping recent apps with 2 fingers. It should work something like this: All app icons are surounded with one kinda fluid shape, on the selected app that fluid shape is bigger and it organically suround the selected icon. When you swipe, that there is organic wave going through that shape which is fully reactive to the swiping, and then when the next app icon is selected that wave kinda enlarge and suround the new icon, and go away from the previous icon. I might be not using the best words, but try to understand my idea and put it the right way for yourself when planning. Ask me anything if needed."

On the swell size: "agree, but make sure it's easy to tweak it and make it subtle"

## What the design must address

1. **Every requirement R1 to R17 and each of its scenarios**, traceable through your usage and your signatures. Name, for each R, the type or function that carries it.
2. **How the shape is built so it is real Liquid Glass** (R1 to R4, R14). The grounding shows that only SDF-merged glass in an `NSGlassEffectContainerView` reads as Liquid Glass (index A1, A2, A8). Decide the elements (band, beads, necks, swell, or whatever you choose), their geometry, and how that geometry derives from the row layout so icons and shape cannot drift.
3. **How motion is produced, especially the motion that must continue after the input stops**: the flow and its wobble (R6, R7), the spring-back (R5, R10), the settle (R9) and the wave's decay (R8). This is the decision the grounding leaves open (index open questions 1 and 2):
   - render-server animation of merged glass is reachable only through AppKit's private `CASDFElementLayer` mirror (A5, A6);
   - every public path runs in-process per display frame, at 30 to 100 times the CPU, against `docs/architecture.md`'s animation rule (A4, B1, B2).

   Make the call your model thinks best, and defend it against the product's least-resources mandate, the architecture rule and the private-API precedent (B3). Name the fallback if the mechanism disappears in a macOS update. Name any change to `docs/architecture.md` your design needs, and say why.
4. **The per-input-event path and its cost** (R15, index A7, C5), including whether and how motion is interpolated between trackpad frames on a 120 Hz display.
5. **Where finger speed comes from** for R8 (C2), and how the wave stays within R8's bounds whatever the speed.
6. **Retargeting**: a selection change during a flow goes to the newest icon, never queues (R6, R7). Also what happens on a lift mid-motion (R12), on open (R11, already settled, no grow-in) and on close (the 150 ms fade, R11).
7. **Reduce Motion** (R13) and **zero work at rest or hidden** (R16): no animation that loops or outlives the settle.
8. **Tuning in one place** (R17). Every look and motion number lives in one value whose defaults are the shipped look. The swell's size is one setting, and setting it small makes the swell subtle without changing anything else. State the module the value lives in, given the module walls (B4, B5).
9. **What stays untouched**: the window switcher's look and behaviour, `SwitcherSelection`'s and `GestureRules`' behaviour for the window switcher, selection, ticks, row contents and lifting (plan non-goals). `OverlayPanel` is shared (C6): say what happens to it.
10. **The seam tests run at.** Name it. State what a test can drive and observe there for each motion requirement, and which handles the design gives a test: Reduce Motion, finger speed and time, and the absence of whatever mechanism plays the motion. Also state what can only be checked by hand (R2, R15, R16).

Prefer a deep module: a small interface hiding the liquid's geometry and motion policy. Keep framework and private types out of `LauncherCore` and off any port. Name modules, not file paths.
