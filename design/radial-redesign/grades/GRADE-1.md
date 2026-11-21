# V3 shipping design grade

Sol, 16 November 2026. Frozen subject: [prototype-v3.html](../claude/prototype-v3.html).

**61/100, D. Do not ship this design as-is.** The command map is coherent. The remaining problems are execution, accessibility, recovery, and unfinished visual craft. This grade gives no credit for improvement over v2. The ten categories carry equal weight. A is 90–100, B 80–89, C 70–79, D 60–69, F below 60. A cancellation failure also blocks shipping regardless of the average.

| Criterion | /10 | One-line justification |
| --- | ---: | --- |
| Visual craft | 7 | The disc is composed, but icon-label collisions, uneven spacing, and a heavy hub keep it below shipping craft. |
| Iconography and typography | 6 | Hand-drawn glyphs, oversized symbol frames, compressed leading, and character-count truncation look provisional. |
| Color and contrast | 7 | Command selection pairs pass solid-color contrast; focus on selection and disabled light-mode text remain weak. |
| Interaction model | 6 | Reanchoring and edge arming work, but Escape during pending Hold can still lead to Clear. |
| Information architecture and copy | 8 | Eight stable root directions work; shortened Match wording and incomplete pending-action copy cost clarity. |
| States and feedback | 6 | Current and pending states differ, but Clear has no direct Undo affordance and capture feedback is only a stub. |
| Motion | 6 | Opening and reanchoring are restrained; hover/hub fades are absent and dismissal violates the specified timings. |
| Accessibility | 3 | A document key handler does not replace semantic commands, managed focus, system accommodations, or a list fallback. |
| Pointer browser | 6 | Artwork density and search work; vertical arrows are wrong, favorites cannot be edited, and Tab escapes. |
| Prototype fidelity | 6 | The main flows run, but cancellation, responsive layout, decorative window controls, and command stubs prevent sign-off. |
| **Overall** | **61/100** | **D. The design is not ready for a shipping macOS utility.** |

## Evidence and limits

I read my [round-1 review](../sol/REVIEW.md), [merged round-2 spec](../sol/ROUND2.md), all 354 lines of the frozen HTML, and all seven supplied settled JPGs. I loaded the HTML in an owned local browser tab and exercised Click and Hold, light and dark, normal and reduced motion, root and child navigation, keyboard, edge arming, Clear/Undo, disabled inspection, and the pointer browser.

T3 navigation, real browser click/hover/key input, and page evaluation worked. Its snapshot operation repeatedly returned `Preview automation snapshot timed out after 15000ms.` The computer-use fallback had no available browser tab and could not bind Chrome. Visual judgments therefore use the supplied settled screenshots, plus live DOM geometry and computed styles. I did not pretend to see a new live screenshot. Hold sequences used synthetic browser PointerEvents through the actual installed event listeners and the real 180 ms timer. They validate this prototype's state transitions, not a native modifier hook or physical trackpad performance.

The file expects the T3 rendering host to supply font/theme variables and inline absolute-path images. For direct HTTP viewing, I supplied system-font host variables and mapped the existing artwork URLs to the same local PNGs in browser memory. I changed no prototype code on disk. The small-size checks changed only the browser's stage dimensions. These host adaptations are not defects in the intended T3 presentation.

No Mac app was built or launched, no source was edited, and no commit was made. This report is the only repository file written. The reviewed HTML SHA-256 is `2ad16605a142daba551f622d25d573b22a2d87118b757deecc98ece9b8c56f6a`.

### Observed behavior

