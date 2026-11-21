# V7 shipping design grade

Review sub-agent, 16 November 2026. Frozen subject: [prototype-v7.html](../claude/prototype-v7.html).

**89/100, B. No, this HTML design is not at or above 90. Do not ship it as-is.** No P0 reproduced. GRADE-4's browser failures are fixed. Its focus-policy finding is only partly fixed: Back still makes opposite mistakes in the two Hold presentations. One stale reference also needs replacement. Keep the command map and radial composition.

The rubric is unchanged: ten equally weighted categories, each out of ten. A is 90 to 100, B 80 to 89, C 70 to 79, D 60 to 69, F below 60. Any P0 blocks regardless of score. This grades demonstrated HTML behavior, without awarding points just for improvement. Native-only gates below are unscored.

| Criterion | /10 | One-line justification |
| --- | ---: | --- |
| Visual craft | 9 | The compact disc, measured blocks, optical exceptions, and narrow wrapped rows hold together. |
| Iconography and typography | 9 | The full label sweep passes at system-font scale; symbol substitution remains an unscored native gate. |
| Color and contrast | 9 | Appearance-specific selection, independent focus, readable disabled inspection, and opaque variants remain sound. |
| Interaction model | 9 | Cancellation, fresh child entry, Back rearming, ownership bounds, and completed-click commitment pass. |
| Information architecture and copy | 9 | Stable directions, explicit consequences, a separate browser, and fully named assignment actions are clear. |
| States and feedback | 9 | All three editing exits now agree; Clear recovery and modeled capture exclusion remain intact. |
| Motion | 9 | Stable hover nodes and restrained timings remain; Reduce Motion removes spatial and content transitions. |
| Accessibility | 8 | Persistent entry is repaired, but pointer-only list Back takes focus and keyboard radial Back loses it in Hold mode. |
| Pointer browser | 9 | Search, spatial arrows, assignment, swaps, short scrolling, long names, and editor exit pass their retests. |
| Prototype fidelity | 9 | The live repairs are reviewable, but the Hold return defect and obsolete short-editor reference leave an incomplete contract. |
| **Overall** | **89/100** | **B. One P1 and one P2 remain.** |

## Evidence and limits

Read sol/REVIEW.md, the merged sol/ROUND2.md, GRADE-1 through GRADE-4, the frozen v7 HTML, and its diff against v6. Inspected all eight supplied states-v7 PNGs. SHA-256 before and after the behavioral review matched the supplied value: `2dd85a7e0f3b42d147d66e6f00a8f72792c9b71ad2c6800d868c65c35a59b8ad`.

Served the unmodified file on my own local Mac server at 127.0.0.1:8785. The server resolved the existing absolute artwork URLs to their original files. Direct HTTP viewing received system-font and theme host variables through an in-memory stylesheet. Size probes changed only the browser's stage dimensions. No source or prototype file was adapted on disk.

An owned T3 browser tab exercised real clicks, search entry, Return, Tab/Shift-Tab, arrows, Backspace, Escape, Control-Option-Right, Command-Z, and Shift-Command-Z. Held gestures used synthetic PointerEvents through the installed listeners and the real 180 ms timer. Additional matrices used the prototype's own functions. The pointer-only Hold list Back finding uses a dispatched MouseEvent through the installed click handler, with detail 1 and a known external control focused. The Hold radial keyboard Back failure was also reproduced with real keys. These establish HTML focus and state behavior, not native activation or physical input draining.

Live snapshots failed twice with `Preview automation snapshot timed out after 15000ms.` Functional input and DOM inspection remained usable. Two list-click attempts during a viewport change also timed out after the resize observer closed the session; those attempts are excluded from defect evidence. Fresh visual checks used T3's separate HTML renderer, including the narrow long-name editor, light selected-focus state, Draw, and More. Inspection copies disabled transitions and made the queued initial panel-focus callback synchronous so the prepared scrolled state could be captured. Behavioral findings use the unmodified handlers. Resize cancellation was checked after observer delivery in a subsequent evaluation. Geometry uses logical SVG bounds at browser scale 1; motion checks establish node stability and computed timing, not frame-rate performance.

## Disposition of every GRADE-4 finding

