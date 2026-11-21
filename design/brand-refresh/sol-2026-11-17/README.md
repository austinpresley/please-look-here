# Look Here Please branding proposal

The pointing wand is the identity. Keep the complete name and the line
"Point it out." Use a larger cream glove, a short ink-colored handle and a
confident coral tile. The hand connects the logo to the pointers people use
in the app. The complete handle makes it a physical presentation toy rather
than a generic cursor glyph.

Three directions were considered. A cream pointing wand on coral is the
recommendation. The same wand on butter yellow is a color alternative. A
glove and separate attention dot keeps the current metaphor but leaves the
glove too small and divides attention between two shapes.

The proposal develops the project's original glove geometry from
`../vector/build.py`. It introduces a complete short handle, revised framing,
three native depth groups, reduced shadows and a brighter coral. The dot is
reserved for the menu bar state, where it has a job.

## Color and type

| Name | Value | Use |
| --- | --- | --- |
| Coral | #F04B32 | App icon and large brand artwork |
| Cream | #FFF5E6 | Glove and large wordmark |
| Ink | #211729 | Small text, handle and dark appearance |
| Butter | #F6C84A | Optional supporting color |
| Paper | #F5F5F7 | Neutral presentation background |

The wordmark uses rounded letterforms to echo the toy glove. The SVG wordmarks
contain outlines, so they do not require a font on the recipient's computer.
Their source is Arial Rounded MT Bold installed on this Mac. Font files are
not redistributed. Native app controls and labels keep system typography.

Small text uses ink on coral, which measures 4.72:1 contrast. Cream on coral
measures 3.38:1 and is reserved for large wordmarks and large bold headlines.
The app's existing system accent behavior should stay independent of the logo.

## Application

- App icon, Settings sidebar, Welcome and About share the native icon asset.
- Website and repository use the same wordmark, glove, colors and plain product
  description. The website hero can use the untiled illustration.
- Menu bar uses an optical reduction with a separated cuff. Its state dot is
  hollow when off and filled when on. Native labels must also expose state.
- Stream Deck plugin art, category art and browser icons are included as studies.
- Keep Austin Presley's attribution and TinyHand / Kamran Ahmed / MIT credits.
- Keep real version information, update controls and existing links in About.
- Public presentation must accurately reflect the project's actual release state.

## Files and local verification

`coral/AppIcon.icon` and `butter/AppIcon.icon` are editable Icon Composer sources.
Both compiled locally with Xcode `actool`. Their compiled `Assets.car` files
are in the adjacent `compiled` folders. Native exports cover Default, Dark,
TintedLight, TintedDark, ClearLight and ClearDark. The recommended coral icon
was rendered directly at 512, 32 and 16 pixels for each appearance. The contact
sheet shows actual small sizes and enlarged nearest-neighbor copies.

`exports/brand-direction.png` shows the brand and before/after comparison.
`exports/native-appearances.png` shows native variants. `identity-preview.html`
is a self-contained website and About layout study. It includes embedded images,
has responsive layouts and contains no remote resources or app functionality.

At 16 pixels the folded-finger detail merges, as expected. The pointing gesture
and short handle remain visible. TintedDark has lower contrast because the
system maps every foreground layer to the user's tint. The menu bar symbol
deliberately drops the finger sculpting instead of squeezing it into 18 points.

These are design proposals. Production assets, application code, the running
app and published materials have not been changed. No app tests or release
packaging were needed. All icon compilation and visual checks ran locally.

Rebuild on this Mac with a Python environment containing Pillow and fonttools:

```sh
python build.py
```

Requires Xcode with Icon Composer, `rsvg-convert` and the system typefaces.
