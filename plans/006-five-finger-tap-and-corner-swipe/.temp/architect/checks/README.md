# Checks: evidence gathered after fan-out

Not visible to the runners (grounding was frozen at fan-out). Each entry names its standing as the grounding index does.

## F36 (probed): a SwiftUI `ScrollView` with `layoutPriority(-1)` sizes the window and absorbs the deficit alone

`scrollview-fit-probe/main.swift`, run 2026-10-11 on this machine (`xcrun swiftc -O -swift-version 6`, Xcode 26, macOS 26), `output.txt`:

- A `VStack` of a fixed 40 pt header, a `ScrollView { VStack { 30 rows × 24 pt } }.layoutPriority(-1)` and a fixed 40 pt footer, padded 16, `.frame(width: 266).fixedSize(horizontal: true, vertical: false)`, hosted in an `NSHostingView`: `fittingSize == (266, 856)`, exactly the natural height (16 + 40 + 12 + 720 + 12 + 40 + 16).
- With the window's content size set to 266 × 400 and again 266 × 300, the measured heights were header 40, footer 40, list 264 and then 164: the list alone absorbed the whole deficit each time.

Conclusion: the shell can cap the panel's height in `LauncherPanel.fitToContent` (`min(fittingSize.height, visibleFrame.height − margin)`) and SwiftUI's own layout gives the deficit to the one flexible child; no observable cap handed into the view (candidate 2's `WindowLimits`) is needed, and the root's `fixedSize` must become horizontal-only. Settles the candidates' R22 disagreement in favour of candidate 1's mechanism. Not probed: a `List` in the same position (its natural height is not its content's, so the window could not grow with it under `fittingSize`).