| Exercise | Result |
| --- | --- |
| Click hover versus entry | Hover previewed Color without entering. A completed click entered it at the click point with no child candidate. |
| Hold Pointer to Coral | After 210 ms, northward entry created a fresh Pointer origin and no candidate. A later eastward movement acquired Coral; release selected it once. |
| Hold edge | Invocation at stage point 20,20 clamped to 192,192 and remained unarmed. Entering radius 52 armed it. A clamped child required arming again; unarmed release canceled. |
| Hold Back and open Escape | Returning to the parent neutral region restored root. Escape after opening canceled; later release did nothing. |
| Pending Escape | Escape before 180 ms failed to cancel. The timer opened root; movement southeast and release changed `DOC.cur` from 2 to 0. |
| Click outside | An outside down/up dismissed without executing a command. |
| Clear and recovery | Clear removed both demo strokes. Command-Z after dismissal did nothing. Reopening and selecting root Undo restored both strokes. |
| Draw from Interact | Selecting a tool turned Interact off and reported the change. |
| Pointer search | No-match state worked. Searching Cloud and Return selected Cloud and closed the browser. Dark-browser search and Escape also worked. |
| Browser arrows | Seven displayed columns, but Down moved Coral at index 2 to Chrome at index 10. Midnight at index 9 was directly below. |
| Browser Quick controls | Six items appeared, with no editing control. Their order followed CAT, placing Lavender before Glove, unlike the saved wheel slot order. |
| Browser Tab | Tab left the open browser for the Click mode demo button. |
| Modified arrow | Control-Option-Right changed the radial candidate instead of leaving that chord alone. |
| Reduced motion | Scale was removed and child animation disabled. Cancellation still retained an 80 ms opacity transition. |
| Small stage | At 320 pt width, scale became 0.7917. At 300 pt height, the ring extended to y=356 and was clipped. Resizing an existing session did not cancel it. |

## Ranked defects

P0 blocks shipping. P1 must be fixed before a shipping review. P2 is craft polish, but the combined P2 work is necessary to reach 90. All line references below are to the frozen prototype unless a screenshot is named. Proposed values are logical points.

### 1. P0. Escape does not cancel a pending Hold

**Where:** lines 320–322, 328–337.

**Wrong:** The keyboard handler returns on `!sess`, while the opening timer and `press` remain alive. Escape during the 180 ms delay is ignored. I reproduced a subsequent Clear of two strokes. There are also no pending-input, pointer-cancel, lost-capture, or focus-loss cancellation handlers. This is a defect in the HTML state machine. It does not establish that the existing native input layer has the same bug.

**Exact fix:** Handle cancellation before the `!sess` return. On Escape, ordinary input that invalidates invocation, a second modifier in the native path, pointer cancellation, or focus loss: clear `openT`, invalidate the pending session token, clear eligibility, and drain the claimed release without executing. Timer callbacks must check that token before opening. Regression sequence: hold down, Escape at 100 ms, wait beyond 180 ms, move to Clear, release. No menu, no toast, no document change. Preserve the existing native session IDs and event-pair draining when implementing.

### 2. P1. Clear promises recovery without providing a direct recovery action

**Where:** lines 49, 193, 255–257, 290–291, 336–343.

**Wrong:** The result says "Undo restores it", but the toast has `pointer-events:none`, no button, and disappears in 1.2 seconds. Command-Z after dismissal does nothing in this prototype. Recovery requires invoking the wheel again and finding Undo. The history itself works; the missing affordance is the issue.

**Exact fix:** For Clear, show `Drawing cleared` with a real `Undo` button, 28 pt hit height and 8 pt separation. Keep it available until another document edit or explicit dismissal. Wire Command-Z and conventional Undo to the same history operation after the wheel closes. Announce the result. The hub before Clear should continue to say `Undo restores it`. Ordinary pointer and ink success labels may keep the 1.2-second timeout.

### 3. P1. The visible commands are not accessible controls

**Where:** lines 93–98, 216–245, 297–312, 336–343.

**Wrong:** The radial SVG has zero roles, tab stops, or accessible command labels. Browser cells and scope selectors are divs/spans. Selection and disabled state are visual only. Search is the browser's only ordinary input control. Replacing `svg.innerHTML` also precludes stable element identity. Control-Option-Right was consumed by the radial key handler, conflicting with an assistive-technology chord. Backspace at root leaves the wheel open despite ROUND2's close-at-root contract. Native VoiceOver success remains unverified.

