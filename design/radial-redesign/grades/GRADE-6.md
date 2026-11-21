# V8 shipping design grade

Review sub-agent, 16 November 2026. Frozen subject: [prototype-v8.html](../claude/prototype-v8.html).

**89/100, B. No, the HTML design is not at or above 90. Do not ship it as-is.** No P0 reproduced. The two exact GRADE-5 handler failures are repaired, and the short-editor reference is current. The claimed complete focus-ownership rule still fails browser-default list focus and pointer-driven radial entry after keyboard ownership. Two P1 paths remain. Keep the command map, composition, palette, and browser layout.

The rubric is unchanged. Each category carries ten points. A is 90 to 100, B 80 to 89, C 70 to 79, D 60 to 69, F below 60. Any P0 blocks regardless of score. Scores assess demonstrated HTML behavior. The native release gates below are unscored.

| Criterion | /10 | One-line justification |
| --- | ---: | --- |
| Visual craft | 9 | The compact disc, measured content blocks, optical exceptions, and narrow editor remain composed. |
| Iconography and typography | 9 | Full radial labels and their measured bounds pass at system-font scale. |
| Color and contrast | 9 | Both selection pairs, independent focus outlines, disabled inspection, and opaque variants pass. |
| Interaction model | 9 | Cancellation, fresh child selection, Back rearming, bounded ownership, and matching click commitment pass. |
| Information architecture and copy | 9 | Stable directions, explicit toggle consequences, full names, and separate browser editing remain clear. |
| States and feedback | 9 | Editing exits agree; Clear recovery persists, and modeled Screenshot exclusion preserves that recovery. |
| Motion | 9 | Hover preserves nodes; the specified timings and immediate reduced-motion cancellation remain intact. |
| Accessibility | 8 | Keyboard Back is repaired, but two menu-replacement paths still leave DOM focus on BODY. |
| Pointer browser | 9 | Search, spatial arrows, editing Return, swaps, assignment focus, and short long-name layouts pass. |
| Prototype fidelity | 9 | The references now agree with the HTML; the broader focus claim still exceeds the working behavior. |
| **Overall** | **89/100** | **B. Two P1 focus paths prevent an as-is handoff.** |

## Evidence and limits

Read sol/REVIEW.md, the merged sol/ROUND2.md, GRADE-1 through GRADE-5, the frozen v8 HTML, and its diff against v7. Inspected all eight states-v8 PNGs. The supplied hashes matched before and after behavioral review:

- HTML SHA-256: `67521be8e6129603f50df4778ea813ffc0b4c022dc8da36c74b0ebe546ceb783`.
- Short-editor PNG SHA-256: `773ba5922285bbadaa5719cf060c3b721e6258e929f84abd3070f80351591614`.

Served the unchanged file on my own local Mac server at 127.0.0.1:8786. Its absolute artwork URLs resolved to the original files. An in-memory stylesheet supplied the system-font and theme variables expected from the rendering host. Size probes changed only stage dimensions in browser memory.

An owned T3 tab exercised real keyboard input, search typing, and successful mouse clicks. Held gestures used synthetic PointerEvents through the installed listeners and the real 180 ms timer. Additional matrices used the installed click/key handlers and prototype functions. These tests establish HTML state and focus behavior, not native modifier ownership or physical input draining.

Snapshots twice returned `Preview automation snapshot timed out after 15000ms.` Some clicks timed out, and the automation host intermittently disconnected. Those attempts are excluded from defect evidence. The alternate browser inventory had no browser, and opening iab returned `Browser is not available: iab`. T3 keyboard input and DOM evaluation remained usable after reconnection. Successful real Pointer and Color list clicks independently established the browser-default focus failure below; a successful Pointer Back sequence also ended on BODY. Explicitly focusing a row before dispatching its installed pointer-style click handler replayed that observed default-focus sequence across all four groups and Back. That replay is distinguished from a real mouse gesture.

Fresh visual inspections used T3's separate HTML renderer for light selected focus, Draw, More, and the short editor. Those inspection copies disabled transitions; the scrolled editor copy also made the queued initial panel focus synchronous. Behavioral tests used the unmodified handlers. Resize cancellation was checked after observer delivery in a subsequent evaluation. Geometry uses logical SVG text bounds at browser scale 1. Motion checks establish node stability and computed transitions, not frame-rate performance.

## Disposition of every GRADE-5 finding

| GRADE-5 finding | Disposition | V8 result |
| --- | --- | --- |
| P1. Hold Back focus policy | Exact reported failures fixed; broader policy incomplete | Pointer-style click dispatch alone no longer makes pointer-only Hold list Back call focusMenu. Real keyboard-operated radial Back now focuses qc immediately. All four groups pass these exact retests in both presentations. Browser-default list focus and mixed keyboard/pointer forward entry still fail, detailed below. |
| P2. Stale short-editor reference | Fixed | The new 320 by 360 stage shows Use/Here, title and Close, editor chrome, complete rows, and the footer. It differs from the obsolete PNG, agrees with live labels, and matches the supplied new hash. |

