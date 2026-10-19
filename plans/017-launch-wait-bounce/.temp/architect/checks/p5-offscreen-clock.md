# Check P5: a Core Animation clock in a panel that shows nothing (after fan-out)

Why: R6 lets the whole bounce row be cut off by a display's top edge (pointer on the menu bar's top pixel), so a design that keeps its deadlines as animations on layers in the bounce's panel must know whether they survive a panel that is off every display, empty, moved off mid-way or ordered out. Grounding F24 showed only that a layer in *no* window stops at once.

Program: `p5-offscreen-clock.swift` (this directory), built and run from `/tmp`, three runs on this Mac, 2026-10-19. A 2 s 1→1 opacity animation with a delegate, on the content layer of a click-through `.screenSaver` panel that is (a) entirely above every display, (b) given an empty frame, (c) moved above every display 0.5 s in, (d) ordered out 0.5 s in.

Printed (three runs): every case completed with `finished == true`, 2015–2057 ms after it was added (15–57 ms late; all four in the same callback batch each run). `isVisible` stayed true for (a) and (b).

**Conclusion:** once a layer has been committed inside a window, its animation completes on time give or take ~60 ms whatever that window's frame or ordering does afterwards; only a layer never committed in a window stops at once (F24 c). Lateness is ~1 ms while the panel is composited on screen (F24) and up to ~60 ms while it is not. Adequate for the 2 s grace, 10 s cap and 3 s preview.
