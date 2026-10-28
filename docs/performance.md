# Performance

How much of the Mac Trackpad Launcher uses, measured on Release builds, and how to measure it again. The product promise is the least resources technically possible (`product-overview.md`). Add each new run as a dated entry under Results, newest first, and keep the method stable so entries compare.

## Method

### Build
`Scripts/perf/build.sh` builds the tools and a Release app into `build/perf/`. It uses the same `-O`, whole-module optimisation, universal binary and hardened runtime as the notarized release, with local Apple Development signing in place of Developer ID, which does not change runtime cost. Never measure a Debug build: it is unoptimised, and it opens the animation tuner. Opening the perf build stops every other running copy by itself, so only one copy reacts to gestures. Accessibility stays granted across rebuilds signed by the same identity.

### Tools
- `sampler` (`Scripts/perf/sampler.c`): `proc_pid_rusage` on the app's pid once per interval. It reports user plus system CPU, instructions, cycles, package idle wakeups, interrupt wakeups and phys footprint. Its own MultitouchSupport callback counts the frames the trackpads delivered in each interval, so every second is labelled touching or not touching. The sampler's cost lands in its own process, not the app's.
- `mtidle` (`Scripts/perf/mtidle.c`): a bare MultitouchSupport client with a no-op frame callback. Sampled beside the app during the same touches, it gives the floor any app that reads touches pays.
- `summary.sh`: the per-frame cost of each sampler TSV: CPU in the touching seconds divided by the frames delivered in them.
- `session.sh`: the guided run below, with spoken cues and one TSV per phase.
- Instruments Time Profiler, attached to the running app: `xctrace record --template 'Time Profiler' --attach <pid> --time-limit 30s --output <file>.trace`. Export with `xctrace export --input <file>.trace --xpath '/trace-toc/run[@number="1"]/data/table[@schema="time-profile"]' > <file>.xml`. `python3 -I Scripts/perf/profile.py <file>.xml` then prints CPU per thread and the top frames. The profiler adds some cost of its own, so use it for attribution, never for the numbers.
- `footprint -p <pid>`, `vmmap --summary <pid>` and `heap <pid>` for memory composition.

### Scenarios
`Scripts/perf/session.sh <pid> <outdir>` runs them in order: hands off (60 s), pointer and scroll (40 s), launcher taps, app switcher swipes, window switcher swipes, swaps, the settings window, hands off again (60 s). A person at the trackpad follows the spoken cues.

The headline number is **CPU per trackpad frame during ordinary pointer and scroll use**: the user touches the trackpad all day, and every frame reaches the app. Report it with the share of one core it adds up to while touching. Measure attribution as an A/B: the app against `mtidle` over the same touches, or the app against a build with one component removed.

### Known limits
- `ri_billed_energy` read 0 for most phases, so it is not reported. Use CPU time.
- Measure startup by quitting the app, relaunching it with `open`, and sampling every 500 ms for 6 s.
- A listen-only event tap (to count events by type) recorded nothing from a terminal without Input Monitoring permission.

## Results

### 2026-10-18: event tap gated (PR #18)
Mac15,6 (Apple M3 Pro), macOS 26.6.2, Xcode 26.6, branch `feature/014-gate-event-tap` (plan 014). The click tap is split into a press tap that is always on and a gated tap over drags, pressure, scroll and the system gesture types. The gated tap is on only while a trackpad may need blocking.

| 40 s of pointer and scroll use | CPU per frame | Share of one core |
|---|---|---|
| Round 1 | 0.062 ms | 0.42% |
| Round 2 | 0.055 ms | 0.38% |
| Round 3 | 0.061 ms | 0.42% |
| Round 4, after one thumb-first swipe and one scroll | 0.076 ms | 0.58% |

Time Profiler over 30 s of pointer and scroll use: 111 ms sampled, 0 ms on the `ClickTap` thread, all of it on the MultitouchSupport frame thread. Ordinary use no longer routes events through the app. Round 4 is the highest because a dropped scroll that ends without momentum keeps the gated tap on until the next scroll gesture (plan 014, open question 2).

### 2026-10-17: baseline audit
The same Mac, origin/main `9557bc2`.

| Scenario | App CPU | Per frame | Notes |
|---|---|---|---|
| Hands off, 60 s (twice) | 0.77 ms in total (0.001%) | – | 0 idle wakeups, 1–4 interrupt wakeups per minute |
| Pointer and scroll, 40 s | 889 ms (2.2% of the phase) | 0.36 ms | |
| Launcher taps, about 10 in 40 s | 779 ms (1.9%) | 0.25 ms | Includes the launch animation |
| App switcher swipes, about 6 in 30 s | 1362 ms (4.5%) | 1.08 ms | |
| Window switcher swipes with previews, about 6 in 30 s | 744 ms (2.5%) | 0.58 ms | |
| Swaps, 20 s | 148 ms (0.7%) | 0.19 ms | |
| Settings window and one picker, 25 s | 1166 ms (4.6%) | – | One-off rendering |
| Startup, first 6 s | 1078 ms, almost all in the first second | – | Settles at 0 |

**Memory.**
- After launch: 37–42 MB phys footprint, with a 63.5 MB lifetime peak.
- After the settings window was first opened: 57 MB, and it stays there after the window closes. MALLOC_SMALL went from 22 to 36 MB, plus 7 MB of CG images and 3.5 MB of CoreAnimation.
- About 20 MB of live heap in 145k allocations, much of it AppKit layout, CFStrings and the app scan's URLs and file caches.

**Attribution of the pointer and scroll cost.**
- Pointer only: the app took 0.221 ms per frame, against 0.020 ms for `mtidle` over the same frames.
- Scroll only: 805 ms in 30 s, against 26 ms for `mtidle`.
- Time Profiler over 30 s of pointer and scroll use put 84% of the app's CPU on the `ClickTap` thread, inside SkyLight's event-tap machinery: decoding each event sent to the tap and re-posting it. `ClickTap.handle` itself was about 1% and `GestureRecognizer.step` about 2.4%.
- During swipes, about a quarter of the CPU was the switcher panels' per-frame `show` (Core Animation commits and `NSView.setFrame` on the glass highlight).

**A/B over the same 40 s of use:**

| Build | CPU per frame | Share of one core |
|---|---|---|
| Shipped | 0.391 ms | 2.34% |
| Same build with no tap installed | 0.058 ms | 0.27% |

Plan 014's budget (0.088 ms per frame) is this no-tap figure plus 0.03 ms.

## Decisions
- **Gate the event tap: done (plan 014).** The always-on active session tap made every scroll, drag and system gesture event on the Mac a synchronous round trip through the app. It cost about 2.3% of a core whenever a finger was down, and put the app in the latency path of all scrolling.
- **Fewer redraws in `SwitcherPanel.show`: rejected.** It would save a few milliseconds per swipe, and skipping unchanged transforms would likely change the icon-grow animation, which plan 013 keeps unchanged.
- **Release the settings window's content on close (about 15 MB): rejected.** Plan 003 keeps pickers instant on every open, and freed small-heap memory is often not returned to the system, so the saving is uncertain. Measure what the 15 MB is before revisiting.
- **Per-frame allocations in the recognizer and the frame parser: not worth it.** They are a few percent of a cost that is now near the floor.