**Exact fix:** Expose a labeled Quick controls group with stable command elements, full names, enabled state, selected state, group relationships, and press actions. Back must announce `Back to Quick controls`. Use real buttons or a fully implemented accessible composite, with one managed focus entry. Give the browser an accessible dialog name, an explicitly labeled search field, accessible scopes and grid cells, and a focus cycle confined to it while open. Restore prior focus on close. Ignore Control/Option/Command modified navigation except explicitly assigned shortcuts. In Click mode, Backspace returns from a child and closes at root, matching Escape. Use the native AX equivalents in the app. No default executable leaf on group entry.

### 4. P1. Browser vertical navigation chooses the wrong column

**Where:** CSS line 65 and JavaScript lines 309–312.

**Wrong:** `round(clientWidth/72)` includes grid padding and assumes a different pitch from the CSS layout. At the standard 560 pt browser width it returns eight, while seven columns render. Down from Coral chooses Chrome one column to the right of the intended Midnight.

**Exact fix:** Derive the actual column count from the resolved grid tracks, or from cells sharing the first row's top coordinate. Use that same count for Up/Down and incomplete-last-row clamping. At 560 pt the stride must be seven. Recalculate after resizing or filtering. Keep Left/Right text-caret behavior in a nonempty search field. Add a clear keyboard path from search into the grid; the grid's visible focus must correspond to its accessible active item.

### 5. P1. Favorites are a fixed demo array, not an editable product feature

**Where:** lines 143, 199–200, 295–307; [browser-dark.jpg](../claude/states/browser-dark.jpg).

**Wrong:** There is no favorite-edit action. The Quick controls scope merely filters the hard-coded array. It also shows catalog order instead of the wheel's slot order. A browser with a Quick controls scope promises management that it cannot perform.

**Exact fix:** Add `Edit Quick controls…` as a separate 28 pt footer control. Open six labeled slot rows in wheel order, north through southeast, southwest, west, with a `Replace…` action for each. A slot assignment must not select the pointer or close the browser. Preserve six explicit saved identities; replacing an already assigned favorite swaps slots rather than silently duplicating it. Render the Quick controls scope from slot order. Keep unavailable slots in place with their reason. The All scope continues to include every enabled, available built-in and custom pointer.

### 6. P1. Small-size and invalid-layout policies contradict the contract

**Where:** lines 251–253, 260–274, 318–335.

**Wrong:** Width shrinks the entire wheel. At 320 pt, 13 pt labels effectively become 10.29 pt and 11 pt hints become 8.71 pt. Height is ignored: a 300 pt stage clips the lower ring. An existing session survives a resize with its old origin. Held hit testing also has no owned-frame bound. Real multi-display behavior is outside this HTML model, but it is not modeled or proven here.

**Exact fix:** Keep scale at 1. If either usable dimension is below 384 pt, show a scrollable command list with the same hierarchy, 13/16 pt text and 28 pt rows. Cancel an active session when its usable frame changes; do not move an armed origin. In the prototype, bound held eligibility to the simulated display rectangle. In native code, use the invocation display's usable global frame, clear eligibility on crossing to another display, and cancel on display removal. Keep the working >8 pt relocation and radius-52 arming policy.

### 7. P1. Icon and label layout actually overlaps

**Where:** lines 181–184, 217, 224–228; [root-dark.jpg](../claude/states/root-dark.jpg), [draw-light.jpg](../claude/states/draw-light.jpg).

**Wrong:** Artwork and labels are positioned with unrelated baseline offsets. At scale 1, live element boxes overlapped by about 6 pt for root Pointer, 2 pt for Color, and 3.5 pt for Interact. Some image boxes include transparent pixels, so these numbers are box collisions, not a claim that every opaque pixel collides. Draw/Undo glyph-to-label clearance was effectively zero, and the Highlighter path reached the child label. More, meanwhile, had roughly 8.6 pt clearance. The rhythm is visibly inconsistent.

