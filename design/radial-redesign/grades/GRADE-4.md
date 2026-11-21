# V6 shipping design grade

Review sub-agent, 16 November 2026. Frozen subject: [prototype-v6.html](../claude/prototype-v6.html).

**88/100, B. No, this HTML design is not at or above 90. Do not ship it as-is.** No P0 reproduced. All six specific GRADE-3 findings pass their requested retests. The fresh sweep found one P1 in the Small display focus policy and two P2 browser defects. The command map and radial composition can stay.

The rubric and scale are unchanged: ten equally weighted categories, each out of ten. A is 90 to 100, B 80 to 89, C 70 to 79, D 60 to 69, F below 60. Any P0 blocks regardless of score. This grades demonstrated HTML behavior, without credit merely for improvement. Native-only gates below are unscored.

| Criterion | /10 | One-line justification |
| --- | ---: | --- |
| Visual craft | 9 | The compact disc, spacing, optical exceptions, and full-height state references remain convincing. |
| Iconography and typography | 9 | Radial labels and measured bounds pass; native glyph substitution remains a separate release gate. |
| Color and contrast | 9 | Appearance-specific selection colors, separate focus, readable disabled inspection, and opaque variants remain sound. |
| Interaction model | 9 | Pending cancellation, fresh child entry, Back rearming, boundary ownership, and bounded persistent clicks pass. |
| Information architecture and copy | 9 | Stable directions, one child level, explicit toggle consequences, and the separate pointer browser remain clear. |
| States and feedback | 9 | Clear recovery and capture exclusion now work; Escape still leaves stale browser editing presentation. |
| Motion | 9 | Stable hover nodes and restrained timing remain; Reduce Motion removes spatial and content transitions. |
| Accessibility | 8 | Keyboard returns now retain menu focus, but mouse entry into the visible list loses it and held list opening takes it. |
| Pointer browser | 8 | Candidate confirmation, swaps, assignment focus, search, spatial arrows, and vertical scrolling pass; long assignment labels overflow. |
| Prototype fidelity | 9 | The six targeted repairs and supplied references are reviewable; remaining HTML interaction defects prevent a clean handoff. |
| **Overall** | **88/100** | **B. One P1 and two P2 findings remain.** |

## Evidence and limits

Consulted sol/REVIEW.md, the merged sol/ROUND2.md, and GRADE-1 through GRADE-3. Read the 554-line v6 file and inspected all seven supplied states-v6 PNGs. SHA-256 checked before and after review: `8e9707e069bfcd9a13a00fe96b135ccade2fd3b375b4fbe3cf5846db61f28bd4`.

I served the frozen HTML on my own local Mac server at 127.0.0.1:8784. The server resolved the existing absolute artwork URLs to their original files. An in-memory stylesheet supplied the system-font and theme host variables expected by the prototype. No source or prototype file was changed. Size probes changed only the browser's stage dimensions.

An owned T3 tab exercised real clicks, search input, Return, Tab/Shift-Tab, arrows, Escape, Control-Option-Right, Command-Z, and Shift-Command-Z. Held gestures used synthetic PointerEvents through the installed listeners and the real 180 ms timer. Additional state matrices used the prototype's own functions and controls. These establish HTML behavior, not native modifier ownership or physical input draining.

Live snapshots failed twice with `Preview automation snapshot timed out after 15000ms.` Functional input and DOM inspection remained usable. Fresh static visual checks used T3's separate HTML renderer with host variables and automatic image inlining. Those inspection copies disabled transitions and made the queued panel-focus callback synchronous so a prepared scrolled state could be captured. Behavioral conclusions use the unmodified live handlers. Resize claims were checked after observer delivery, rather than immediately after changing dimensions. Animation timing and node identity are not frame-rate measurements.

## Disposition of every GRADE-3 finding

