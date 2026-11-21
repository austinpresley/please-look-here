# Look Here Please: four playful icon ideas (Opus round)

Each concept uses the actual in-app hand PNG. None of the hands were redrawn or regenerated. The new props are original SVG drawn in `tools/build.py`. There is no text and no SF Symbols. All four are native Icon Composer documents, compiled with `actool` and rendered with `ictool`.

| # | Concept | Hand | What happens to the PNG |
|---|---|---|---|
| 1 | **Ta-da!** The white glove rises out of an upside-down magician's top hat, with a few sparkles. | `hand_glove.png` | Nothing. It's a byte-identical copy (`cmp` passes). |
| 2 | **Boop.** The purple hand comes in sideways from the left edge, like a manicule (☞, the old "look here" mark), and pokes a pop-art burst. | `hand_lavender.png` | Exact 90° pixel remap with no resampling. Rotating the decoded output back gives byte-identical pixel data. |
| 3 | **X marks the spot.** The white glove drops in from the top and points straight down at a red X on a sand island. | `hand_glove.png` | Exact 180° pixel remap with no resampling, verified the same way. |
| 4 | **Puppet show.** The hand already sits on a stick, so it becomes a puppet. It pops up on a curtained stage, leaning in to point. | `hand_lavender.png` | Tilted −12° with CoreGraphics high-quality resampling. This is the only resampled hand. |

The parent round has diagonal purple on yellow, a high-five, pin-through-paper and stripes; none of these four repeat those.

## Pick: 1, Ta-da!

- The hand file is unchanged, so this concept meets the "actual original hand" requirement with no caveat.
- A white cartoon glove already reads as a magician's glove, so the metaphor needs no explanation. "Ta-da, look here" also fits a presentation tool.
- The hat solves the long-handle problem. The handle drops into the hat, so the hand can be large (scale 1.08) and the tile has no awkward cropped stick.
- It holds up best at small sizes: a white upright hand over a black hat on indigo still reads at 16 px. The sparkles drop out at 16 px without leaving noise.

Runner-up: **2, Boop**. It's the most energetic and the most "pointer" of the four, and the hand and burst still read at 16 px. The tradeoffs are a short stub of handle at the left edge and a background that `automatic-gradient` renders lighter and mintier than the specified teal.

## Tradeoffs and true limits

- **Rotation:** Icon Composer has no rotation property; `position` only takes `scale` and `translation-in-points`. Any angled hand therefore has to be a rotated copy of the raster. Concepts 2 and 3 use exact quarter-turn copies; concept 4 is resampled. `provenance.json` records the source and layer SHA-256 for each concept.
- **X marks:** the white glove on light blue is the weakest at 16 px, and a downward point reads less like "pointer" than the others.
- **Puppet:** the busiest of the four. At 16 px it reads as a red frame with a purple blob, and its hand is the resampled one. At Dock sizes it's the most charming.
- **Dark mode:** only the background changes in Dark. The props keep their colors.
- **Tinted and clear looks:** these are the system's own treatment. TintedDark is low-contrast for all four, worst for Ta-da. See `appearances.png`.
- **Not done:** I only checked these through `ictool` exports. I didn't open them in the Icon Composer GUI. Nothing was installed, and no production assets, prior proposals or app source were changed.

## Files

- `contact-sheet.png`: the four concepts with the 512 px Default render, plus Dark at 128, 64, 32 and 16 px.
- `small-size-review.png`: actual 16 and 32 px exports, the same pixels enlarged with nearest neighbour, and 128 px, in Default and Dark.
- `appearances.png`: all six native renditions for each concept.
- `exports/<concept>-<Look>-<px>.png`: individual PNGs. Default and Dark are at 1024, 512, 128, 64, 32 and 16 px; the four tinted and clear looks are at 256 px.
- `concepts/<concept>/AppIcon.icon`: the native source documents. `concepts/<concept>/compiled/`: `actool` output (`Assets.car` and `AppIcon.icns`).
- `tools/build.py`: rebuilds everything with `python3 -I tools/build.py`. It needs only the standard library, Xcode `actool`, Icon Composer `ictool`, `swiftc` and `rsvg-convert`. `tools/pngraw.py` is an exact stdlib PNG codec used for the lossless rotations. `tools/rasterkit.swift` handles the tilt and the nearest-neighbour zooms.
