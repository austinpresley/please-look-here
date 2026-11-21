# Four playful icon ideas

Austin asked for more fun with the actual original white and purple hands.
The hands here are the original PNGs embedded unchanged inside SVG layers.
SVG transforms set their position, scale and angle. Native Icon Composer
renders the background, mask, depth and appearances. No hand was generated,
traced, recolored or repainted.

| ID | Idea | Why try it |
| --- | --- | --- |
| S1 | Lemon pop | One big diagonal lavender hand against yellow. The clearest and strongest app icon of this set. |
| S2 | Double take | White and purple fingertips meet. The most playful expression of the two source assets. |
| S3 | Sticky situation | The hand sits over a peeled note. Connects pointing to the app's screen annotations. |
| S4 | Ribbon dance | An oversized white hand over pink and yellow stripes. A louder, playful direction with the opposite diagonal. |

S1 is my first pick. The hand occupies more of the tile, the yellow separates
from lavender, and it works with a single object. S2 is the playful alternate
if the brand should feel more like a character. S4 has more visual noise at
16 pixels. S3 can suggest a notes app when shown without its name.

All four `.icon` documents compile locally with Xcode `actool`. Each has real
Icon Composer exports in Default, Dark, TintedLight, TintedDark, ClearLight
and ClearDark. Default and Dark also have direct native 32 and 16 pixel
exports. The appearance contact sheets downsample the large renders for
their small examples; the main idea sheet uses the direct native small exports.

`originals/` contains byte-identical copies of the two existing hand PNGs.
`source-artwork.json` records their hashes. The SVG layers embed the same PNG
bytes, which preserves the actual hand shape and source shading.

Native tinted and clear treatments mute the source colors. The two-hand
composition becomes harder to distinguish in those looks. These are visual
explorations, and the production icon and running app have not changed.

Rebuild from this repository with `python build.py`, using Pillow, Xcode and
Icon Composer. Open `S1/AppIcon.icon` through `S4/AppIcon.icon` to edit them.
The experimental `probe/` folder was used only to establish native support
for embedded raster art and is excluded from delivery.
