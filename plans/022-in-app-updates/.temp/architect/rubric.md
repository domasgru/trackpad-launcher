# Rubric: plan 022 design candidates

Success for this task: a design a maintainer can implement slice by slice, that delivers every R1-R14 scenario on the probed platform behaviour, keeps the network exception exactly as narrow as the requirements state, fits the codebase's two-model shape and its structural rules, and leaves the update logic in one place a future change can extend without breaking an invariant.

Score each criterion 1-5 per candidate, with one or two sentences of evidence (cite the candidate's section and the requirement or grounding fact).

## C1. Requirement coverage and correctness
Every `R<N>` and each scenario traces through the usage and the signatures, with no gap and no contradiction. Weigh hardest the subtle ones: one check per closed→open opening and none on a re-front (R1); a check in flight dropped on close (R1); no request at a login start, in a development build (including `--as-release-build`, O7), outside /Applications or while the move dialog asks (R2); the highest offer this Mac can run (R4); a cancelled admin prompt returning to the available state (R11); Close during installing letting the install finish and the new version open with its window (R13); the reopened window checking again (R9).

## C2. Ownership, depth and the domain model
The update sits behind a small interface at a clean seam consistent with the `Lifecycle` / `Launcher` split; it does not bloat either model with scattered flags, and it does not add pass-through layers. The card's states and the offer are types that make illegal states unrepresentable; policy (version order, choosing the offer, what an outcome does to the card) is pure. Judge by the design red flags: shallow modules, information leakage (wire or framework types crossing a port), temporal decomposition, pass-throughs.

## C3. Platform soundness and safety
The design rests on the probed facts, not assumptions: the self-relaunch needs `createsNewApplicationInstance` (R-3); the swap is `replaceItemAt` (R-1) and the admin path's restart gap is addressed or explicitly accepted against R13 (E8, R-5); genuineness pins team, identifier, notarisation and version with resources validated (V1); the request's headers are constant and non-identifying with an ephemeral session (N1-N4, G2); the stall rule uses the request's idle timeout (N3); quarantine is cleared; a crash or kill at any point converges (no half-installed app, no leftover file beyond what the next run cleans up), with the effect order stated.

## C4. Fit with the architecture's rules
Ports with exactly two adapters each and no `async` in the model; framework and wire types stay in adapters; `LauncherCore` imports Foundation and Observation only; no timers, polling or sleeps; no logging; files written only where the docs will say; the source scan relaxed the established way (a token moves from banned to confined in one owning file, the remaining network bans stay and obvious bypasses are banned); docs and glossary changes named.

## C5. Testability at one high seam
The requirement scenarios run at one named seam (the models over in-memory adapters, synchronously), with a handle for every completion and push the update depends on (check, progress, finish, failure, verification, install outcome, the old copy's exit) so tests can hold, withhold, deliver late or deliver after close. Pure policy is unit-testable. Real-adapter behaviour that matters (headers, stall, unpack, swap, admin script) has a concrete real test. What stays manual is named and minimal.

## C6. Release path and extensibility
R14 is concrete and simple: one command still makes a release; the tag/version, the asset format and the minimum-macOS declaration are robust and parseable in the one request R3 allows; an older version will keep finding newer releases even as the release format grows. A future maintainer can add a field or a rule without coordinated edits across modules.
