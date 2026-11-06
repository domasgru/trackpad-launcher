# Figma notes: settings window frame

Source: file `EB5ptBWZnAot7J3vx3cYLw`, frame `2193:21747` ("Utility Panel", 326x749, radius 15).
Values come from `get_design_context` and `get_metadata` unless marked "rendered", which means sampled from `figma-frame.png`.
Coordinates are in points. Figma strokes do not affect layout here: the card border adds nothing to the metadata sizes.

Screenshot: `figma-frame.png` is 366x789 at 1x. That is the frame plus 20pt of shadow margin on each side.

## Accessibility card

Form Group `2193:21755`.

- Group size: 294x76, at x=0, y=0 in `2193:21754`. Page padding around it is 16.
- Group padding: horizontal 10, vertical 0.
- Group fill: `fills-opaque/quaternary`, rgba(0,0,0,0.03). Rendered #F7F7F7 on white.
- Group border: 1px solid #DEDEDE. The other form groups have no border.
- Group radius: 12. Overflow is clipped.
- Row `2193:21756`: 274x76, at x=10, y=0. Vertical stack, gap 8, padding top and bottom 8, min-height 42. Bottom border 1px `labels/quinary`, rgba(0,0,0,0.05).
- Vertical check: 8 + 28 + 8 + 24 + 8 = 76.

Text `2193:21757`:

- "Allow Accessibility access to make trackpad gestures work reliably."
- Style: Subheadline/Regular. SF Pro Regular, size 11, weight 400, line height 14, letter spacing 0.
- Colour: `labels/primary`, rgba(0,0,0,0.85).
- Frame: 216x28 (two lines), at x=0, y=8 in the row. Fixed width 216.

Button `2193:21963`:

- Size: 134x24 at x=0, y=44 in the row. Height is fixed at 24; width is hugged.
- Padding: horizontal 16 (`button/padding-horizontal`). Radius: 6 (`button/radius`).
- Fill layers, bottom to top: Tint `accents/blue` #0088FF, then Fill `fills-vibrant (use plus-lighter/darker)/quaternary` #F7F7F7.
- Rendered fill: #0080F7, sampled at two points. The Fill layer's blend mode is not in the design context; it is not a plain opaque #F7F7F7 cover, since the button renders blue.
- Label: "Open Settings...", white, SF Pro Medium, weight 510, size 13, line height 16, centred.

## Gear

Vector `2193:21759`, a child of the card, painted after the row, so it sits on top of it.

- Size: 91x91.
- Position in the card: x=222, y=-23 (metadata, relative to the card frame).
- The design context gives left=221, top=-24. That is the same place: CSS measures from inside the 1px border.
- Clipped by the card: 23 off the top and 19 off the right (222 + 91 = 313, card width 294). Bottom edge at y=68, inside the 76 card.
- Horizontal overlap with the text frame: text ends at x=226 in card coordinates, gear starts at 222. The rendered glyphs are short of that edge in the screenshot.
- Fill: #DEDEDE, solid, one path. Same colour as the card border.
- Opacity: none. No opacity on the node in either design context call and none in the SVG.
- Asset: `gear-export.svg`, root width=91, height=91, viewBox="0 0 91 91", 6494 bytes, root attributes `preserveAspectRatio="none"` and `overflow="visible"`.

## Switch windows row

Row `2193:21863`, in Form Group `2193:21851` (294x204, padding horizontal 10, radius 12, fill rgba(0,0,0,0.03), no border).

- Row size: 274x110, at x=10, y=48 in the group.
- Row layout: vertical stack, align trailing, gap 4, padding top and bottom 9, min-height 42. Bottom border 1px rgba(0,0,0,0.05).
- Vertical check: 9 + 28 + 4 + 60 + 9 = 110.

Top line `2193:21864`: 274x28, at x=0, y=9. Space-between.

- Gesture image `2193:21866`: 45x28, radius 4, x=0.
- Gap image to title: 10.
- Title `2193:21871`: x=55 in the row, y=6 within the line, 183 wide, 16 tall. "Switch windows", SF Pro Medium, weight 510, size 13, line height 16, `labels/primary`.
- Toggle `2193:21872`: 36x16 at x=238, y=6. Track #0088FF, knob 21x13 white, inset 2 from the right.

Hint block `2193:21873`: 219x60, at x=55, y=41 in the row. Vertical stack, gap 8, min-height 42. Right aligned in the row, so x=55 follows from 274 - 219.

- Title x and hint x are the same: 55 in the row, 65 in the card.
- Hint text `2193:21874`: 219x28 (two lines) at x=0, y=0, full block width.
  "Allow Screen Recording access to show previews in the window switcher."
  SF Pro Regular, weight 400, size 11, line height 14, `labels/primary` rgba(0,0,0,0.85).
- Triangle: SF Symbol `exclamationmark.triangle.fill`, inline at the start of the text at the same size 11, colour #FFCC00, followed by one space in the same coloured span.
- Button `2193:21875`: 134x24 at x=0, y=36 in the block. Gap 8 from the text.
  Fill rgba(0,0,0,0.08), rendered #E4E4E4. Horizontal padding 16, radius 6, height 24.
  Label "Open Settings...", `labels/primary`, SF Pro Medium, weight 510, size 13, line height 16, centred.

Neighbouring rows in the same group, for comparison: Switch recent is 48 tall (`2193:21852`), Toggle recent is 46 tall (`2193:21876`, padding 9).
