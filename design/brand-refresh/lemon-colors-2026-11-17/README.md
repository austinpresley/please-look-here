# S1 Lemon pop color combinations

Austin selected S1 Lemon pop and requested more color combinations. This set
keeps S1's original purple hand, 35 degree angle, scale, placement, shadow and
framing. Only the Default and Dark background colors change.

Open `gallery.html` for the self-contained comparison. Select a palette to
compare it with the original S1 and switch between Default and Dark.
`lemon-colors-default.png` and `lemon-colors-dark.png` show all twelve at once.
The PNGs and gallery include direct native 32 and 16 pixel renders.

| ID | Palette | Default background | Dark background |
| --- | --- | --- | --- |
| C1 | Lemon, original | #F7CD35 | #51426D |
| C2 | Butter | #FFE5A0 | #514331 |
| C3 | Apricot | #FFAF72 | #603D37 |
| C4 | Tangerine | #FA762D | #632E29 |
| C5 | Watermelon | #FB696F | #592C4B |
| C6 | Bubblegum | #FFADD1 | #552B56 |
| C7 | Lime | #D7ED69 | #3A492A |
| C8 | Mint | #78D9BD | #254941 |
| C9 | Lagoon | #1E9EAA | #174F59 |
| C10 | Sky | #73C7ED | #273D60 |
| C11 | Cream | #F5F0E7 | #51426D |
| C12 | Midnight | #24203D | #181627 |

C7 Lime and C9 Lagoon are my favorite new alternatives. C1 retains the
original bright complementary palette. C12 gives the glove strong separation
but makes the black handle less prominent. The warm colors offer a louder
direction; Butter, Bubblegum and Cream are softer.

The hex values are the source colors for Icon Composer's automatic gradient.
The rendered tile includes the system's lighting and gradient treatment.
Dark palettes are proposals alongside the Default colors. System Tinted and
Clear appearances replace the palette, so their renders are similar across
these options; TintedDark retains the earlier contrast limitation.

Each `C1/AppIcon.icon` through `C12/AppIcon.icon` is editable and self-contained.
The hand SVG is byte-identical to the selected S1 source, including its embedded
original hand PNG. `palettes.json` records source layer checksums and colors.
Native groups and layer properties were checked against S1; only background
specializations differ.

All twelve compile locally with Xcode `actool` and have Icon Composer renders
in all six native appearances. Default and Dark were also rendered directly at
32 and 16 pixels. The comparison gallery was checked at 728 and 360 pixels and
with a different palette selected in Dark, without console errors.

These are color studies. The selected composition is recorded in the project's
brand document; production assets and the running app have not changed.

Rebuild from the project checkout with `python build.py`, then `python gallery.py`.
The scripts require Pillow and local Xcode with Icon Composer. The source
`.icon` folders contain their own artwork and can be opened directly.