| GRADE-4 finding | Status | V7 result |
| --- | --- | --- |
| 1. Small display focus policy, P1 | Partly fixed | Real mouse entry into Pointer, Color, Draw, and More in Click mode now focuses the replacement lmenu with focus/candidate both -1. Their mouse Back routes retain that menu focus. Hold opening in both presentations preserves the prior control, and pointer-only forward-entry probes do likewise. Back still violates the policy, detailed below. |
| 2. Long candidate overflow, P2 | Fixed | At 320×360 and 320×180, Presentation pointer as candidate and as the saved favorite in each of six slots produced no horizontal overflow. All 72 row-placement checks allowed a complete assignment button to scroll into view. Visible Use/Here labels and full assignment names are present. |
| 3. Escape leaves editing presentation stale, P2 | Fixed | Escape, Done, and the footer action all remove slots.open, clear bgrid.editing and the Selected: prefix, focus bedit, announce completion, and restore Edit favorites… or Edit Quick controls… immediately. |

The three implementation claims therefore have different outcomes. Narrow-row repair passes. Shared finishEditing passes. The blanket focus-policy claim does not pass its return paths.

## Fresh full sweep

| Exercise | Observed result |
| --- | --- |
| Pending Hold cancellation | Ordinary input, a Command chord, Shift, Control, Option, Command, Escape, pointercancel, lost capture, and blur canceled pending invocation. After the real timer interval, later southeast travel/release left DOC.cur at 2. Only Escape was prevented among the keyboard cancellation cases. |
| Held selection and Back | North entry created Pointer at the entry event with no child candidate. Later east travel acquired Coral; release applied it. Explicit Back set needNeutral and blocked outward acquisition until neutral entry. Returning to the saved parent center also worked. |
| Edges and layout | Invocation at 20,20 clamped to 192,192 and stayed unarmed until neutral entry. Leaving the simulated display cleared eligibility; release canceled. An actual stage resize canceled after observer delivery. |
| Persistent pointer path | Hover previewed without navigation. A real completed radial click entered Pointer at its click point with no child candidate and retained qc focus. Drag-away from Clear did not execute; outside down/up dismissed without changing the document. All four group-entry focus branches also passed direct activation probes. |
| Keyboard and disabled commands | Persistent initial opening had no executable default. Real Backspace and explicit keyboard Back returned to qc; Escape at root restored the prior control. Disabled Undo and Redo retained their explanation, had no executable candidate, and did not change history. Hold radial keyboard Back is the remaining P1. |
| Small display | At 320×180, the list fit a 156 pt viewport. Rows retained identity through eight real Tabs; More scrolled fully into view at scrollTop 107. Keyboard entry and persistent Escape return worked. Pointer-only Hold list Back still took focus. |
| Clear recovery | Clear removed the modeled strokes. Recovery survived 1.45 seconds and an unrelated Robot choice. Real Undo restored both modeled strokes and removed its controls. Dismiss removed both buttons and focused the stage. Real Command-Z and Shift-Command-Z restored and recleared. |
| Capture exclusion | With Clear recovery present, both motion settings hid the snackbar before the modeled capture boundary, set menu opacity to 0, hid the marker, and emptied toast/cue. Recovery returned afterward. Undo during the interval expired it without resurrecting controls. |
| Browser search and scopes | Empty results removed aria-activedescendant and Return did nothing. Cloud search/Return selected and closed. Quick controls scope followed saved slot order. All pointers ended the radial session and focused browser search. |
| Browser navigation and focus | Seven-column Down moved Coral to Midnight; three-column Down moved Coral to Bubblegum. Real Control-Option-Right left the candidate unchanged. Tab and Shift-Tab stayed inside the editing dialog. |
| Favorite editing | A real Bubblegum cell click plus Return kept Coral live and left favorites unchanged. Use assigned Bubblegum, then a Lavender assignment swapped occupied slots. Both assignments focused the labeled destination row. Search Return also retained editing semantics. All three finish routes passed, including narrow and wide footer labels. |
| Narrow and short browser | Initial narrow opening already used Edit favorites…. Shared body viewports were 247 pt at 320×360 and 67 pt at 320×180. In the long-name matrices, each 264 pt row had scrollWidth 264, and the body had clientWidth/scrollWidth 296/296. No complete button fell outside the recoverable viewport. |
| Appearance and accommodations | Exercised dark/light with Glass, Reduce Transparency, and Increase Contrast. Opaque modes removed blur. Fresh light selected-focus rendering and immediate reduced-motion styles showed white text/symbols on deep coral, with a separate blue/white focus outline. Reduced cancellation had no transition and opacity 0. |
| Geometry | All 41 sector boundaries and samples 0.00001 degrees on either side passed, including More's wrap. All 188 measured label corners remained inside the outer circle and their sector. Screenshot retained about 10.18 pt outer clearance; Match retained about 0.67 degrees angular clearance. |
| Motion and other outcomes | Backing, highlight, item, and semantic node identities survived hover. The 120/60/80/100 ms opening/highlight/hub/child timings remain. Draw exited Interact; sound/mute changed state; Toolbar hid; Settings focused Close; Pointer off hid ink/toolbar and provided a working Turn on route. |

