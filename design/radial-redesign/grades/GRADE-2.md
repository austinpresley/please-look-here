# V4 shipping design grade

Sol, 16 November 2026. Frozen subject: [prototype-v4.html](../claude/prototype-v4.html).

**78/100, C. Do not ship this design as-is.** The hierarchy is sound and the ordinary radial path is coherent. Pending invocation still survives input that should cancel it. The browser's new favorite editor and the accessible list also fail ordinary tasks. These are implementation holes in this design instrument, not reasons to restart the command map.

The rubric is unchanged from [GRADE-1](GRADE-1.md). Each category carries ten points. A is 90 to 100, B 80 to 89, C 70 to 79, D 60 to 69, F below 60. This scores the demonstrated design, with no points for improvement. A P0 blocks shipping regardless of the average.

| Criterion | /10 | One-line justification |
| --- | ---: | --- |
| Visual craft | 8 | The disc and measured blocks hold together; Screenshot clearance and Match's sector fit still miss the stated bounds. |
| Iconography and typography | 8 | Frame sizes, leading, and wrapping are credible; stand-in glyphs and inconsistent optical gaps remain provisional. |
| Color and contrast | 9 | Both appearances have readable selection pairs, opaque variants, stronger dividers, and a separated focus halo. |
| Interaction model | 7 | Reanchoring, arming, and ownership work, but ordinary input during pending Hold can still end in Clear. |
| Information architecture and copy | 9 | Stable directions, full Match wording, pending toggle actions, and a separate browser make the model understandable. |
| States and feedback | 8 | Clear has working direct recovery, but unrelated success feedback can overwrite it and dismissal leaves hidden controls alive. |
| Motion | 9 | Stable radial elements and the specified fade timings are present, including immediate reduced-motion cancellation. |
| Accessibility | 6 | Real radial commands and browser semantics exist; initial focus, modified browser keys, and the list's focus model remain incomplete. |
| Pointer browser | 7 | Search, seven-column arrows, scopes, and swaps work; mouse editing and narrow layouts do not. |
| Prototype fidelity | 7 | Most outcomes are reviewable, but cancellation and fallback failures prevent sign-off; capture remains a simulation. |
| **Overall** | **78/100** | **C. The demonstrated design is below the 90-point shipping threshold.** |

## Evidence and limits

I read [REVIEW.md](../sol/REVIEW.md), [ROUND2.md](../sol/ROUND2.md), GRADE-1, all 523 lines of v4, and all six supplied PNGs in [states-v4](../claude/states-v4). The reviewed SHA-256 is `ff26f8462915dd4e4344cc2709bd4cc787541fab40d3b6e62fc76f58bfbed55b`.

I served the frozen file locally and operated an owned T3 browser tab. Real browser input covered clicks, hover, search, arrows, Tab, Return, Backspace, Escape, Control-Option navigation, Command-Z, and Shift-Command-Z. Held sequences used synthetic browser PointerEvents through the installed listeners and the real 180 ms timer. They test the HTML state machine, not a physical modifier hook or native input-pair draining.

For direct HTTP viewing I supplied system-font/theme host variables in memory and served the existing absolute artwork paths as the same local PNGs. T3's `html_preview` supplied its host variables and automatic artwork inlining for additional rendered states. Neither adaptation changed the frozen file. I inspected fresh renders of light keyboard focus, Draw, More, the small list, and the narrow browser, as well as the supplied screenshots.

T3's interactive snapshot failed twice with `Preview automation snapshot timed out after 15000ms.` The computer-use inventory exposed no browser, and opening the Chrome fallback returned `Browser is not available: chrome`. Interactive input and DOM inspection continued to work; T3's separate HTML renderer produced viewable screenshots. Motion findings establish stable nodes and declared/computed transitions, not a frame-rate measurement. ResizeObserver and capture callbacks were checked after returning control to the browser between evaluations.