**Exact fix:** Lay out measured icon and text blocks with an 8 pt gap, instead of calculating the baseline independently. Use 24 pt root symbol frames, 22 pt child symbols, 32 pt artwork, root 13/16 pt medium labels and child 12/15 pt medium labels. Keep the content anchor at radius 118, including children. Center the entire block optically within each sector; allow a 4 pt inward correction for the longest two-line blocks. Verify all visible bounds remain inside their sector with at least 8 pt outer clearance. Keep two lines for Clear drawing and pointer names. Do not fix collisions by reducing the type size.

### 8. P1. Focus contrast and accessibility appearances are unfinished

**Where:** lines 29–35, 39, 60–61, 69–70, 223, 349–350.

**Wrong:** The hard-coded blue focus stroke touches selected fills. Solid-color calculations give only 1.50:1 against light-mode command selection and 1.72:1 against dark-mode selection. Disabled light text is about 3.44:1 against the opaque reference. Disabled controls have contrast exemptions in WCAG; this is still weaker than this design's readable-inspection requirement. There are no Increase Contrast or Reduce Transparency variants, and Reduce Motion is only a manual demo segment.

**Exact fix:** Use a 2 pt keyboard focus outline with a 1 pt contrasting halo and a 2 pt separation from the pending fill. Require at least 3:1 for an essential visible focus edge against its immediate background. Use `#645B68` for light disabled inspection text and `#C3B9C8` for dark, with the no-fill treatment and reason providing the unavailable distinction. Add opaque fallbacks `#F8F5F1` / `#29242D`, disable backdrop blur under Reduce Transparency, and strengthen separators to a tested 1 pt neutral stroke under Increase Contrast. Reflect system preferences in native implementation and provide explicit demo controls to review those states. Keep the existing command selection pairs, which calculate to 5.48:1 and 6.75:1. These are solid-reference calculations, not sampled glass ratios.

### 9. P1. Screenshot and several More commands cannot support shipping sign-off

**Where:** lines 288–294, 255–257; line 347's interaction teaching.

**Wrong:** Screenshot displays `Demo: menu hidden first`, while close merely begins the wheel's fade and immediately shows another toast. No capture is performed. Pointer off does not hide anything, and Settings is a declared stub. Toolbar changes a Boolean without showing a toolbar result. These are acknowledged prototype limits, not evidence of native capture or command failures. They still leave requested states and outcomes unreviewable.

**Exact fix:** Give the prototype faithful visible outcomes: Pointer off must remove its presentation indicator and offer a recoverable on path; Toolbar must show/hide an actual demo toolbar; Settings must open a representative panel. For Screenshot, remove the wheel, marker, arming cue, browser, and previous/result feedback from the captured scene before capture, then show an actual outcome such as `Screenshot saved` or a persistent actionable error. Do not add a pre-capture success toast. Native capture exclusion and input draining require a local runtime check before release.

### 10. P2. The icon set does not meet the requested native standard

**Where:** lines 146–167, 181, 217; [draw-light.jpg](../claude/states/draw-light.jpg), [more-dark.jpg](../claude/states/more-dark.jpg).

**Wrong:** Custom path approximations are inconsistent in visual size and construction. The Settings icon is a sun-like circle with eight detached rays. Undo/Redo have long low tails. Highlighter is crowded and oversized next to Rectangle. Matching every path to stroke-width 1.8 does not make this an SF Symbols family. The root uses 28 pt frames and several children use 28 pt symbols despite the smaller spec.

**Exact fix:** Use real SF Symbols, medium weight, with the frames in defect 7: `trash`, `camera`, `arrow.uturn.backward`, `arrow.uturn.forward`, `cursorarrow`, `pencil.tip`, `highlighter`, `rectangle`, `arrow.up.right`, `textformat`, `number.circle`, `eraser`, `speaker.wave.2`, `speaker.slash`, `rectangle.topthird.inset.filled`, `gearshape`, `power`, and `square.grid.2x2`. Check symbol availability against the macOS 26 target. Use a standard directional arrow for Back. Keep pointer artwork as artwork. Review optical bounds after substituting the real glyphs.

