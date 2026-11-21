# V9 shipping design grade

Review sub-agent, 16 November 2026. Frozen subject: [prototype-v9.html](../claude/prototype-v9.html).

**90/100, A. Yes, the HTML design is at or above 90. Ship this HTML design as-is.** Both GRADE-6 P1 findings are fixed. No new P0, P1, or P2 was demonstrated in the fresh sweep. Keep the command map, composition, palette, and browser layout. Native release verification remains separate and unscored.

The rubric and scale are unchanged. Ten categories carry ten points each. A is 90 to 100, B 80 to 89, C 70 to 79, D 60 to 69, F below 60. Any P0 blocks regardless of score. This grade assesses demonstrated HTML behavior.

| Criterion | /10 | One-line justification |
| --- | ---: | --- |
| Visual craft | 9 | The compact disc, measured blocks, optical exceptions, and narrow editor remain composed. |
| Iconography and typography | 9 | Full labels and all measured radial text bounds pass at system-font scale. |
| Color and contrast | 9 | Both selection pairs, independent focus outlines, readable disabled inspection, and opaque variants pass. |
| Interaction model | 9 | Cancellation, fresh child selection, Back rearming, display bounds, and matching down/up commitment pass. |
| Information architecture and copy | 9 | Stable directions, explicit toggle consequences, full names, and separate favorite editing remain clear. |
| States and feedback | 9 | Editing exits agree; Clear recovery persists and survives modeled capture exclusion correctly. |
| Motion | 9 | Hover preserves nodes; the specified timings and immediate reduced-motion replacement and cancellation pass. |
| Accessibility | 9 | The full focus-ownership matrix now passes, including real list clicks and mixed keyboard/pointer Hold navigation. |
| Pointer browser | 9 | Search, spatial arrows, editing Return, swaps, assignment focus, and short long-name layouts pass. |
| Prototype fidelity | 9 | The frozen behavior and all eight unchanged reference images now support the HTML handoff. |
| **Overall** | **90/100** | **A. No demonstrated HTML blocker remains.** |

## Disposition of every GRADE-6 finding

| GRADE-6 finding | Disposition | V9 evidence |
| --- | --- | --- |
| P1. Pointer-only Hold list clicks take focus, then discard it | Fixed | Real browser down/up clicks entered Pointer, Color, Draw, and More and returned through each Back row. The same external Dark control retained focus throughout. No menu row received focus, no BODY focus loss occurred, and every replacement started with focus/candidate both -1. |
| P1. Pointer-driven forward entry bypasses focus transfer after keyboard ownership | Fixed | Real Tab established ownership, then real pointer movement opened every radial group. Each child immediately focused qc with kbOwn true and focus/candidate both -1. Real movement through explicit Back retained qc and set needNeutral. Parent-center returns also retained qc. No recovery Tab was needed. |

Claude's two implementation claims hold up. The eligible list pointerdown cancels browser-default mouse focus without removing click activation; its mousedown guard covers the mouse-only path. The shared enterChild routine now performs the guarded transfer after either presentation rebuilds. Removing activate's duplicate transfer did not regress keyboard entry, Click mode, or Back.

## Focus-ownership matrix

Every row below covers Pointer, Color, Draw, and More separately. Menu replacement means focus/candidate both -1 before another navigation key. Pointer-only Hold retains the external control. Once the session owns focus, radial replacements focus qc and list replacements focus lmenu.

| Mode and presentation | Entry and explicit Back | Escape and Backspace | Parent-center return |
| --- | --- | --- | --- |
| Pointer-only Hold, radial | Real pointer movement preserved external focus through all four entries and explicit Back; Back required neutral rearming. | Escape canceled and preserved prior focus. Backspace has no Hold navigation action. | Preserved external focus in every group. |
| Pointer-only Hold, list | Real down/up entry and Back clicks preserved external focus in all four groups. | Escape canceled and preserved prior focus. Backspace has no Hold navigation action. | Not applicable to a list. |
| Keyboard-owned Hold, radial | Real number/Return entry and keyboard Back passed; real Tab followed by pointer entry and explicit Back also passed. | Real Escape canceled and restored prior focus. Real Backspace left the child and qc focus intact. | Retained qc in every group, including real pointer movement. |
| Keyboard-owned Hold, list | Real keyboard entry/Back and real mouse entry/Back retained lmenu in all four groups. | Real Escape canceled and restored prior focus. Real Backspace left the child and lmenu focus intact. | Not applicable to a list. |
| Click, radial | Real down/up entry and Back clicks, plus real keyboard entry and Back, retained qc. | Real Escape and Backspace returned to root, then closed at root and restored prior focus, for every group. | The geometric shortcut belongs to Hold. |
| Click, list | Real down/up entry and Back clicks, plus real keyboard entry and Back, retained lmenu. | Real Escape and Backspace returned to root, then closed at root and restored prior focus, for every group. | Not applicable to a list. |

