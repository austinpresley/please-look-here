# Look Here Please: actual hand artwork

Austin's direction is to use the actual original hand or the purple hand.
These icon sources use the existing in-app PNGs directly. The earlier redrawn
vector concepts are superseded by this direction.

- Original white: `assets/hand_glove.png`, the app's Cursor glove.
- Purple: `assets/hand_lavender.png`, the app's Lavender toy and default hand.

Every PNG inside the candidate Icon Composer documents is byte-identical to
its corresponding source file. `source-artwork.json` records the SHA-256 hashes.
No generation, tracing, recoloring or repainting was used. The native icon
documents control the scale, vertical placement and background. The lower
part of the long handle extends beyond the tile; the complete hand is visible.
The raster layer has glass disabled to preserve the existing shading.

## Recommendation

Use the purple hand on cream. The neutral field gives the lavender hand
separation, and the purple is already the app's default pointer. The original
white hand on coral is the alternative that retains the existing coral identity.
Purple on coral is included for direct comparison on the same background.

The original artwork should also carry through into the website, repository
banner, Welcome and About treatments. Keep the complete product name,
Look Here Please, and the line "Point it out." The exact hand PNG should be
used in those placements. This supersedes the illustrated hand treatments
from the first branding round.

## Verification and files

All three `.icon` documents compile locally with Xcode `actool`. Each option
has native Default, Dark, TintedLight, TintedDark, ClearLight and ClearDark
exports at 512, 32 and 16 pixels. Native appearances and framing have been
visually inspected. TintedDark has low contrast under the system's tint
treatment; the original hand colors remain in Default and Dark.

`exports/actual-hands-comparison.png` shows the three combinations.
`exports/*-appearances.png` show the six native looks for each combination.
`preview.html` is a self-contained comparison with the native appearance sheets.

The source generator expects to run inside this project checkout on Austin's
Mac with Pillow, Xcode and Icon Composer installed. The `.icon` documents are
self-contained and can be opened directly in Icon Composer.

The running app and production assets have not been changed. These are native
icon candidates using the requested original artwork.
