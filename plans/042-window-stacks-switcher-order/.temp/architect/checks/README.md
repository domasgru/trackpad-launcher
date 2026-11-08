# Checks gathered after fan-out (2026-11-07, same Mac as the grounding probes)

Build: `swiftc -swift-version 5 -O -o probe_offmain_budget/probe ../grounding/probes/axread.swift probe_offmain_budget/main.swift`;
run with the grounding's compiled fixture. Output: `probe_offmain_budget.output.txt`. No fixture left running afterwards.

- C1 **probed** (a): a per-element messaging timeout set **on a GCD thread** caps that call there too: the stopped fixture's
  kAXWindows returned at 61 ms with 0.06 s, while 13 other apps read on other GCD threads at the same moment finished by
  +23 ms (one, pid 60097, answered cannot-complete at once). Extends grounding F9 (main thread only) to off-main reads.
- C2 **probed** (b): **one `optionAll` copy does not give the on-screen front-to-back order.** For the fixture's three
  on-screen windows, `optionAll` filtered to on-screen entries read `[65238, 65234, 65235]` while `optionOnScreenOnly`
  read `[65238, 65235, 65234]`, in all 20 samples; the 13 one-window apps matched trivially. *Conclusion*: the visible order
  must come from the `optionOnScreenOnly` copy; `optionAll` can only say which numbers still exist. A warm `optionAll` copy
  costs 2.35 ms against 0.20 ms for the on-screen copy (grounding F7).
- C3 **probed** (`probe_alive`, output `probe_alive.output.txt`): `CGWindowListCreateDescriptionFromArray` over three
  window numbers (a `CFArray` of raw `CGWindowID`s made with null callbacks) costs **0.19 ms** warm, against **2.56 ms**
  for a full `optionAll` description copy (153 windows on this Mac). It returned W1, W2 and the minimised W3 before W2
  closed, and W1 and W3 after: a closed window's number drops out, a minimised one's stays. `CGWindowListCreate` (numbers
  only) is **unavailable in Swift** ("No replacement at present"). *Conclusion*: with numbers never reused (F19), "which
  remembered windows still exist, on any Space" is one cheap call over just those numbers.