### 11. P2. The hub cuts meaning to fit a character count

**Where:** lines 201, 205–209, 234–242, 301.

**Wrong:** `fit(top,14)` and `fit(bot,17)` truncate by string length rather than measured width. Selecting a tool while Interact is on can show `Starts drawing` but does not name the mode change until afterward. Match is rewritten as `Match pointer` or `Match / pointer`, despite the requested full name. `Mute all / Turn on` makes people mentally invert a negative setting. Browser names also truncate by character count.

**Exact fix:** Wrap the full `Match the pointer` to two lines, `Match the` / `pointer`, in the sector. Use a fixed hub text frame up to 96 pt wide and at most two lines, with measured wrapping and no routine truncation. Keep `Interact on` / `Send clicks to apps` and `Interact off` / `Draw on screen`. For tool previews while Interact is on, use `Starts drawing` and announce `Turns Interact off` through the accessible description. For Mute use pending copy `Mute all sounds` or `Unmute sounds`; for Toolbar use `Hide toolbar` / `Show toolbar`; for Tap sound use `Turn tap sound on` / `Turn tap sound off`, wrapped as needed. Browser labels use two lines at 11/14 pt, with the full name in the footer and accessible name.

### 12. P2. The cursor marker is too large and covers the content it identifies

**Where:** lines 13, 46–47, 261; [pointer-dark.jpg](../claude/states/pointer-dark.jpg), [color-light.jpg](../claude/states/color-light.jpg).

**Wrong:** The 12 pt marker plus exterior stroke occupies roughly 15 pt. In the supplied screenshots it covers Coral's first label line and Green's label. The CSS hides the ordinary cursor in persistent mode as well. That is a poor default for a conventional click panel and has no enlarged-cursor accommodation.

**Exact fix:** Use the specified 8 pt hollow marker in held mode, with opposing 1 pt strokes and a 2 pt open center. Keep it at the real pointer location. In persistent mode offer the ordinary system cursor, with no second marker by default. Preserve the 20 by 20 pt origin reserve at neutral. Do not offset a selection dot to make screenshots look clean; fix the block layout and cursor choice.

### 13. P2. The motion specification is largely declarative

**Where:** lines 25–31, 36, 216–245, 255–259.

**Wrong:** Replacing all of `svg.innerHTML` inserts a fully colored new path, so the declared 60 ms fill transition does not crossfade old and new hover states. There is no 80 ms hub crossfade. Dismissal reuses the 120 ms opening transition. Reduced-motion cancellation still fades for 80 ms. Child swap fades the whole `.content` group, including the material fill and hub backing, from 25% opacity, rather than keeping the new material present while content settles.

**Exact fix:** Keep stable backing and item elements. Opening is 120 ms ease-out with optional 0.98 scale; close is 80 ms opacity; hover fill 60 ms; hub 80 ms; child foreground content 100 ms; Back foreground 80 ms. Use cubic 0.2,0,0,1. Reanchor immediately with no spatial tween. Under Reduce Motion: 80 ms opening opacity, immediate hover/hub/child/Back replacement, and immediate cancellation. Keep the new material fully drawn during child replacement. Command execution never waits for these effects.

### 14. P2. Material and sector edges need restraint and consistency

**Where:** lines 32–35, 218–233; [root-dark.jpg](../claude/states/root-dark.jpg), [color-light.jpg](../claude/states/color-light.jpg), [more-dark.jpg](../claude/states/more-dark.jpg).

**Wrong:** The dark disc and hub read as two heavy plum plates. Saturation 1.5 pulls a red chart column into the lower ring. Selection overlays use sharp annular corners, a nominal 3 pt artwork arc, and angle-based gaps whose size changes with radius. The separators and selected edges do not read as one deliberate drawing system. More's dashed disabled perimeter adds another texture.