| GRADE-3 finding | Status | V6 result |
| --- | --- | --- |
| 1. Editing Return applies the live pointer; assignment loses focus, P1 | Fixed | Mouse Bubblegum candidate plus real Return kept Coral live, left favorites unchanged, announced the candidate, and focused the first enabled Use button. Search Return did the same. Use assigned or swapped without choosing the live pointer, then focused the labeled slot row when its button became Already here. |
| 2. Short favorites pane collapses, P1 | Fixed for the reported vertical failure | At 320×360 the shared body viewport was 247 pt; at 320×180 it was 67 pt. All six 34 pt rows and 28 pt buttons could scroll fully into view. Candidate click, Return, Use/swap, focus, and Done worked at the short sizes. Long-candidate horizontal overflow is a new finding below. |
| 3. Back discards menu focus, P1 | Fixed for the reported return routes | Explicit Back, Escape, and Backspace returned to the labeled radial or visible list menu with focus/candidate both -1. Real radial Back and list Escape passed. Mouse forward entry is a separate remaining branch below. |
| 4. Clear snackbar contaminates Screenshot, P1 | Fixed at HTML level | Before the modeled capture boundary, the snackbar had visibility hidden while its recovery state remained intact; menu opacity was 0, marker display none, toast empty, and cue empty. Both motion settings restored the valid recovery afterward. Undo during the interval expired it without resurrecting its controls. |
| 5. First narrow footer is measured while hidden, P2 | Fixed | The first 296 pt-wide panel already showed Edit favorites… and hid the count. Resizing an open wide panel to 296×156 updated narrow/short classes and footer copy through the observer. |
| 6. Clear reference crops the recovery controls, P2 | Fixed | states-v6/clear-snackbar.png is a complete 760×880 capture; Drawing cleared, Undo, dismissal, and surrounding clearance are visible. |

The summary's blanket claim that persistent entry always focuses the displayed group, while Hold stays nonactivating, is too broad. The list branches still contradict it.

## Fresh sweep

| Exercise | Observed result |
| --- | --- |
| Pending Hold cancellation | Ordinary input, a Command chord, each added modifier, Escape, pointer cancellation, lost capture, and blur canceled the pending session. Later southeast travel/release left DOC.cur at 2. Only Escape was prevented in the keyboard cases. |
| Held selection and Back | North entry opened Pointer at the actual entry point with no candidate. A later east stroke acquired Coral; release applied it once. Explicit Back set needNeutral, blocked outward acquisition, and allowed another group only after neutral entry. Parent-center return also worked. |
| Edges and layout | Invocation at 20,20 clamped to 192,192 and stayed unarmed until neutral entry. Leaving the simulated display cleared eligibility; release canceled. An actual stage resize canceled after ResizeObserver delivery. |
| Persistent pointer path | Hover previewed without entering. Matching down/up entered a group at the click point without a child candidate. Dragging away from Clear did not execute; an outside down/up dismissed without changing the document. |
| Keyboard and unavailable commands | Opening had no executable default. Return routes retained focus. Disabled Undo and Redo retained their reason, lacked an executable highlight, and did not alter document history. Protected modified chords did not navigate the browser. |
| Small display | At 320×180 the list fit its 156 pt viewport, retained row identity through eight real Tabs, and scrolled More fully into view at scrollTop 107. Keyboard child entry and return worked. Mouse child entry left focus on BODY. |
| Clear recovery | Recovery survived more than 1.4 seconds and an unrelated pointer choice. Direct Undo restored both modeled strokes and removed recovery controls. Dismiss focused the stage. Real Command-Z and Shift-Command-Z restored and recleared afterward. |
| Browser search and navigation | Empty results removed aria-activedescendant and Return did nothing. Ordinary Cloud search/Return selected and closed. Seven-column Down moved Coral to Midnight; three-column Down moved Coral to Bubblegum. Quick controls scope preserved saved slot order. All pointers ended the radial session before opening the browser. |
| Favorites | Mouse candidates and both Return routes left the live pointer alone. New assignment and existing-favorite swaps worked. Assignment focused the correct labeled slot. Done worked; Escape removed the editor but left its presentation stale. |
| Appearance and accommodations | Exercised dark/light, Glass, Reduce Transparency, Increase Contrast, and both motion settings. Opaque variants removed blur. Fresh settled light selected-focus rendering used white on deep coral with a separate blue/white outline. Reduced motion used opacity-only opening, immediate highlight/hub/content replacement, and immediate cancellation. |
| Geometry | All 41 sector boundaries and their adjacent samples passed, including seven-way wrap. All 188 measured label corners stayed inside the outer radius and their sector. Screenshot retained about 10.18 pt outer clearance; Match retained about 0.67 degrees angular clearance. |
| Motion and other actions | Base, highlight, and item nodes survived hover. Normal opening/highlight/hub/child timings remained 120/60/80/100 ms. Draw exited Interact; sound/mute state changed; Toolbar hid; Settings focused Close; Pointer off hid ink/toolbar and supplied a working Turn on route. |

## Remaining defects and exact fixes

