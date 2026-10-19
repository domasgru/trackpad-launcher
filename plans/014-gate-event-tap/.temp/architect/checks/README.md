# Checks gathered after fan-out (not part of the grounding the runners saw)

## two-tap-order.swift (runs 1-4)

Question (candidate 1's open question 1): do two active session taps on one run-loop thread receive events in posting order across the two ports? Tap A masks `mouseMoved` (5), tap B masks `scrollWheel` (22); 300 pairs of moved (to the pointer's current location) and zero-delta scroll events were posted, and each callback appended its tag to one sequence.

| Run | Posting | Result |
|---|---|---|
| 1, 2 | As fast as possible (600 events in about 100 µs) | Not alternating: long runs of one tag (the run loop drains each port's queue in turn once a backlog exists); extra callbacks from the user's own pointer and scroll input during the run (342 and 328 moved, 300 and 336 scroll) |
| 3 | One pair every 2 ms (500 Hz) | 300 and 300, **strictly alternating** |
| 4 | One pair every 8 ms (125 Hz) | 300 and 300, **strictly alternating** |

Conclusion drawn: while the tap thread keeps up (every event handled before the next arrives, the case at trackpad rates with a ~20 µs callback), cross-port order is the posting order. Order across the two ports is not guaranteed once a backlog builds, i.e. if the tap thread stalls for several milliseconds: a withheld press's first drags could then be decided before its down and pass as plain drags. Mouse moves are a type the window server may coalesce, so the first two runs' tag counts are not a measure of loss.

`CGEvent.tapIsEnabled` cost 20-47 µs per call (1000 calls, four runs): a window-server round trip, acceptable on a notice (rare), not per event.

## SwapTests:324 (read, not run)

`fromTheFirstSwapUntilTheFingersLiftClicksAndScrollsAreBlocked`: fingers rest, the thumb taps and stays (a series), the fingers slide 10 mm, then `scroll(.fingers(.began)) == .drop` with no `mayBegin` offered before. A fake that marks the scroll filter `.unseen` at every reopening would answer `.passStill` here, failing an existing test (R2). A fake that knows no opening event was withheld keeps nil and answers `.drop`.

## ScrollFilterTests:47-57 and DockSwipeFilterTests:31-36 (read, not run)

The forget tests pin only a `.changed` after the forget (`.pass` with the flag down, `.passStill` with it up), which an `.unseen` stage answers the same way. No existing test pins a `began` under the flag after a forget.

## Recognition's initializer (grep)

`Recognition(event:blocksClicks:blocksDockSwipes:)` is constructed only at `GestureRecognizer.swift:200`; every test reads the accessors, so replacing the stored Bools with one level and derived accessors keeps every test compiling.