**Exact fix:** Native implementation uses one regular glass host, a quiet internal hub fill, and the existing 0/8/20 shadow starting points. For the HTML approximation, reduce backdrop saturation from 1.5 to 1.0; retain blur 24 pt and review over bright and busy backgrounds. Use a 2 pt artwork arc, a consistent 4 pt gap measured at radius 164, and 2 pt rounded selection corners. Keep separators 1 physical pixel in normal contrast and a tested stronger variant for Increase Contrast. Remove the dashed disabled perimeter; retain readable text and the reason in the hub. Let the real material establish depth. Do not add gloss, bevels, or glow to compensate.

### 15. P2. Browser chrome and names still look like a mockup

**Where:** lines 56–75, 94–97, 301; [browser-dark.jpg](../claude/states/browser-dark.jpg).

**Wrong:** Three traffic lights are decorative circles. The apparent close control does nothing. `Presentation pointer` is cut to `Presentatio…` even with a footer available. The browser's selected/focused coral box is overloaded with hover, keyboard focus, and the search's provisional Return target. The actual current-item check is separate, but the rest of the focus grammar is vague.

**Exact fix:** Use a real native panel close control, or one explicit Close button in the prototype with a 28 pt hit area; remove fake minimize/zoom controls. Keep 36 pt art, 72 pt cell height, 8 pt grid gaps, and a maximum of seven columns. Seven fixed 64 pt cells plus gaps occupy 496 pt, centered inside a 560 pt panel. Wrap labels to two 14 pt lines instead of slicing strings. Use neutral hover, a distinct keyboard focus outline, and the existing current check. Show the complete focused name and result count in the footer. Keep favorite editing separate from choosing.

### 16. P2. Exact unowned boundaries select the wrong neighbor

**Where:** lines 268–271.

**Wrong:** Nearest-angle reduction retains the earlier array entry on a tie. A fresh root probe at 22.5 degrees selected Pointer, although ROUND2 assigns an unowned boundary to the clockwise item, Color. This is small but makes the written geometry inaccurate.

**Exact fix:** Use half-open angular intervals with the clockwise edge owning an exact boundary. Apply the existing 4-degree retention only after a prior target exists. For a fresh 22.5-degree sample, focus Color. Preserve deterministic behavior at the 0/360 wrap and for seven- and ten-sector children.

## What it takes to reach 90+

This needs completion of the current design, not another hierarchy experiment. These are the minimum ordered changes. Fixing the P0 alone does not turn this into an A.

1. **Close the cancellation and recovery holes.** Pending Hold cancellation must be terminal; Clear gets direct Undo and a post-dismissal Command-Z route. Verify no command executes after cancel.
2. **Finish accessible interaction.** Stable semantic command elements, modifier-safe keyboard handling, managed browser focus, focus restoration, and the opaque/contrast/large-text states. These must be reviewable, not described in a paragraph beside the demo.
3. **Finish the pointer browser.** Correct seven-column arrows, six-slot favorite editing, wheel-order scope, full names, working Close, and separate current/hover/focus signals.
4. **Repair the actual visual geometry.** Real SF Symbols, specified symbol sizes, measured 8 pt icon-label gaps, 16/15 pt label leading, full hub copy, and an 8 pt held marker or ordinary persistent cursor. Review every root and child in both appearances at scale 1.
5. **Complete material and motion.** One regular material, consistent 4 pt selection gaps and 2 pt artwork arcs, a stable backing during child swaps, real 60/80/100 ms content transitions, and immediate reduced-motion cancellation.
6. **Make edge and command outcomes honest.** A list below 384 pt, cancellation on invalid layout, bounded display ownership, visible More outcomes, and real capture exclusion/outcome verification. These are release gates even if the HTML remains a design instrument.