### 1. P1. Small display still has an inconsistent focus policy

HTML lines 385, 395 to 399, and 417 to 419.

In Click mode at a 320×360 stage, initial focus correctly reached lmenu. A real mouse click on the visible Pointer row rebuilt the list as Pointer, cleared the candidate, and left document.activeElement on BODY. Clicking the new Back row correctly restored lmenu. Keyboard forward entry is repaired because activate calls focusMenu only when viaKey is true. Mouse forward entry still destroys the focused row without transferring focus to the replacement menu.

The same policy has the opposite error during held opening. With a known demo control focused, ordinary radial Hold left that control focused; Small display Hold instead moved focus to lmenu. The small-open branch checks only !auto, not mode. This is a directly observed DOM focus difference, not a claim about native window activation.

**Exact fix:** After building a child list in persistent mode, call focusMenu for mouse as well as keyboard entry, preserving focus/candidate -1. Guard automatic list opening and return focus by the same persistent-mode policy used for the radial presentation. Hold must leave prior focus alone unless the user explicitly transfers to persistent keyboard operation. Retest mouse Pointer/Color/Draw/More entry, their Back routes, and held opening with a known prior focus. Do not rely on the next globally intercepted Tab to repair BODY focus.

### 2. P2. Long candidate labels overflow narrow favorite rows

CSS lines 141 to 150 and HTML line 474.

At a 320×360 stage, search Presentation while editing. This is an existing catalog item, not an invented custom name. Each button becomes Use Presentation pointer. With the six default favorites, the NE row's scroll width reached 296 pt inside a 264 pt row. Its button extended to x=324.25 while the panel ended at x=308. The shared body also acquired horizontal overflow. Vertical reachability is repaired, but a narrow editor still requires sideways recovery to see a complete control.

**Exact fix:** In narrow rows, use a short visible Use label with the complete candidate and destination in its accessible name. Give the favorite-name region min-width:0 and wrapping, and keep direction, artwork, and button dimensions stable. A two-line row is acceptable; clipping names or hiding overflow alone is not. Verify all six rows with Presentation pointer as candidate and as a saved favorite at both 320×360 and 320×180. No horizontal scroll should be required, and each complete button must remain visible.

### 3. P2. Escape exits editing without updating the browser's presentation

HTML line 487.

After real Escape from the favorite editor, slots.open was false and focus correctly reached bedit. The button still read Done editing, bgrid still had editing, and the footer still read Selected: Presentation pointer. Unlike Done and the footer toggle, this branch never calls renderBrowser. The visible editing affordances now describe a mode that has already ended. Clicking the apparent Done editing button reopens editing.

**Exact fix:** Use the same finish-editing routine for Escape, Done, and the footer action. Remove slots.open, render the browser to update its class/name/button, then focus bedit. On a narrow panel it must read Edit favorites… immediately. Confirm that normal Return-to-select resumes only after that visible mode change.

## What remains before 90

Fix the three findings above, then rerun their exact paths. Persistent Small display entry must retain focus on its displayed menu, Hold must preserve prior focus, every narrow favorite row must fit the existing long catalog names, and Escape must visibly leave editing. Those are the remaining HTML requirements identified here. No new radial map or visual theme is needed. A fresh passing review is required; this is not an automatic two-point promise.

## Native release gates, unscored

- Replace the stand-ins with real SF Symbols. Verify system typography, native material, actual contrast over bright/busy content, and final glyph bounds at 1x/2x.
- Verify VoiceOver, Full Keyboard Access, Voice Control, enlarged cursor, larger-text list operation, command accessibility state, and prior application/responder restoration.
- Verify native modifier triggering, session IDs, stale-release rejection, cancellation, claimed input-pair draining, commit-time revalidation, and no click-through. Synthetic HTML events do not establish these.
- Verify real Screenshot success and failure, its saved file, and exclusion of every overlay and feedback layer. The HTML only models sequencing.
- Verify Dock/menu-bar/full-screen edges, multiple displays with negative coordinates and mixed scales, display crossing/removal, and system accommodation changes.
- Run ROUND2's three physical experiments locally: reanchoring with mouse/trackpad, eight versus six root choices including Clear slips and recovery, and actual display/accessibility behavior.

No source or prototype was edited, no Mac app was built or launched, no hosted CI ran, and no commit was made. This report is the only repository file written. The temporary review server was stopped; Claude's 127.0.0.1:8777 server was left untouched.