The complementary installed-handler matrix checked 80 applicable route cases, with 16 geometric cases marked not applicable. It had no failures. Real keyboard checks separately covered 48 child-entry/return combinations and 16 complete Click-mode return-and-close paths. Real mouse input independently covered both reported failures and every list ownership branch. The pointer-only list result does not depend on a synthetic click-only replay.

## Fresh full sweep

| Exercise | Observed result |
| --- | --- |
| Pending Hold cancellation | Ordinary input, a Command chord, Shift, Control, Option, Command, Escape, pointercancel, lost capture, and blur canceled pending invocation. Waiting beyond the actual timer, then traveling southeast and releasing, left DOC.cur at 2. Only Escape was prevented among keyboard cases. |
| Held selection and cancellation | Pending movement updated the opening origin. North entry opened Pointer at the entry event with no child candidate. A later east stroke acquired Coral; release applied it. Unentered-group release, child-neutral release, and held Escape canceled without changing the pointer. |
| Back and rearming | Explicit Back cleared the candidate and set needNeutral. Outward travel remained blocked until neutral entry; a subsequent Draw entry worked. Saved-parent-center return passed in all four groups. |
| Edges and invalid layout | Invocation at 20,20 clamped to 192,192 and stayed unarmed until neutral entry. Leaving the stage cleared eligibility and showed Return to this display; release canceled. A stage resize canceled after observer delivery. |
| Persistent pointer path | Hover previewed without entering. Real matching down/up entered each group at its click point with no child candidate. Drag-away from Clear did not execute; outside down/up dismissed without changing the document. |
| Keyboard and disabled commands | Opening had no executable default. Disabled Undo and Redo retained their reasons, candidate -1, and unavailable semantics; Return did not alter history. Return paths and prior-focus restoration passed the matrix above. |
| Small display | At 320 by 180, the list fit its 156 pt viewport. Rows retained identity through eight real Tabs; More scrolled fully into view at scrollTop 107. Keyboard entry and Escape returned focus to lmenu. |
| Clear recovery | Its two controls survived 1.45 seconds and an unrelated Robot choice. A real Undo click restored both modeled strokes and removed recovery controls. Real Dismiss removed both controls and focused the stage. Real Command-Z restored; Shift-Command-Z recleared. |
| Capture exclusion | Both motion settings hid recovery before the modeled capture boundary and restored it afterward. Undo during capture expired recovery without resurrecting controls. Additional radial probes began with marker, arming cue, recovery, and prior toast present; capture removed the session, marker, cue, and toast, hid recovery, and resolved menu opacity to 0. |
| Browser search and launch | Empty search removed aria-activedescendant and real Return did nothing. Real Cloud search/Return selected and closed. All pointers ended the radial session and focused search. Quick controls scope followed saved slot order. |
| Browser navigation and focus | Real Down moved Coral to Midnight in seven columns and to Bubblegum in three. Real Control-Option-Right left the candidate unchanged. Sixteen real Tab/Shift-Tab steps stayed inside the editing dialog. |
| Favorite editing | A real Bubblegum cell click plus real Return kept Coral live and favorites unchanged. Real Use assigned Bubblegum; assigning Lavender to an occupied slot swapped identities. Both assignments focused the labeled destination row. Search Return also retained editing semantics. |
| Editing exits | Escape, Done, and the footer action removed slots.open, bgrid.editing, and the Selected prefix, focused bedit, and immediately restored the correct narrow or wide Edit label. |
| Narrow and short editor | Body viewports were 247 pt at 320 by 360 and 67 pt at 320 by 180. Presentation pointer as candidate and as each saved favorite passed all 84 row/button reachability checks. Body clientWidth/scrollWidth stayed 296/296; complete buttons required no horizontal recovery. |
| Appearance and accommodations | Dark/light crossed with Glass, Reduce Transparency, and Increase Contrast passed computed-style inspection. Opaque variants removed blur. Light selection used white on deep coral; dark used plum on light coral. The separate two-stroke focus outline remained present. |
| Geometry | All 41 exact boundaries and samples 0.00001 degrees on either side passed both sector calculation and tracking. All 188 measured label corners stayed inside radius 156 and their sector. Screenshot retained 10.18 pt outer clearance; Match retained 0.67 degrees angular clearance. |
| Motion | Base, highlight, item, and semantic-command nodes survived hover. Opening/highlight/hub/child timing remained 120/60/80/100 ms; Back content used 80 ms. Reduce Motion removed transforms and highlight/hub/content transitions. Cancellation had transition none and opacity 0. |
| Other outcomes | Draw exposed Turns Interact off before activation and exited Interact. Sound and mute toggled. Toolbar hid. Settings focused Close. Pointer off hid ink/toolbar and supplied a working real-click Turn on route. |