No application source or prototype was edited. No Mac app was built or launched, no hosted CI was used, and no commit was made. This report is the only repository file written. The temporary HTTP server was stopped after review.

### Exercises and results

| Exercise | Observed result |
| --- | --- |
| Pending cancellation | Escape, pointercancel, lostpointercapture, and blur at 80 ms canceled; later movement/release changed nothing. Ordinary `a` and a second modifier did not cancel and subsequently allowed Clear. |
| Held selection | Northward entry opened Pointer at the entry point with candidate -1; subsequent eastward movement and release selected Coral once. |
| Corner and display ownership | Invocation at 20,20 clamped to 192,192, stayed unarmed until the neutral region was entered, and did not acquire during unarmed travel. Movement outside the simulated display cleared eligibility, showed the return instruction, and release canceled. |
| Click and keyboard | Hover did not enter a group. Tab focused a real command; Return entered with no default leaf. Backspace returned, then closed at root. A focusable prior control regained focus on close. Initial opening itself left focus on that prior control. |
| Clear and history | A real click on Clear removed the strokes; the 28 pt Undo button restored them. The snackbar survived 1.45 seconds. After dismissal, real Shift-Command-Z cleared again and Command-Z restored. Choosing a pointer after Clear replaced the persistent snackbar. |
| Browser search and arrows | Search isolated Coral and Return chose it. Empty results removed aria-activedescendant and showed zero pointers. Down from Coral, after entering the grid, reached Midnight at index 9 rather than Chrome at 10. |
| Favorites | Use swapped Cursor glove and Lavender between N and NE without changing the live pointer or closing. Quick controls scope followed slot order. Mouse hover did not change the edit target; clicking that artwork selected it and closed instead. |
| Browser keyboard | Tab cycled through the open dialog, including its editor. Escape closed the editor before the browser. Control-Option-Right in the grid still changed Midnight to Chrome. |
| Themes and accommodations | Dark/light and Glass/Reduce Transparency/Increase Contrast were exercised. Both opaque modes removed blur; selected text resolved to plum on light coral in dark appearance and white on deep coral in light appearance. Reduced motion removed highlight/hub/content transitions and cancellation transition. |
| Small display | Width 320 or height 300 invoked a list at full text size with 28 pt rows. Actual stage resize canceled an active session. At height 180, keyboard focus moved below the list viewport without scrolling. Back was excluded from the list's Tab cycle. |
| Browser at 320 pt | The panel shrank to 296 pt but retained seven columns. The first cell was wholly left of its viewport; the seventh extended beyond the right edge. A fresh render confirmed clipping. |
| Visible outcomes | Toolbar changed actual visibility. Settings opened and focused Close. Pointer off hid ink/toolbar and provided a working Turn on route. Screenshot removed wheel/marker/feedback immediately, then flashed in normal motion and eventually reported the simulated saved result. |
| Stable rendering and boundaries | Backing, highlight, item, and semantic-command nodes survived hover changes. Root 22.5 degrees correctly belonged to Color. More at exactly 315 degrees incorrectly resolved to Back instead of Toolbar. |

## Disposition of every GRADE-1 defect

“Fixed” refers to the reviewed HTML behavior, not native release verification. No item is wholly untouched, but several fixes are incomplete.

