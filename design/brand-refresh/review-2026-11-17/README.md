# Look Here Please branding review

Austin requested a better identity, including the app icon, and an independent
proposal from Opus 5.5 at high effort. Both proposals are included here.

Open `comparison.html` for the interactive comparison. It is self-contained.
`branding-comparison.png` is the quick side-by-side image. The source folders
contain editable Icon Composer documents, SVG art, native appearance exports,
menu bar symbols and brand applications. The generator scripts are designed
to run from this project checkout on Austin's Mac.

## Recommendation

Use the soft toy direction in `../sol-2026-11-17/` as the basis. The bigger cream
glove and complete short handle connect directly to the app's pointer collection.
Keep the full product name, Look Here Please, the coral field and "Point it out."
Rounded letterforms suit the physical toy. The untiled glove works as a website
illustration, while the native tile covers Finder, Settings and About.

Opus independently reached the glove-on-a-stick idea. Its version in
`../opus-2026-11-17/` makes the gesture explicit by aligning a graphic glove
with an amber target. Its website study also uses the real hand collection,
which is a good addition to the eventual public presentation.

The main difference is emphasis. The soft version puts the toy first and has
more solid hand area. Opus puts the pointing action first; its gaps and target
ring become harder to distinguish at small sizes. Both deserve a real menu bar
check before adoption. Both TintedDark treatments inherit lower contrast from
the system's tint mapping.

## What the current branding needs

The existing glove is small relative to the tile, the raised thumb competes
with the pointing finger, and the finger does not line up with the dot.
The cuff looks like a shadow. The branding does not show enough of the actual
toy-hand character. Scaling the old mark alone would leave those issues.

The public name is already Look Here Please. Keep that spelling in visible
copy; renaming the repository or moving the checkout is unnecessary for this
branding work.

## Integration after choosing a direction

1. Copy the chosen Icon Composer layers and menu symbol sources into the
   existing production asset locations.
2. Update `scripts/make-branding.py` before regenerating exports. It currently
   reads only the first icon group and hard-codes the old `front.svg`,
   `back.svg` and `attention.svg` names. Neither new source is a safe drop-in
   for that exporter. The native compiler accepts the candidates.
3. Regenerate CAR/ICNS, all six appearance checks, website/favicons,
   repository banner/logo and Stream Deck branding. The Stream Deck asset
   hash contract also needs the matching regenerated files.
4. Apply the wordmark and chosen descriptor to the website and repository.
   Preserve the real release status, attribution, links and MIT credits.
   Add the hand collection from Opus's site concept.
5. Update icon appearances in Welcome, Settings and About through the shared
   asset. Keep system type in app controls, existing version/update controls,
   user accent behavior and native layout.
6. Build locally, inspect the actual menu bar and own app windows in light
   and dark appearances, then package the review app locally. Hosted CI stays
   disabled.

## Completed verification

Both proposals compiled with local Xcode `actool` and were exported through
Icon Composer in Default, Dark, TintedLight, TintedDark, ClearLight and ClearDark.
The recommended icon also has direct 32 and 16 pixel native renders. The parent
inspected both contact sheets, menu bar art and the identity comparisons.

The comparison and the soft direction's website/About HTML were checked at
728 and 360 pixels with no browser console errors. The Opus panel was also
rendered separately. Small text in the soft direction uses ink on coral at
4.72:1. Cream on coral is reserved for large lettering.

These are finished design proposals. The running app, production assets,
existing source changes and published materials were not changed. No app
build or real menu bar installation is claimed.