## New demonstrated defects and exact fixes

None. No new P0, P1, or P2 was demonstrated. There is no additional HTML fix required for this handoff. Do not reopen the radial layout to solve the two focus paths that are now repaired.

## Evidence and limits

Consulted sol/REVIEW.md, the merged sol/ROUND2.md, and GRADE-1 through GRADE-6. Read the frozen v9 HTML and its diff against v8. Inspected all eight states-v9 PNGs and verified that each is byte-identical to its v8 counterpart. Unchanged visuals are appropriate for these focus-only repairs. Fresh T3 HTML renders checked light selected focus, Draw, More, and the short editor; they produced no console errors.

The supplied HTML SHA-256 matched before and after behavioral review:

`58beb3c4d29ff5f69d3d0f820f834666e714eb2e7b82da6fef622d8d6af2084d`

Served the unchanged file on my own local Mac server at 127.0.0.1:8797. Absolute artwork URLs resolved to their original files. An in-memory stylesheet supplied the system-font and theme variables expected from the rendering host. Size probes changed only stage dimensions in memory.

Real browser input covered successful down/up clicks, pointer movement, search typing, keyboard navigation, assignment, and history shortcuts. Held invocation/cancellation exercises used synthetic PointerEvents through the installed listeners and the actual 180 ms timer. Other exhaustive matrices used installed handlers and prototype functions. These establish HTML state and DOM focus behavior. They do not establish native modifier ownership or physical input draining.

Interactive snapshots twice returned `Preview automation snapshot timed out after 15000ms.` Visual inspection therefore used the supplied references and the separate HTML renderer; successful input and DOM evaluation remained usable. Static visual copies disabled transitions, and the short-editor copy made initial panel focus synchronous to retain its prepared scroll position. Capture probes used the original capture handlers. An attempted small-list test raced resize cancellation, and an initial browser-arrow attempt preceded queued search focus. Those attempts and a resulting click timeout were discarded; both tests were repeated after verifying their preconditions. Resize cancellation was assessed in a subsequent evaluation. Settled colors and transition properties were checked rather than treating an unfinished color transition or an inert transition duration as a defect. Motion evidence establishes node stability and computed timing, not frame rate.

## Verdict

**Yes. V9 reaches 90/100, A, and the HTML design can ship as-is under this rubric.** The two GRADE-6 blockers are closed, the required focus matrix passes, and the fresh sweep demonstrates no new scored defect. This is approval of the HTML design handoff.

## Native release gates, unscored

- Substitute real SF Symbols and verify native system typography, material, contrast over bright/busy content, and final glyph bounds at 1x/2x.
- Verify VoiceOver, Full Keyboard Access, Voice Control, larger-text list operation, enlarged cursor, actual command accessibility state, and prior application/responder restoration.
- Verify native modifier triggering, session IDs, stale-release rejection, cancellation, claimed input-pair draining, commit-time availability validation, and no click-through.
- Verify actual Screenshot success and failure, its saved file, and exclusion of every overlay/feedback layer. The HTML models sequencing only.
- Verify Dock/menu-bar/full-screen edges, mixed scales, negative-coordinate/multiple displays, crossing/removal, and system accommodation changes.
- Run ROUND2's three physical experiments locally: reanchoring with mouse/trackpad, eight versus six root choices including Clear slips/recovery, and actual display/accessibility behavior.

No source or prototype was edited, no Mac app was built or launched, no hosted CI ran, and no commit was made. This report is the only repository file written. The owned browser tab was closed, the review server was stopped, and port 8797 had no remaining listener. Claude's 127.0.0.1:8777 server was left untouched.