| GRADE-1 # | Status | V4 finding |
| --- | --- | --- |
| 1. Pending Hold cancellation | Partially fixed | Escape and the three added lifecycle cancellation routes work; ordinary input and second-modifier cancellation remain missing. The P0 remains. |
| 2. Clear recovery | Partially fixed | Real persistent Undo, dismiss, Command-Z, and redo work; unrelated success feedback replaces the persistent action, and dismissed buttons remain focusable. |
| 3. Accessible commands | Partially fixed | Stable radial buttons, roles, states, reasons, live announcements, Backspace, and restoration exist. Opening does not focus the menu; the browser and list have the failures below. |
| 4. Browser vertical navigation | Fixed | Actual rendered-row stride is seven; Coral to Midnight verified. |
| 5. Editable favorites | Partially fixed | Six ordered rows and swaps work through keyboard/search targeting. The normal mouse editing path changes the live pointer and closes. |
| 6. Small-size/layout policy | Partially fixed | No shrink, either-dimension fallback, active-session resize cancellation, and bounded held tracking work. The fallback's inaccessible Back and offscreen focus keep it from completing the intended policy. |
| 7. Icon/label layout | Partially fixed | Former icon-label collisions are gone, and measured frame/leading rules are present. Screenshot lacks 8 pt outer clearance and Match's last line crosses its sector boundary. |
| 8. Contrast and accommodations | Fixed in the prototype | Disabled colors, halo, opaque fallbacks, contrast separators, and startup media-query mappings are present. Native preference behavior remains untested. |
| 9. More command outcomes | Partially fixed | Off, toolbar, Settings, and capture sequencing have visible modeled outcomes. There is no actual captured image or capture failure path. |
| 10. Native icon standard | Partially fixed | Sizes and the gear construction changed; all HTML glyphs remain hand-drawn stand-ins. Existing native source names real SF Symbols, but it still contains the old six-root hierarchy and does not prove v4 implementation or optical parity. |
| 11. Hub and full names | Fixed | Width-based wrapping, full Match wording, pending toggle copy, tool-mode descriptions, two-line browser labels, and full footer names replace character-count slicing. |
| 12. Cursor marker | Fixed in the prototype | Click mode uses the system cursor; Hold alone shows the small hollow marker at the real pointer. Enlarged native pointer behavior remains untested. |
| 13. Stable motion | Fixed in the prototype | Hover preserves radial nodes; highlight 60 ms, hub 80 ms, child 100 ms, Back/close 80 ms, and immediate reduced-motion replacement/cancellation are implemented. |
| 14. Material and edges | Fixed to HTML approximation level | One blur host, no saturation boost or gloss, quiet hub, rounded selections, 2 pt artwork arc, hairlines, and no dashed disabled outline. Native glass remains a separate check. |
| 15. Browser chrome and names | Fixed | Real Close, seven 64 pt tracks at normal width, two-line names, neutral hover, separate focus/current marks, full footer name/count, and separate edit control. Responsive failure is detailed below. |
| 16. Half-open boundaries | Partially fixed | Root and ordinary child boundaries pass; floating-point holes in the seven-sector More ring fall through to Back. |

## Ranked defects and exact fixes

Line numbers refer to the frozen v4 HTML. “New finding” identifies a newly exercised failure, not a claim that the old prototype passed that task.

### 1. P0. Ordinary input still leaves pending Hold live

Residual GRADE-1 #1. Lines 473 to 476 and 491 to 496.

The new session token protects the explicitly canceled routes. The key handler only cancels pending invocation for Escape. I pressed down, sent `a` at 80 ms, waited past 180 ms, moved southeast, and released. `DOC.cur` changed from 2 to 0. Repeating with a second modifier also cleared. The written protected-input contract still is not met.

**Exact fix:** Before the `!sess` return, cancel pending invocation for every ordinary key and any additional modifier that invalidates the trigger. Preserve pass-through for that unrelated key; cancel the timer, invalidate the token, clear eligibility, and drain the claimed release. Use the established native input policy when porting. Verify the same sequence with ordinary input, a shortcut chord, and a second modifier. No menu, action, or document change may follow.

### 2. P1. The favorite editor cannot choose a new target normally with a mouse

New finding in the added editor, GRADE-1 #5 remains incomplete. Lines 442 to 451.

Use reads `bList[bFocus]`. Mousemove only paints `.hov`; clicking a cell always calls `choose()`. I hovered Bubblegum while the editor offered Use Chrome. Clicking Bubblegum changed the live pointer and closed the browser without assigning a slot. Filtering down to one result or using arrows is a workaround, not a complete mouse flow.