## Remaining defects and exact fixes

### 1. P1. Back still has two incompatible focus policies in Hold mode

HTML lines 399 to 401 and 419 to 421. This is the unresolved part of GRADE-4 finding 1, with a newly exercised keyboard branch.

**Pointer-only Small display return takes focus.** With Hold mode, sess.kb false, and a known theme control focused, opening the list and entering Pointer preserved that control. Dispatching a normal pointer-style click through the Back row's installed handler returned to root and moved document.activeElement to lmenu. No keyboard transfer had occurred. The list branch of goBack calls focusMenu unconditionally.

**Keyboard-operated radial return loses focus.** On a full display in Hold mode: real Tab, Return opens Pointer and focuses qc; Shift-Tab focuses qc-pointer-0, Back; Return returns to root but leaves document.activeElement on BODY, despite sess.kb being true and the menu remaining open. The same failure reproduced for Color, Draw, and More through their normal activation functions. The radial branch only focuses the new menu when mode is click. activate sets kb after goBack and update has no focused item to repair the loss.

**Exact fix:** Give opening, forward entry, and every return route one explicit focus-ownership policy. Pointer-only Hold must preserve prior focus. Persistent invocation and an explicit transfer to keyboard operation must focus the displayed replacement menu after rebuilding, with focus/candidate still -1. Track that ownership separately from the hover-versus-keyboard highlight flag, which track() resets. Pass keyboard intent into the return routine before it rebuilds, or record it on the session first. Apply the same guard to list and radial Back. Retest all four groups in pointer-only Hold, keyboard-operated Hold, and Click mode. Do not depend on the next intercepted Tab to recover BODY focus.

### 2. P2. The short-editor reference still documents v6 labels

[states-v7/browser-short-editing.png](../claude/states-v7/browser-short-editing.png) is byte-identical to the v6 reference. It shows Use Robot and Already here in a 296 pt-wide browser. Actual v7 at that width shows Use and Here. The new long-name reference and a fresh render agree with the live implementation; the old short-editor image contradicts them.

Reusing unchanged reference states is fine. This state changed. Its SHA-256 in both sets is `173d611d4adbf248d85e75fb2e1634b95e9a80f724a564f6fb40d20a6e63e731`.

**Exact fix:** Regenerate only the short-editor reference from the frozen replacement HTML at the same 320×360 stage, after narrow/short sizing and scroll position settle. Show Use/Here, the complete panel chrome, and enough scrolled content to review complete rows. Keep the new long-name reference. This is a handoff-evidence defect, not another live overflow defect.

## What remains before 90

Repair the shared Back focus policy in both Hold presentations, and replace the obsolete short-editor reference. Then rerun those exact paths. The narrow long-name repair and finishEditing repair do not need redesign. No new command map, palette, or motion treatment is warranted.

**The HTML is below 90 now.** A passing new review is required; these fixes are not an automatic point award. The native checks below do not reduce this HTML score.

## Native release gates, unscored

- Substitute real SF Symbols and verify native system typography, material, contrast over bright/busy content, and final glyph bounds at 1x/2x.
- Verify VoiceOver, Full Keyboard Access, Voice Control, larger-text list operation, enlarged cursor, real command accessibility state, and prior application/responder restoration.
- Verify native modifier triggering, session IDs, stale-release rejection, cancellation, claimed input-pair draining, commit-time availability validation, and no click-through. Synthetic HTML events do not prove these.
- Verify actual Screenshot success and failure, its saved file, and exclusion of every overlay/feedback layer. The HTML only models sequencing.
- Verify Dock/menu-bar/full-screen edges, mixed scales, negative-coordinate/multiple displays, crossing/removal, and system accommodation changes.
- Run ROUND2's three physical experiments locally: reanchoring with mouse/trackpad, eight versus six root choices including Clear slips/recovery, and real display/accessibility behavior.

No source or prototype was edited, no Mac app was built or launched, no hosted CI ran, and no commit was made. This report is the only repository file written. The temporary review server was stopped; Claude's 127.0.0.1:8777 server was left untouched.
