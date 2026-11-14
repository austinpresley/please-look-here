# Look Here Please identity

By Austin Presley. A playful Mac utility for pointing and annotating while presenting.

Original vector motif: a cream pointing glove reaches toward an attention dot.
The plum cuff keeps the gesture readable against warm coral. Icon Composer owns
macOS masking, depth and appearance treatment. No donor glyph or SF Symbol.
The menu bar uses the same simplified silhouette in a template image, with a
hollow dot when off and a filled dot when on. Meaning also has native state labels.

Considered alternatives: focus ring on blue; annotation loop on cream. The glove
has the clearest connection to the app's hands at small sizes. Use the complete
name, Look Here Please. Short line: Point it out.

Owned source: https://github.com/austinpresley/please-look-here
No owned website is verified. No upstream analytics, social identity or download
URL should identify this fork. Keep TinyHand / Kamran Ahmed and MIT in Credits.

Curated publication must explicitly distinguish local review capabilities from
functional source still on remote main. Do not publish the dirty source tree.

## Rebuild and review

Use Python with Pillow installed and `rsvg-convert` from librsvg. Xcode must
include Icon Composer. `scripts/make-icons.py` compiles the native CAR/ICNS and
menu symbols. The review build runs it after the plugin leaf, before app assembly.
`scripts/make-branding.py` exports six native appearances, repository/site marks
and plugin/category PNGs. `scripts/review-icons.py` makes the size/appearance sheet.
The leaf plugin consumes only the checked-in `streamdeck/branding` PNGs, all
covered by its exact source hash contract. Regenerate those before rebuilding a
changed identity. There are no runtime art dependencies or downloads.

The default glove is cream on coral. Dark explicitly keeps a cream glove on
plum. Tinted and clear treatments come from Icon Composer. Hand paths and dot
are original filled SVG geometry. The thin cuff is secondary; finger and dot
remain the main signal at small sizes. The native template menu symbols use the
same gesture with a tighter crop. The icon is not a new always-visible Dock UI;
Look Here Please remains a menu bar utility.