**Exact fix:** Give editing an explicit selection state. While the editor is open, a cell click selects the assignment candidate, updates its visible/accessible focus, footer, and Use labels, and keeps the browser open without changing `S.pointer`. Only Use assigns or swaps; Done exits editing. Outside editing, ordinary clicking may continue to choose. Keep hover preview separate from that deliberate candidate selection. Preserve focus on the corresponding slot after a swap.

### 3. P1. The pointer browser loses columns on a small display

New responsive finding. CSS lines 107 to 123, browser rendering lines 434 to 441.

The panel uses a responsive width but the grid always requires 496 pt. In a 320 pt stage, its 296 pt viewport began at x=12; the first cell occupied x=-88 to -24. Centering puts content before the scroll origin. The screenshot also shows cropped cells and cramped tools/footer. This is the display that explicitly needs the fallback path.

**Exact fix:** Derive one to seven 64 pt tracks from the available width and 8 pt gaps, with normal internal margins. Keep `cols()` tied to the resulting rows. At 296 pt, use three columns. Wrap the scopes/search and footer as needed, give the grid a shrinking flex area with `min-height:0`, and keep artwork, names, Close, and edit controls inside the panel. Scroll vertically. Repeat arrows, search, and favorite assignment at narrow and short sizes.

### 4. P1. The list fallback breaks accessible navigation and visible focus

New finding in the added fallback; GRADE-1 #3 and #6 remain incomplete. Lines 348 to 356, 363, 396, and 500 to 502.

Every focus change replaces all rows with `innerHTML`. The Back header button is excluded from the intercepted Tab cycle. Keyboard group entry focuses `qc`, the separate screen-reader group, even though the list path has not built its command children. At a 320 by 180 pt stage, eight Tabs focused More at y=329 to 357 while the list ended at y=250. `scrollTop` remained zero. The fallback is not a usable keyboard alternative in the very size it is meant to rescue.

Persistent radial opening also leaves DOM focus on the previously focused external button until a navigation key is pressed. Announcing a menu is not the same as entering it.

**Exact fix:** Build stable real list buttons once per level. Make Back a member of the same focus order and activation model. Focus the displayed menu group on persistent opening/entry, without a default command. Update row classes and states in place; scroll the focused row into view with nearest alignment and preserve scroll position. Do not focus the unused `qc` group in list mode. Give disabled inspection no pending-action fill. Keep held opening nonactivating and define its transition to list browsing explicitly.

### 5. P1. The browser still consumes assistive-technology chords

Newly verified browser case of GRADE-1 #3. Lines 455 to 463 and 491 to 496.

The modifier guard is below the `panelOpen` branch, so it protects only the radial menu. Real Control-Option-Right in the browser moved Midnight to Chrome. This contradicts the blanket claim that modified navigation is ignored.

**Exact fix:** Apply the modifier policy before panel navigation, or at the beginning of `panelKey`. Leave Control/Option/Command navigation to its owner unless that exact chord is an intentionally assigned action. Preserve Shift-Tab. Verify the protected chords in search, grid, slots, Settings, radial, and list contexts.

### 6. P1. Clear's recovery action has the wrong lifetime, and hidden buttons retain focus

Residual GRADE-1 #2 with a new dismissal failure. Lines 399 to 426.

Clear's snackbar is the same element used for transient success. Clearing, reopening, and choosing Robot replaced `Drawing cleared / Undo` with `Robot / Pointer`, despite no further document edit or explicit dismissal. Clicking the real dismiss button then demonstrated a second problem: `tX` retained DOM focus at opacity zero, both buttons still had tabIndex 0, and neither hidden nor inert was set.

**Exact fix:** Store the actionable Clear result separately from transient success feedback. Preserve it across pointer, ink, mode, toolbar, and sound changes; clear it only on a subsequent document edit or explicit dismissal. On dismissal, remove its controls from DOM or mark the container hidden/inert and move focus to a sensible prior control. Keep the working Undo/redo history route. Confirm that no invisible Undo/Dismiss control remains reachable by Tab or accessibility navigation.

