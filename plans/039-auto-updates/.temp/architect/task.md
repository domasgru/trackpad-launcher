# Task: design automatic updates for Trackpad Launcher

## Artifact

One design package, shaped per the Design package template in the shared reference, for the requirements in `plans/039-auto-updates/plan.md`. Swift 6 type sketches, signatures and module boundaries with `fatalError("not implemented")` bodies and pseudocode, plus a shell sketch for the release script's new steps. Leave Synthesis decision empty.

## What the human asked for, verbatim

"implement auto udpates, so we no longer have a card, and updates are being downloaded and installed automatically. Do it according best, most common practises. It should work reliably"

"i will be afk, continue straught to implementation planning after prd"

The human is away. Decide; don't leave a design question open that the sources settle. Questions go in Open questions and risks only when only the human or a real Mac can answer them.

## Fixed by the plan

Sparkle 2 is the updater. It replaces the hand-written check, download and install. There is no update interface of any kind. R1 to R16 are the requirements; the Non-goals bind too. Do not reopen these.

## What the design must settle

Each of these is a real decision. `grounding/index.md` holds the facts and marks what is probed, sourced, disputed and open. Read it first and rest decisions on it.

1. **Which Sparkle path, and what crosses into our code.** What is on Sparkle's public API, what depends on its private behaviour, and where that coupling lives so it can be found when Sparkle is upgraded.
2. **Ownership.** Whether `Updater` survives and what it owns; what `Lifecycle` and `Launcher` learn; which module holds what. `LauncherCore` imports Foundation and Observation only. Each port has two adapters. Show the data shape first: the state an update can be in, and what makes an illegal combination unrepresentable.
3. **R8's gate.** Where "contact of any kind on any trackpad" is read, how the window's edges arrive, and how the minute passes. `docs/architecture.md` bans timers: say how the rule changes or how the design stays inside it.
4. **The hand-over, R9 and R11.** How the old copy ends, how the new one starts silently with the keyboard focus left alone, what happens at each point an install can fail, and how a working copy is running within 10 seconds of a failure. State the order of effects. Say what happens if the process dies at each step.
5. **R13 and R14.** What each way of quitting does in each update state. Nothing may leave something armed that restarts the app later.
6. **R6.** Sparkle does not enforce the same Developer ID or bundle identifier, and the key-rotation path weakens the update-key half. State how each half of R6 holds, including a mismatch's veto and what happens when a veto fails.
7. **R1.** A check at every start, every 24 hours, on wake past the mark, and again when a connection arrives after a failure, without a hot loop on a persistent failure.
8. **R2 and R12.** The gate: decided where, read when, and how a copy that cannot write stays silent. A copy about to end or to ask to move must not start the updater.
9. **R3.** Headers, cookies, query string, validators, on the feed and the download, across redirects, on every Mac and version. The feed's address.
10. **The feed and the release.** Where the feed lives and how it is published given immutable releases, the order of effects in `Scripts/release.sh`, how R7 and R4 hold, where the update key lives, build-number discipline, what a failure at each step leaves behind.
11. **R16.** How every future release stays installable from the card once the card's code is gone from the tree.
12. **Build.** Where Sparkle is depended on, how it is pinned, `Package.resolved`, signing, and the keychain stall on the binary download.
13. **Deletions and the rules.** What goes, what the move keeps, which `SourcePolicyTests` rows change and why. Every standing rule in `docs/architecture.md` the design breaks is named and changed on purpose, per `grounding/why.md` Change. Nothing is bypassed quietly.
14. **Testing seam.** The seam the requirement scenarios run at, and a handle on everything a test cannot wait for or provoke: the clock, the contact and window signals, connectivity, Sparkle's callbacks, the process ending. Say which scenarios cannot run below a built, signed app.

## Bindings from the record

- `grounding/why.md`'s Preserve list binds unless a requirement here overrides it, and the design says so. Its Avoid list binds unless a fact in `grounding/index.md` section I shows it did not weigh this requirement, and the design says so.
- Prefer what Sparkle documents as the common path wherever it meets the requirement. Where it does not, say exactly why, and keep the departure as small and as findable as possible.
- Every effect in the app's normal idle stays as it is: no finger down means no work.
