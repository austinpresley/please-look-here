# Per-hand gesture artwork

This folder is the design handoff for Claude. It contains complete replacement
canvases for the two built-in gesture slots. No app source or bundled asset was
changed. Nothing was committed, uploaded or delivered.

36 of 36 pairs passed this design sub-agent's visual review. All 72 finished
PNGs passed the disk audit, and all 72 remained byte-identical after rerunning
normalization. There were 75 image-generation calls, including new attempts for
both black poses and coral OK. Claude's lead review is still pending.

No anatomy or canvas failures remain. Coral OK has a slightly angular right
palm edge. Generated grain, stitching, veins, sparkles and reflections follow
the same materials but are not pixel-identical to the pointing pose. The
plush/robot one-pixel bottom-edge adjustment is documented below.

## Files

- `<id>-ok.png` maps to slot `first`.
- `<id>-shaka.png` maps to slot `second`.
- `contact-sheet.html` shows every material as base, OK, Shaka on light, dark
  and checkerboard backgrounds. Open a sprite for its full-resolution PNG.
- `contact-sheet-light.png` and `contact-sheet-dark.png` are full-canvas sheets.
  Each row repeats the three sprites on all three backgrounds.
- `reviews/detail-*.png` show larger hand/cuff crops for visual review.
- `review-inline.html` is the compact material/background selector used for
  the T3 review preview. Its close-up thumbnails live in `reviews/`.
- `manifest.json` records each prompt, input references, generation attempts,
  selected attempt, transforms, deterministic checks, visual review and status.
- `generation-log.json` is the original prompt/attempt log. `raw/` retains the
  generated inputs. `manual-review.json` records the visual decisions.
- `audit.py` reopens and checks finished images without normalizing them again.
  It writes `audit-report.json`, including PNG and base-reference hash checks.
- `check_determinism.py` reruns normalization and compares the finished PNG byte
  hashes. Its result is in `determinism-report.json`.

The manifest's `pairs_passed` is the current accepted pair count. Do not infer
acceptance from a file merely existing.

## Generation

Each output was generated separately with the built-in `image_gen.imagegen`
tool in edit/reference mode and `transparent_background=true`. The first
reference was `assets/hand_<id>.png`, which locks character, material, palette,
lighting, camera and cuff. The second reference was `assets/gesture_ok.png` or
`assets/gesture_shaka.png`, used only for the finger pose. The prompts explicitly
require five digits and preserve special styles such as voxel, low-poly,
knitted yarn, articulated robot and bone.

Generated files are copied into `raw/<id>-<pose>-<attempt>.png`. Generation is
stochastic. The normalization step is deterministic. The original built-in tool
may also retain its own generated file in the Codex image cache.

To regenerate a sprite in a tool-enabled Codex session:

1. Read its selected prompt and references from `manifest.json`.
2. Inspect the base PNG, then call `image_gen.imagegen` with that prompt, both
   reference paths and `transparent_background=true`.
3. Save the returned PNG as a new numbered file in `raw/`. Add an attempt entry
   to `generation-log.json` with `id`, `pose`, `attempt`, `prompt`, `raw`,
   `reference`, and `pose_reference`.
4. Review the new candidate. Put its attempt number in `manual-review.json` as
   `selected_attempt` and record `pass` plus concrete `notes`.
5. Run the normalization command below and inspect the contact sheets again.

No CLI/API image-generation fallback was used.

## Local normalization and checks

Run from this folder:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install --no-cache-dir -r requirements.txt
.venv/bin/python process.py
.venv/bin/python audit.py
.venv/bin/python check_determinism.py
```

The existing `.venv` already contains the required packages. The script only
writes inside this folder. It does not invoke Swift or repository build/test
scripts. It reads base images from `../../assets/`.

`process.py` removes diffuse alpha residue, clears hidden RGB under zero alpha,
and keeps edge antialiasing within two pixels of meaningful coverage. It fits
the generated wrist to the base rod center and cuff profile. It then restores
the original cuff and rod against the cleaned base. All solid cuff/rod pixels
remain exact. Final alpha cleanup can remove a few low-alpha fringe pixels at
the restoration boundary, recorded as `cuff_stick_pixel_difference_count`. A smooth
horizontal contour warp over the last 100 rows of the lower palm meets the
original wrist outline, followed by a 12-row color/alpha blend. This avoids
double outlines where two independently rendered wrist silhouettes meet.
Wood also receives a small RGB gain calibrated against the original lower-palm
median to remove a warmer generated tint. The gains appear in the manifest.
Pixel artwork uses
nearest-neighbor resampling. Other artwork uses bicubic resampling.

When generated fingertips sit above the base's hand crop, the script compresses
the upper hand vertically about the fixed wrist. A horizontal fit leaves at
least 16 pixels of side margin when needed. These transforms are combined before
sampling, so an intermediate crop cannot lose the fingertips. It never moves
or rescales the restored cuff or rod. Exact transforms appear in the manifest.

Checks reopen the finished PNG and verify:

- 1024 x 1536 RGBA with real transparent pixels.
- No nonzero alpha on any canvas edge.
- Cuff/stick bounds within three pixels of the original base.
- All solid cuff/stick pixels equal the cleaned original base. Full-region
  equality and any low-alpha cleanup differences are also reported.
- No hidden RGB under zero alpha and no diffuse alpha beyond the two-pixel edge.
- All opaque fingertips lie within the base `handTop` crop.
- The raw generation has no opaque pixels on its top or side canvas edges,
  so normalization cannot hide an already cropped digit.

The original `plush` and `robot` rods touch the bottom canvas edge. Their final
edge row is cleared, shortening those rods by one pixel. This is reported in
the manifest. All other anchor geometry remains at original coordinates.

Anatomy, pose readability, style and visible halos are visual review decisions,
not inferred from pixel dimensions or alpha connectivity.

## Bundling rules for Claude

These are full-canvas artwork replacements. Load their CGImages directly and
retain the base `HandAsset` geometry. `HandGestureCatalog.image` already treats
custom saved gesture canvases as complete images of exactly the base size.

Do not pass these files through `HandMaker.makeGesture` or `composeGesture`.
`makeGesture` interprets the entire opaque input bounds as a hand-only image,
rescales it into `reference.handTop...reference.wrist`, and adds the base rod.
A full-canvas input would therefore shrink the hand and double-compose the rod.
`composeGesture` is the path for the generic starter source assets only.

Use the proposed order: custom import, bundled per-hand artwork, generic starter
composition. Resolve `first` to `ok` and `second` to `shaka`. A bundled image must
have exactly the base width and height. Include the selected per-hand bundle
asset in the gesture cache signature so replacement artwork invalidates cache.

All coordinates in `process.py` and the manifest use top-left PNG coordinates.
The cuff restoration line is specific to each base. The app crops the hand
using the base `handTop` and `wrist`, so preserve that metadata when swapping
the image. Do not redetect anchors from an OK or Shaka silhouette, whose width
and highest digit differ from the pointing hand.

`RESTORE_Y` and `base_restoration_y` describe the post-processing join. They can
sit in the lower palm and are not the runtime `HandAsset.wrist` anchor.
