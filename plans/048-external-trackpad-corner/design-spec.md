# Design spec: thumb corner group with mixed trackpads

Source: Figma `EB5ptBWZnAot7J3vx3cYLw`, node `2231:13555` ("Form Group"), read with `get_design_context`. Screenshot: `.temp/figma-thumb-corner.png`. The human asked to follow it closely.

Group (the existing rounded settings group): background fills/quaternary `rgba(0,0,0,0.03)`, corner radius 12, horizontal padding 10. Two cells separated by a 1 px divider labels/quinary `rgba(0,0,0,0.05)`; each cell has 2 pt vertical padding around its row.

## Cell 1: the thumb corner rows (ONE cell, no dividers inside)
Row: min height 42, vertical padding 16, vertical stack with **16 pt spacing** between its three lines, all full width:
1. **"Thumb corner:"** (with colon) at the leading edge, no control. SF Pro Medium (weight 510) 13 pt, line height 16, labels/primary `rgba(0,0,0,0.85)`.
2. **"MacBook trackpad"**, **20 pt leading indent**, label at leading edge (same font), and at the trailing edge the corner pop-up: value text ("Top left") right-aligned, same font, then 12 pt gap, then the chevron badge (`chevron.up.chevron.down`, bold, 10 pt, in a 16×16 circle filled `rgba(0,0,0,0.08)`). This is the same pop-up look the single *Thumb corner* row uses today; reuse it.
3. **"External trackpad"**, same as line 2 (value "Bottom left").

The design spells "Macbook"; the agreed copy is "MacBook trackpad" (Apple's spelling).

## Cell 2: "Hide background apps"
Unchanged from today: label leading, standard switch trailing, row min height 42, vertical padding 16.

## Single-row mode
When the Mac does not have mixed trackpads, the group stays exactly as today.

## Notes for implementation
Match these metrics in SwiftUI's grouped `Form` on macOS 26: a single `Form` row/cell containing a `VStack(alignment: .leading, spacing: 16)` of the title and two `LabeledContent`/`HStack` lines with `.padding(.leading, 20)`, so the grouped form draws no separators between them. Prefer the system's own label font/colours (they map to the tokens above) over hardcoded values. Verify by screenshot of the running settings window side by side with the Figma screenshot (hand check M1).

## Human's correction after review (2026-11-13)
Between the MacBook trackpad and External trackpad pop-ups: 15 pt, badge to badge. From the External trackpad pop-up to the divider below the cell: 15 pt. Both measured on a screenshot of the running window, 30 px at 2x each.
