# Rubric: launch bounce design

Score each criterion 1–5 for each candidate, with one or two lines of evidence quoted or cited from the candidate.

1. **Requirement and evidence fidelity.** Every R1–R19 scenario can be traced through the Usage and the signatures to an observable outcome. The lifecycle handling matches the probed facts in `grounding/index.md` (completion arrives at check-in and may carry a terminated app; menu bar apps get no workspace notifications; AX registers only at about finishing launching and needs a one-shot window read then; activation is not a window signal; "running" read by process, R14 by the model's own state). Gaps the platform forces are named, not hidden.

2. **Ownership and interface depth.** The model owns every decision (bounce, launch animation or nothing; which ending and when) behind a small interface; the platform owns rendering, pointer and macOS signals behind few, deep port members that speak domain types only. No shallow modules, pass-throughs, temporal decomposition or information leakage (the red flags). A future maintainer can extend it (a new ending, a new knob) by touching one place.

3. **State correctness.** Per-app bounce state is modelled so invalid combinations cannot be represented: each bounce ends exactly once; stale or duplicate signals (a second completion, a window after the cap, a late deadline, R14's repeated gesture) cannot act on a bounce that ended or on another app's bounce; concurrent bounces (R13) cannot interfere.

4. **Testability at one high seam.** R1–R14 scenarios run synchronously at the model's seam (the `World` harness) with in-memory adapters that inject lifecycle signals and control time; R4–R8, R13, R15 geometry and motion are pure functions testable like `LaunchFlightTests`; nothing a test needs requires waiting in real time, a real app launch or a screen.

5. **Architecture fit and honesty about rule changes.** Zero idle cost once the last bounce ends (monitors, observers, panels gone); no display-driven loop; time handled per the timer ban or the ban changed explicitly with its rationale; fire-path ordering preserved; every changed contract (architecture Concurrency and Privacy text, the port docs, the glossary, source-scan confinement) named with its reason, and nothing more changed than needed.

6. **Tuner fit.** All R17 knobs, applying to the next bounce, snapshotting tuning at bounce start (the preview swap-and-restore); a preview with no timer; tolerant decoding so old presets load with shipped bounce values; Release unchanged.
