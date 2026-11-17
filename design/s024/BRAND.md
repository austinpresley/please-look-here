# Look Here Please identity

Austin selected C11 Cream with the S1 composition on 17 November 2026.
This is the current logo and branding direction.

## Logo

Use the actual lavender toy hand from `assets/hand_lavender.png`. Its shape,
material and shading stay intact. The hand is tilted 35 degrees, enlarged
and placed as in S1, with the lower stick cropped at the tile edge.

The canonical native source is `assets/AppIcon.icon`. Its hand layer is
byte-identical to the selected C11 source from
`design/brand-refresh/lemon-colors-2026-11-17/C11/AppIcon.icon`.
The earlier redrawn glove, attention dot, coral field and upright studies
are superseded as the main identity.

The product name is Look Here Please. Keep that order in visible text.
The line is "Point it out." The descriptor is "Pointers and screen annotations
for Mac." Credit the product direction and branding to Austin Presley.

## Colors and type

| Token | Hex | Use |
| --- | --- | --- |
| Cream | #F5F0E7 | Default icon field, repository banner and page background |
| Lavender | #C9ABF0 | Supporting accents and dark-mode buttons; the hand keeps its original colors |
| Purple | #7050A0 | Links, primary buttons and the tagline on cream |
| Plum | #30233D | Text and outlined wordmark |
| Dusk | #51426D | Selected native Dark icon field |
| Paper | #FFFCF6 | Light button text and supporting surfaces |

`assets/brand.json` stores these tokens and the shared name, line and descriptor.
Wordmarks use Arial Rounded MT Bold, outlined into SVG paths for delivery.
Body copy uses the system sans-serif. Native app controls retain system type
and their existing accent behavior.

## Applications

The README banner uses the actual diagonal hand on cream, with an oversized
rounded wordmark and plum text. The page pairs the same identity with real
art from the hand collection. Use the native tile in small logo placements,
favicons and plugin identity; use the untiled hand for larger illustrations.

The default and Dark native icon retain the purple hand. System Tinted and
Clear treatments come from Icon Composer. TintedDark has reduced contrast.
The existing menu bar controls retain their dedicated monochrome state marks.

Keep TinyHand by Kamran Ahmed and the original MIT license visible in credits.
The owned repository is https://github.com/austinpresley/please-look-here.
GitHub Pages is not configured, and no public app download is available.
Public copy must distinguish the local review app from the earlier functional
source on main. Publish only curated branding/presentation paths from the
working tree. Hosted CI stays disabled.

## Rebuild

Run `scripts/make-icons.py` to compile CAR/ICNS and native menu symbols, then
`scripts/make-branding.py` for native looks, web marks, outlined wordmarks,
banner, social art, hand lineup and local plugin identity. Run
`scripts/review-icons.py` for the native appearance sheet.

The branding exporter supports the selected embedded-raster SVG source,
rather than the old hard-coded vector layer names. It requires Pillow,
fonttools, librsvg, the installed Arial Rounded font and local Xcode with
Icon Composer. The `.icon` and outlined web assets contain their own artwork.
No runtime art download is added.

Stream Deck branding PNGs are part of the plugin's exact source hash contract.
Regenerate them before the next plugin/app package build. Changing the source
identity does not replace or update the currently installed app by itself.
