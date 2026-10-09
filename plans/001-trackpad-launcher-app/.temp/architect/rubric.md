# Rubric: Trackpad Launcher design candidates

Success for this task: a design a future maintainer can extend without breaking invariants, where every requirement scenario in R1–R23 runs through a named seam, the platform's private and permission-free mechanisms (grounded in `grounding/index.md`) sit behind small interfaces with in-memory adapters, and the policy (recognition, active/inactive, resolution, fire-or-stay-silent) is pure and testable without hardware.

Score each criterion 0–3 (0 absent, 1 weak or contradicted elsewhere in the package, 2 present and coherent, 3 present, coherent, and simpler than the alternative). Cite the candidate section that earns the score.

## C1. Recognizer purity and scenario coverage
The recognizer is a pure core: frames (with sampled button state) in, gesture events out, clock injected, no AppKit or MultitouchSupport types inside. Every R11 scenario (thumb first, fingers first, staggered, thumb lifts early, drag, five fingers, click-during-tap, repeated taps while anchored, 1 cm / 4 cm corner geometry) is expressible as a frame sequence through one seam. Constants (corner fractions, drag threshold, tap window) live in one named place.

## C2. Adapter isolation and depth
Each platform dependency (multitouch devices + frames + actuator, trackpad preferences + change notification, IOKit/wake notifications, LaunchServices open, persistence, login item) sits behind an interface with one real and one in-memory adapter, framework types parsed into domain types behind it, thread of delivery stated, and the main-actor hop in one place. Penalise pass-through layers and leaked wire types.

## C3. Single source of truth for domain state
Gestures active/inactive (with causes) is derived in one table-driven function from connected trackpad kinds and preference values, and both the recognizer gate and the window read that same derivation. Assignment presence (found / not found) is derived, not synced. Device-set reconciliation is one idempotent operation used at launch, on add/remove and on wake. No second boolean kept in sync with a first.

## C4. Types encode invariants
Hand mode, the four gestures, assignment, activity with causes, recognizer state, gesture event and trackpad identity are sum types or branded values such that invalid combinations do not compile (no bag of optionals; no `completed: Bool` beside `completedAt?`). Swift 6 concurrency ownership (`@MainActor`, frame thread, `Sendable`) is stated and consistent with the sketch.

## C5. Caller's view and interface depth
The Usage section shows the app shell wiring with two or three real call sites, and the type sketch agrees with it. The shell coordinates few calls per operation (the fire path, the window's reads, the status item's reads); each module's public surface is small relative to the policy it hides. Reader can trace a gesture from frame to activation and haptic in three modules or fewer.

## C6. Requirement coverage and buildability
Every R1–R23 is traced to a module and seam, the silent cases of R13 and the Dock-click contract of R12 land where grounding says they work, no network import exists, the no-logging rule is a mechanism (a source-scan test), no timer or poll exists, and the build/test layout is concrete enough to slice (package/targets, deployment target 26, `LSUIElement`, universal binary, signing step) with the Developer ID gap noted.