### 7. P2. Two measured content bounds still violate the drawing contract

Residual GRADE-1 #7. Lines 305 to 313.

At scale 1 with system fonts, Screenshot's text-box corner leaves about 4.2 pt to the outer circle, below the required 8 pt. The second line of Match extends about 1.3 degrees past its logical sector edge. These measurements use individual content frames, excluding decorative group notches; whole-group bounding-box corners would exaggerate the problem. The old icon-label collisions themselves are fixed.

**Exact fix:** Give these two blocks measured optical exceptions instead of changing all anchors. Moving Screenshot inward about 6 pt and moving Match's block upward about 4 pt are sensible starting trials. Verify actual corners against their sector edges and radius 156 at both 1x and 2x. Keep the current type sizes and full wording. Review the stand-in glyphs' optical gaps again after substituting real SF Symbols; a shared frame does not make their visible gaps equal.

### 8. P2. Seven-sector boundaries contain floating-point holes

Residual GRADE-1 #16. Line 295.

At exactly 315 degrees in More, Toolbar's normalized offset becomes `359.99999999999994`; Mute's offset is just outside the shortened interval. No interval accepts the sample, so `return 0` chooses Back. A fresh `track()` at that angle reproduced Back. Another More boundary at about 212.142857 degrees has the same failure. Root 22.5 degrees is correctly fixed.

**Exact fix:** Compute one contiguous sector index from the first boundary and sector width, normalize once, and apply a small consistent tolerance before floor/modulo. Map that index to the frozen clockwise order. Do not create gaps by subtracting epsilon from every interval or default unmatched samples to Back. Verify every exact boundary and samples immediately on either side, especially all seven More boundaries and the wrap.

### 9. P2. The supplied selected-focus screenshot is not a reliable final reference

New evidence issue. [increase-contrast-keyboard-light.png](../claude/states-v4/increase-contrast-keyboard-light.png).

That PNG shows dark Interact lettering on the deep coral selection. The settled live computed style was white, and a fresh reduced-motion HTML render also showed white. I have not charged the live color implementation for the stale-looking PNG. It should not be handed to the native implementer as the correct selected treatment.

**Exact fix:** Regenerate this reference after fonts and transitions settle, or use Reduce Motion for the static capture. Check computed on-selection color before taking it. Supply a matching light/dark state set with current, pending, keyboard focus, and disabled inspection identified consistently.

## What remains between this and 90+

Keep the eight root directions, full replacement children, and separate browser. The next pass needs completed interactions, not another hierarchy debate.

1. Close the pending-input hole and show terminal cancellation for every invalidating input route.
2. Make mouse favorite editing and narrow browser layouts complete tasks without selecting the wrong thing or clipping choices.
3. Finish the list as an accessible control, including Back, initial group focus, stable identity, visible focused rows, and modifier-safe panel navigation.
4. Preserve Clear's direct recovery until its stated expiry condition, and remove dismissed controls from focus/accessibility navigation.
5. Repair the two content bounds and all seven-sector boundary ties, then replace the inconsistent screenshot reference.

The screenshot sequence is now an honest reviewable simulation of overlay removal and feedback timing. It still does not prove a file was captured: `capture()` has no capture operation or error route. A native release needs actual local success/failure and exclusion evidence. Existing SF Symbol identifiers likewise do not demonstrate the new native layout. Native AX operation, real focus restoration across applications, enlarged cursor behavior, mixed-scale/multi-display ownership, input-pair draining, and the three physical experiments in ROUND2 remain outside this HTML grade.

Those native checks are release gates, not invented HTML failures or a reason to withhold credit for working prototype behavior. The failures ranked above are demonstrable inside v4 itself. Fix them before calling the design ready to implement as-is.
