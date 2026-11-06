# Rubric: automatic updates design

What success looks like here: a Mac that keeps itself current for years with nobody watching, where every failure is silent and self-healing, and where a maintainer upgrading Sparkle can find every place the design depends on Sparkle's behaviour. Failures in this path are invisible by requirement, so a design has to be right by construction, not by observation.

Score each criterion 1 to 5. Quote the part of the candidate the score rests on.

## 1. Requirement fit where Sparkle falls short

Do R6 (both halves), R9, R11, R12, R13 and R3 actually hold, traced through the signatures and the order of effects? A 5 holds each on a stated mechanism, with the probed fact it rests on, and names the residual gap. A 1 assumes Sparkle covers them, or leaves an R's scenario unreachable.

## 2. Reliability under failure

For each point the process, the helpers or the network can die, does the system converge to a whole working copy and a later retry? A 5 walks the order of effects and leaves nothing armed, nothing stale and no state that needs a person. A 1 has a path that strands the user with no gestures, or one that restarts the app after a Quit.

## 3. Depth and ownership

Is one module the owner of update decisions, behind a small interface, with no Sparkle or wire type crossing a port and with the coupling to Sparkle's private behaviour in one findable place? Would a maintainer extend it without breaking invariants? A 5 hides substantial policy behind few methods and makes illegal states unrepresentable. A 1 scatters update logic across `Lifecycle`, `Launcher` and the shell, or has shallow pass-through ports.

## 4. Honest fit with the standing rules

Does it keep `why.md`'s Preserve list, change each broken rule on purpose with the doc and source-policy edits named, and stay within what Sparkle documents as the common path wherever that meets the requirement? A 5 lists every rule touched, with its reason, and needs the fewest departures. A 1 bypasses a rule quietly or adds machinery a documented path would have given.

## 5. Testability at one high seam

Can the requirement scenarios run at a named seam, with handles on the clock, the contact and window signals, connectivity, Sparkle's callbacks and the process ending? Is the line between `swift test`, a built-app run and a by-hand check drawn honestly? A 5 lets a test provoke every failure the design claims to handle. A 1 relies on waiting or on manual checks for logic that could be pure.

## 6. Release safety

Can a release fail at any step and leave nothing half-published, with R7 and R16 held by the script rather than by care? Is the update key's handling, the build-number rule and the card contract enforced by a check? A 5 makes publishing a broken or unnotarised update impossible and keeps the card's rules alive in a check. A 1 relies on the release author remembering.