A revised prototype can earn a design score above 90 when these states are demonstrable. Native screenshot exclusion, AX operation, focus restoration, enlarged cursor, multi-display ownership, and actual input-pair draining still need local Mac evidence before shipping. No hosted CI is called for.

## ROUND2 requirements still violated or unproven

| ROUND2 requirement | V3 status and location |
| --- | --- |
| 24 pt root symbols, 32 pt pointer art, measured 1x/2x frames | Root symbols are 28 pt, root art can be 36 pt, many children use 28 pt symbols and 34 pt art. Box collisions remain. Lines 190, 199–202, 217, 224–226. |
| Content anchor at radius 118 | Children subtract 4 to use radius 114. Line 224. A deliberate optical exception is reasonable only after measuring each block. |
| Root 13/16 and child 12/15 typography, medium weight | Weight 600 throughout and baseline steps of 14/13. Lines 37–38, 224. Necessary text shrinks below the floor on small stages. |
| Full Match the pointer wording | Shortened in sector and hub. Line 201. |
| Dedicated editable six-slot favorites, unavailable placeholders, complete catalog | Six fixed identities are seeded correctly in the wheel, but editing, unavailable states, custom catalog input, and persistence are absent. Lines 101–143, 199, 299–307. |
| Real semantic commands, accessible Back, stable identities, prior-focus restoration | Absent in HTML; SVG replaced wholesale. Lines 216–245, 297–312. Native behavior unproven. |
| Do not swallow VoiceOver's Control-Option commands | Modified Right still changes focus. Lines 336–343. |
| Persistent Backspace returns one level, then closes at root | Child Backspace works; root Backspace does nothing. Line 338. |
| Current, pending, and keyboard focus are separate signals | Partially implemented in the wheel. Browser focus/hover remains overloaded, and the blue ring lacks contrast on selected fills. Lines 69–70, 219–228, 301–312. |
| No shrinking; list below either 384 pt usable dimension; invalid-layout cancellation | Width shrinking remains; height clips; no resize cancellation. Lines 251–253. |
| Owned-display boundary and protected input lifecycle | No frame bound in held tracking; pending Escape is ignored; no cancellation lifecycle. Native multi-display and pair draining are unproven. Lines 261–275, 318–343. |
| 80 ms dismissal, 60 ms hover, 80 ms hub, material present during child swap | Not implemented as specified. Lines 25–31, 216–245, 255. |
| System Reduce Motion, Reduce Transparency, Increase Contrast, larger text | Manual motion segment only. No other accommodation states. Lines 29–31, 350. |
| Clear Undo remains accessible after feedback | Root Undo can recover after reopening, but no direct Undo action or Command-Z route after dismissal. Lines 49, 255–257, 290–291, 336–343. |
| Close all Quick controls feedback before capture; report actual capture outcome | Declared stub. Close fades the wheel while adding feedback. Lines 255–257, 293. |
| Keyboard or AX can operate a clamped, pointer-unarmed child | Keyboard entry and arrow arming are modeled; AX entry is not. Lines 276–278, 341. |
| Exact unowned boundary belongs clockwise | Tie picks earlier array entry. Lines 270–271. |

The eight root positions, one active replacement ring, fresh child origin, navigation-only entry event, 72/64 acquisition/retention, 112 entry, 180 ms opening delay, stable Pointer directions, separate current checks, disabled reasons, no hover navigation in Click mode, outside-click cancellation, and corner arming are present. I am not reopening those decisions or counting them as defects. The three empirical risks in ROUND2 still require physical testing; the HTML cannot settle them.

## Reference standard

This report's design judgments and exact dimensions are my recommendations. Apple supports the general requirements for system-aware materials, keyboard and assistive access, readable type, contrast, and reduced motion. See [Apple accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility) and [Apple materials guidance](https://developer.apple.com/design/human-interface-guidelines/materials). The browser exercises and local source establish the specific findings above. An SF-looking SVG is not proof of native material or accessibility behavior.