Claude's summary is therefore only partly correct. kbOwn survives tracking, and goBack now honors it. But enterChild does not call focusMenu when track enters a group, and guarding explicit focus calls does not suppress a button's browser-default mouse focus.

## Required focus matrix

Each row covers Pointer, Color, Draw, and More separately. Every passing replacement below had focus/candidate both -1 before another navigation key.

| Mode and presentation | Opening, forward entry, and Back |
| --- | --- |
| Pointer-only Hold, radial | Preserved the same external theme control through opening, tracked group entry, and tracked Back in all four groups. |
| Pointer-only Hold, list, exact GRADE-5 click-handler probe | Preserved the external control through opening, entry, and Back for all four groups when dispatching only a MouseEvent with detail 1. |
| Pointer-only Hold, list, browser-default focus sequence | Failed. Successful real Pointer and Color entry clicks focused a row before removing it, then left BODY focused. Pointer Back did the same. Default-focus replay reproduced entry and Back failure in all four groups. |
| Keyboard-operated Hold, radial | Real number/Return entry and Shift-Tab/Return Back passed for all four groups, focusing qc on return. |
| Keyboard-operated Hold, list | Real number/Return entry and Tab/Return Back passed for all four groups, focusing lmenu on return. |
| Click, radial | Pointer-style activation entry/Back and real keyboard entry/Back passed for all four groups, retaining qc focus. |
| Click, list | Pointer-style click-handler entry/Back and real keyboard entry/Back passed for all four groups, retaining lmenu focus. |
| Click, both presentations, Escape and Backspace | Real keys returned from every group to its displayed menu. Closing at root restored the external theme control. |
| Keyboard-owned Hold, radial, then pointer-driven entry | Failed in all four groups. kbOwn remained true, but removing the focused root item left BODY focused. Tracked Back correctly restored qc. |

The distinction between the second and third rows matters. The old synthetic click-only probe omits mousedown's default focus. Passing that probe does not establish pointer-only focus preservation during a real click.

## Fresh full sweep

| Exercise | Observed result |
| --- | --- |
| Pending Hold cancellation | Ordinary input, a Command chord, Shift, Control, Option, Command, Escape, pointercancel, lost capture, and blur canceled pending invocation. After the real timer interval, later southeast travel/release left DOC.cur at 2. Only Escape was prevented among the keyboard cases. |
| Held selection and cancellation | Pending movement updated the opening origin. North entry created Pointer at the entry event with no candidate; later east travel acquired Coral and release applied it. Release over an unentered group, child neutral release, and held Escape canceled without changing the pointer. |
| Back and rearming | Explicit Back cleared the candidate and set needNeutral. Outward travel remained blocked until neutral entry; another group then opened normally. Returning to the saved parent center also worked. |
| Edges, ownership, and layout | Invocation at 20,20 clamped to 192,192 and stayed unarmed until neutral entry. Leaving the stage cleared eligibility and showed Return to this display; release canceled. A stage resize canceled after ResizeObserver delivery. |
| Persistent pointer path | Hover previewed without entering. Matching down/up entered Pointer at its click point with no child candidate. Drag-away from Clear and an outside down/up left the document unchanged; the outside click dismissed. |
| Keyboard and disabled commands | Initial persistent opening had no executable default. Disabled Undo and Redo retained their reasons, had candidate -1, and did not alter history. Explicit Back, Escape, Backspace, and prior-focus restoration passed as listed above. |
| Small display | At 320 by 180, the list fit its 156 pt viewport. All row identities survived eight real Tabs; More scrolled fully into view at scrollTop 107. Keyboard entry and Escape return focused lmenu. |
| Clear recovery | The two controls survived 1.45 seconds and an unrelated Robot choice. Undo restored both modeled strokes and removed recovery controls. Dismiss removed both controls and focused the stage. Real Command-Z restored and Shift-Command-Z recleared. |
| Capture exclusion | With Clear recovery present, both motion settings hid the snackbar, set menu opacity to 0, hid the marker, and emptied toast/cue before the modeled capture boundary. Recovery returned afterward. Undo during capture expired it without resurrecting controls. |
| Browser search and launch | Empty search removed aria-activedescendant and real Return did nothing. Real Cloud search/Return selected and closed. All pointers ended the radial session and focused browser search. Quick controls scope followed saved slot order. |
| Browser navigation and focus | Real Down moved Coral to Midnight in seven columns and to Bubblegum in three columns. Control-Option-Right left the candidate unchanged. Sixteen real Tab/Shift-Tab steps stayed inside the editing dialog. |
| Favorite editing | A pointer-style Bubblegum cell click plus real Return retained live Coral and unchanged favorites. Use assigned Bubblegum; assigning Lavender to an occupied slot swapped identities. Both assignments focused the labeled destination row. Search Return also retained editing semantics. |
| Editing exits | Escape, Done, and the footer action all removed slots.open and bgrid.editing, removed the Selected prefix, focused bedit, and immediately restored the correct narrow or wide Edit label. |
| Narrow and short editor | Body viewports were 247 pt at 320 by 360 and 67 pt at 320 by 180. Presentation pointer as candidate, then as each saved favorite, passed 84 row/button reachability checks without horizontal overflow. Body clientWidth/scrollWidth remained 296/296. |
| Appearance and accommodations | Dark/light crossed with Glass, Reduce Transparency, and Increase Contrast passed computed-style inspection. Opaque modes removed blur. Light selection used white on deep coral; dark used plum on light coral. The separate two-stroke focus outline remained present. |
| Geometry | All 41 boundaries and samples 0.00001 degrees on either side passed, including More's wrap. All 188 measured label corners stayed inside the circle and their sector. Screenshot retained about 10.18 pt outer clearance; Match about 0.67 degrees angular clearance. |
| Motion | Base, highlight, item, and semantic-command nodes survived hover. Normal opening/highlight/hub/child timing remained 120/60/80/100 ms. Reduce Motion removed spatial transforms and highlight/hub/content transitions; cancellation had transition none and opacity 0. |
| Other outcomes | Draw exited Interact and exposed Turns Interact off. Sound/mute changed state; Toolbar hid; Settings focused Close. Pointer off hid ink/toolbar and supplied a working Turn on route. |

