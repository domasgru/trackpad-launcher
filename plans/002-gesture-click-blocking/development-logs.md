# Development logs: Click blocking and forgiving taps

## Specify
- Cross-reference named the wrong 001 requirements → now names R11 finger count, duration and press rule, R20, and the amended 001 non-goal.
- Lone finger in the corner could swallow ordinary clicks → presses with only the anchored thumb down pass; baseline and lone-finger scenarios added.
- Press straddling the window or a drag in progress was undefined → new requirement: a press is blocked or passed as a whole.
- Press-and-hold while blocked was unnamed → scenario: nothing clicks, no gesture fires.
- Tap boundary and finger bounce were undefined → tap defined; a re-landed finger counts once; two quick 1-finger taps scenario.
- R3 scenario unverifiable → outcome tied to the haptic at lift with no added wait.
- Click blocking going live was hidden in the hint requirement → its own requirement; hint requirement covers only the hint, with exact copy.
- Mouse clicks were in scope without a stated problem → mouse clicks, pointer and scrolling are never blocked.
- Accessibility use was unbounded → app uses it only to block clicks, never reads or changes other events.
- First-launch prompt plus hint → window is open after the prompt, hint shows if not granted.
- Missing non-goals and 3-second rationale → added.
- Rejected: continuing 001's requirement numbering. Each plan numbers from R1 and cites the other plan by path.
