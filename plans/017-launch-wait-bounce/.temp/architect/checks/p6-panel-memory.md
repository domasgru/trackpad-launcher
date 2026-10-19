# Check P6: memory of a display-sized bounce panel (after fan-out)

Why: candidate 1 holds the bounce row in one click-through panel the size of the pointer's display; candidate 2 rejects that for "a display-sized backing store (about 24 MB at 2x)" and moves a small panel on every pointer event instead.

Program: `p6-panel-memory.swift` (this directory), built and run from `/tmp` on this Mac (1512×982 @2x), 2026-10-19. Prints the process's `phys_footprint` (Activity Monitor's Memory) while a borderless clear `.screenSaver` panel with a layer-backed content view holds one 60 pt icon layer bouncing forever, first in an 84×120 panel, then in a panel the size of the display, then after 300 actions-disabled position moves.

Printed:
- start 6.0 MB; small panel bouncing 10.6 MB; small closed 10.1 MB
- display-sized panel bouncing 10.9 MB; after 300 moves 10.9 MB; closed 10.8 MB

**Conclusion:** in our process a display-sized panel whose root layer draws nothing costs about 0.8 MB more than a closed one, the same order as the small panel; no display-sized backing store is allocated in our footprint. What the WindowServer spends compositing it is not attributable from here (unmeasured). Candidate 2's 24 MB figure does not hold for our process.
