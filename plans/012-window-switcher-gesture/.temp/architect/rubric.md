# Rubric: window swipe design candidates

Success for this task: a maintainer can implement the window swipe from the package without re-deciding anything, every
requirement scenario is traceable through the usage and the signatures, the shape honours the architecture's rules and
the grounded platform facts, and the next feature (say, closing a window from the switcher, or live previews) extends
it without breaking an invariant. Score each criterion 0 to 3, with the evidence (section and lines of the candidate).

## C1. Requirement coverage and traceability

Every R1 to R17 scenario can be traced through the usage and the type sketch: the recognizer's vertical start and
direction-once rule (R1, R2), the fixed list and its ordering rules (R3, R4), the panel (R5, R6), permissions and hints
(R7, R8, R14), selection and raise-as-you-go (R9, R10), the lift's order, focus, restore and silence (R11, R12), the
one-row cases (R13), blocking, rejoin, thumb lift and cancellation (R15), the setting (R16), previews in memory only
(R17). Nothing is designed that no requirement asked for. 3 = every scenario traceable with no gap; 0 = requirements
missing or invented behaviour.

## C2. Interface depth at the seams

The public surfaces are small and hide the AX, CGWindowList, ScreenCaptureKit and TCC complexity: domain types only
across ports; the model is the single decision-maker; the shell renders state and forwards intents; pure policy
(row derivation, selection, re-stack order, naming) is in value types and pure functions; the window switcher reuses
the swipe's recognizer state, selection maths and presenter pattern instead of duplicating them; no pass-through
methods, no options that expose stages. 3 = deep modules with one place per decision; 0 = shallow wrappers, duplicated
policy, framework types leaking.

## C3. Architecture and platform-fact conformance

Honours `docs/architecture.md` and the grounding: exactly two adapters per port with async deliveries behind a port and
a test handle; nothing on the main actor that would delay a click beyond what the swipe already pays, capture off the
main actor; no timers or polling (the TCC push, workspace notifications and user events only); the source policy
(confinement of `AXIsProcessTrusted`, `notify_register` and new API families, `LauncherCore` imports); privacy (no
files, no logging, previews only in memory). Uses the probed facts correctly: `AXRaise` restores a minimised window;
a closed window answers `-25202`; a minimised window's subrole is unreliable; windows on other Spaces must not be
raised; `CGWindowListCreateImage` is gone; the AX messaging timeout; the `com.apple.tcc.access.changed` push. Handles the
degraded cases (no Accessibility, no Screen Recording, no private symbol, an app that does not answer, a window that
closed). 3 = conforms and uses the facts; 0 = contradicts the architecture or a probed fact.

## C4. Testability at one high seam

Names the seam each scenario runs at (the `World` end-to-end seam for the model, `TouchScript` for the recognizer,
pure values for policy) and gives tests handles for previews arriving later, the permission changing, a window closing
between frames and an app not answering; says what stays manual and why; the fakes are small and shaped by the port.
3 = every scenario has a seam and a handle; 0 = tests would need to reach past the interface or wait on real time.

## C5. Maintainability and reader load

Short call chains (a swipe or a window swipe traceable in three files); the direction decision in one place; the
visual and motion parameters in one tunable place so the human's later refinement touches no policy; invariants
encoded in types (an illegal row state cannot be built; the front window and the all-minimised case are distinct
variants, not flags); the diff to the recognizer and the model is the smallest that makes the window swipe a sibling
of the swipe; tradeoffs and alternatives are stated honestly. 3 = a future maintainer extends it without breaking
invariants; 0 = scattered booleans, duplicated choices, a second pipeline.