## Remaining defects and exact fixes

### 1. P1. Pointer-only Hold list clicks still take focus, then discard it

HTML lines 369 to 379 and 396 to 402.

With Hold and Small display, focus the external Dark control, then open the list. Opening correctly preserves that control. A successful real click on Pointer produced the event sequence mousedown, focusin on lm-0, click, then removal of lm-0. The new Pointer menu remained open with focus/candidate -1 and kbOwn false, but document.activeElement was BODY. A successful real Color click produced the same sequence through lm-1. The Pointer Back path also left BODY focused. Explicitly replaying the observed row-focus-then-click sequence reproduced both entry and Back failure for Pointer, Color, Draw, and More.

The focusMenu guard works as written. It cannot undo the browser's default focus transition before the click handler runs. Rebuilding listmenu removes the focused button. This is a demonstrated DOM focus defect, not a hypothetical native activation problem.

Exact fix: suppress the default mouse-focus action on list-row pointerdown while mode is Hold and kbOwn is false, while preserving click activation and existing propagation ownership. For example, preventDefault for the eligible primary pointerdown in that branch. Keep normal focus behavior once the session owns focus. Alternatively preserve stable rows and explicitly preserve the prior focus under the same policy. Verify with real down/up clicks, rather than click dispatch alone, through every group and Back. The same external control must remain focused throughout pointer-only Hold.

### 2. P1. Pointer-driven forward entry bypasses focus transfer after keyboard ownership

HTML lines 396 to 400, 404 to 417, and 420 to 421.

In radial Hold, press Tab to focus qc-root-0. The session now has kbOwn true. Move the pointer 114 pt north to enter Pointer. track clears the visual kb flag and calls enterChild directly. The child opens with no candidate and kbOwn remains true, but buildA11y removes the focused root button and document.activeElement becomes BODY. The same probe through each group's fixed axis reproduced this for Color, Draw, and More. Tracked Back then correctly focused qc, proving ownership survived and the missing transfer is specifically forward entry.

Exact fix: make enterChild perform the guarded focusMenu transfer after either presentation has finished rebuilding, covering the direct track caller as well as activate. Record keyboard intent before rebuilding, retain kbOwn through pointer tracking, and keep focus/candidate -1. Consolidate duplicate caller-level focus work if needed. Retest keyboard ownership followed by pointer-driven entry and Back in every group. Do not depend on another Tab to recover focus.

These are two paths through the unfinished focus contract. They do not justify another radial redesign. They also do not earn a passing score merely because the narrower GRADE-5 probes pass.

## Verdict

The HTML remains below 90. Repair the browser-default focus path and put the guarded forward transfer in the shared level-entry routine, then rerun the complete matrix. The short-editor evidence defect is closed. No other scored defect was demonstrated in this sweep.

## Native release gates, unscored

- Substitute real SF Symbols and verify native system typography, material, contrast over bright/busy content, and final glyph bounds at 1x/2x.
- Verify VoiceOver, Full Keyboard Access, Voice Control, larger-text list operation, enlarged cursor, actual command accessibility state, and prior application/responder restoration.
- Verify native modifier triggering, session IDs, stale-release rejection, cancellation, claimed input-pair draining, commit-time availability validation, and no click-through.
- Verify actual Screenshot success and failure, its saved file, and exclusion of every overlay/feedback layer. The HTML models sequencing only.
- Verify Dock/menu-bar/full-screen edges, mixed scales, negative-coordinate/multiple displays, crossing/removal, and system accommodation changes.
- Run ROUND2's three physical experiments locally: reanchoring with mouse/trackpad, eight versus six root choices including Clear slips/recovery, and actual display/accessibility behavior.

No source or prototype was edited, no Mac app was built or launched, no hosted CI ran, and no commit was made. This report is the only repository file written. The temporary review server was stopped; Claude's 127.0.0.1:8777 server was left untouched.
