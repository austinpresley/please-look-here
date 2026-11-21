# V5 shipping design grade

Review sub-agent, 16 November 2026. Frozen subject: [prototype-v5.html](../claude/prototype-v5.html).

**84/100, B. Below 90. Do not ship this HTML design as-is.** No P0 was reproduced. The pending-Hold P0 is fixed, and the radial geometry is now credible. Favorite editing, short browser layouts, focus after Back, and feedback exclusion during Screenshot still fail inside the HTML. These are concrete unfinished interactions, not a reason to reopen the eight-direction map.

Same rubric and scale as GRADE-1 and GRADE-2: ten equally weighted categories; A 90 to 100, B 80 to 89, C 70 to 79, D 60 to 69, F below 60. Any P0 blocks regardless of the total. Scores assess the demonstrated design, without points for improvement. Native-only gates listed below do not reduce this HTML score.

| Criterion | /10 | One-line justification |
| --- | ---: | --- |
| Visual craft | 9 | The two optical exceptions repair the measured sector bounds; the compact disc and content hierarchy hold together. |
| Iconography and typography | 9 | Full labels, measured blocks, and readable type work at the HTML approximation level; native symbol substitution is a separate gate. |
| Color and contrast | 9 | Both selection pairs, the focus halo, disabled inspection, and opaque/strong-divider variants behave consistently. |
| Interaction model | 9 | Pending cancellation, fresh child entry, Back rearming, boundary ownership, and display-edge arming pass the exercised paths. |
| Information architecture and copy | 9 | Stable root directions, one child level, explicit pending toggle copy, and a separate pointer browser remain clear. |
| States and feedback | 8 | Clear recovery now has the right lifetime and real controls, but its new snackbar contaminates the modeled capture interval. |
| Motion | 9 | Stable hover nodes and the specified transitions remain; Reduce Motion removes spatial and selection/content transitions. |
| Accessibility | 7 | Opening, stable list rows, visible scrolling, and protected chords improve access; Back and favorite assignment still discard DOM focus. |
| Pointer browser | 7 | Search, responsive columns, arrows, mouse candidates, and swaps work; Return escapes editing and the short editor collapses. |
| Prototype fidelity | 8 | Most outcomes are reviewable; capture exclusion and the cropped Clear reference still mislead a handoff. |
| **Overall** | **84/100** | **B. Four P1 findings and two P2 findings remain.** |

## Evidence and limits

Reviewed REVIEW.md, the merged ROUND2 specification, both prior grades, all 549 lines of v5, and all seven supplied states-v5 PNGs. SHA-256, checked before and after review: `e3fcf3c4046cced4c5767269c75c29cb398eb41b8227bb2a1634d2b5c7fef804`.

I served the frozen file on my own local server at 127.0.0.1:8783 and exercised an owned T3 browser tab. Direct HTTP viewing received system-font/theme host variables through an in-memory style element; the server resolved existing absolute artwork paths to their original local PNGs. No prototype file was adapted on disk. Fresh T3 HTML renders used its supplied host variables and automatic image inlining, with only in-memory state setup and disabled transitions for static inspection.

Real browser input covered clicks, search entry, Return, arrows, Tab/Shift-Tab, Escape, Control-Option-Right, Command-Z, and Shift-Command-Z. Held sequences dispatched PointerEvents through the installed listeners and waited for the real 180 ms timer. Those establish HTML state transitions, not native modifier ownership or physical input draining. Other state combinations used the prototype's own functions and controls in browser evaluation.

The live snapshot tool failed twice with `Preview automation snapshot timed out after 15000ms.` Live interaction and evaluation remained usable for most of the review. Fresh visual checks used the separate HTML renderer, including the narrow editor, 180 pt-high browser, and light selected-focus state. A later browser reconnection interrupted an attempted mouse-entry check in the small list; I do not use that attempt as evidence of an application defect. Focus-loss findings below were independently reproduced with successful keyboard input. Resize/capture observations were read after animation-frame callbacks, not inferred immediately after changing a size.

| Exercise | Observed result |
| --- | --- |
| Pending Hold | Ordinary `a`, a Command chord, Shift, Control, Option, Command, and Escape at 60 ms canceled the timer, invalidated the session, and drained release. Later Clear-direction travel/release left `DOC.cur` at 2. Only Escape was prevented. Pointer cancellation, lost capture, and blur also canceled. |
| Held navigation | North entry created Pointer at the entry point with candidate -1; a later east stroke selected Coral once. Explicit Back cleared eligibility and blocked further outward selection until neutral entry. Returning to the saved parent neutral region also worked. |
| Edges and invalid layout | Invocation at 20,20 clamped to 192,192 and remained unarmed; neutral entry armed it. Leaving the simulated display removed eligibility, and release canceled. An actual stage-size change canceled after ResizeObserver ran. |
| Persistent radial | Opening focused `qc` without an executable candidate; the automatic page-load demonstration did not steal focus. Hover did not enter a group, and outside down/up dismissed. Keyboard group entry focused the child. Activating its Back then left focus on BODY. |
| Clear and history | Clear removed the demo ink. Its two controls survived 1.45 seconds and a later Robot choice. Dismiss removed both buttons and focused the stage. Direct Undo restored both modeled strokes. Command-Z and Shift-Command-Z worked after closing/dismissal. |
| Search, grid, and scopes | Empty search results removed aria-activedescendant. Search/Return outside editing selected and closed normally. Seven-column Down moved Coral to Midnight; three-column Down moved Coral to Bubblegum. Quick controls scope preserved saved slot order. Narrow cells stayed horizontally inside the panel. |
| Favorite editing | A real cell click selected Bubblegum, updated Selected/Use text, and kept the live Coral pointer and browser unchanged. Return then changed the live pointer to Bubblegum and closed without assigning any favorite. Use swapped Glove/Lavender correctly, but focus became BODY. |
| Modified keys | Real Control-Option-Right left Midnight unchanged in the grid. The panel handler now checks Control/Option/Command before its navigation branches. Shift-Tab remains available. |
| Small list | Initial focus reached the displayed list. Rows retained identity across eight Tabs; More scrolled fully into the 156 pt viewport, with scrollTop 107. Child Back was first and reachable. Executing it returned to root but discarded DOM focus. Disabled Undo had transparent fill, an inspection outline, and its reason. |
| Narrow and short browser | At 320 pt stage width the panel was 296 pt and rendered three columns. At 320 by 360, editing left the favorites scroll viewport only 20 pt high. At 320 by 180, the browser scrolled internally, but fixed chrome initially covered the entire grid area. |
| Themes and accommodations | Exercised dark/light with Glass, Reduce Transparency, and Increase Contrast. Opaque variants removed blur. Settled selected text/symbols were plum on light coral in dark appearance and white on deep coral in light appearance. Reduced motion made highlight/hub/content replacement and cancellation immediate, with opacity-only opening. |
| Geometry and motion | All 41 exact boundaries across root and four child rings, plus samples 0.00001 degrees on either side, resolved correctly. Screenshot text had about 10.18 pt outer clearance; Match's closest text corner stayed about 0.67 degrees inside its sector. Backing/highlight/item identities survived hover. Normal transitions resolved to 120/60/80/100 ms for opening/highlight/hub/child content. |
| Other outcomes | Draw exited Interact and changed the tool. Sound/mute state changed, Toolbar visibly hid, Settings focused Close, and Pointer off hid ink/toolbar and supplied a working Turn on route. During Screenshot's frame interval the wheel had opacity 0, but Clear's snackbar still had display flex. |

The geometry measurements use logical SVG text bounds with system fonts at the browser's 1x scale. Final native glyph bounds at 1x/2x remain a release check, not an asserted result here. Motion inspection establishes node stability and computed timing, not frame-rate performance.

## Disposition of every GRADE-2 finding

Numbers refer to GRADE-2's nine ranked findings.

| GRADE-2 # | Status | V5 disposition |
| --- | --- | --- |
| 1. Pending Hold input cancellation, P0 | Fixed | Ordinary keys, shortcut chords, added modifiers, Escape, and lifecycle cancellation all terminated the exercised pending sessions. No later Clear executed. |
| 2. Mouse favorite editing | Partial | Mouse candidate selection and Use assignment/swap work. Editing still permits Return to apply the live pointer, and assignment destroys the focused slot control. |
| 3. Responsive pointer browser | Partial | Correct three/seven columns, no horizontal cell clipping, spatial arrows, and wrapping tools. The short editor collapses to 20 pt; initial narrow footer detection also runs while the browser is hidden. |
| 4. Accessible list and initial menu focus | Partial | Stable buttons, first-row Back, visible scrolled focus, disabled outline, and initial displayed-menu focus work. Returning through Back still loses focus in both presentations. |
| 5. Modified browser navigation | Fixed | The modifier guard is now inside panelKey before navigation. Real Control-Option-Right did not move the candidate. |
| 6. Clear recovery lifetime and hidden controls | Fixed | Separate persistent snackbar survives unrelated pointer feedback. Dismiss removes its controls and focuses stage; Undo/redo shortcuts remain functional. Its separate capture-exclusion regression is ranked below. |
| 7. Screenshot and Match content bounds | Fixed at HTML level | The -6 pt radial and -4 pt vertical exceptions are present and measured corners pass. Native symbols/Retina verification remains separate. |
| 8. Seven-sector floating-point holes | Fixed | Contiguous index computation passed every More tie and adjacent sample, including wrap, as well as all other rings. |
| 9. Incorrect selected-focus reference color | Fixed | The supplied light Increase Contrast reference shows white selected text, matching settled computed style and a fresh render. The cropped Clear reference is a different evidence defect below. |

## Remaining defects and exact fixes

No P0 reproduced. Four P1 findings still prevent sign-off.

### 1. P1. Favorite editing still has an accidental apply route and loses assignment focus

HTML lines 468 to 489.

After opening Edit, I clicked Bubblegum. The footer said Selected: Bubblegum, every Use button named Bubblegum, the live pointer remained Coral, and focus was on bgrid. Real Return reached panelKey's unconditional choose branch: the live pointer became Bubblegum, the browser closed, and FAV stayed unchanged. The editing mode's candidate semantics stop at the mouse handler.

Separately, real Use on the NE slot correctly swapped Glove and Lavender without changing the live pointer. renderBrowser/renderSlots replaced the focused button and left document.activeElement on BODY. This also violates GRADE-2's explicit requirement to preserve the corresponding slot after a swap.

**Exact fix:** Route search/grid Return through editing state before choose. While editing, Return confirms or retains the assignment candidate and keeps the editor open; only Use mutates slots. Keep ordinary Return-to-choose outside editing. Preserve slot identity during updates, or restore focus by slot index after rendering. If assignment disables that slot's Use button, focus a stable, labeled slot row rather than a disabled button or BODY. Apply the same candidate rule to mouse and keyboard activation.

### 2. P1. The short favorites pane is too small to operate

CSS lines 104 to 138.

At a 320 by 360 stage, the browser was 296 by 336. Its grid's minimum height was 152. The favorites element had a 21 pt border box and only a 20 pt scroll viewport, while rows were 34 pt and buttons 28 pt. The outer browser had no vertical overflow, so scrolling the panel could not recover space. No complete Use button could fit within its own scroller. The supplied narrow-editing PNG shows this same sliver. This is not a successful short-window fallback.

**Exact fix:** Stop flex shrink from collapsing the editor. Give title/footer nonshrinking dimensions and use a shared scrolling content region in short layouts, containing tools, a bounded grid, and the editor. In that mode let editor content have its natural height or a useful minimum viewport that fits complete rows, with its overflow handled by the shared region. Keep title/footer sticky without covering the only visible content. Retest candidate click, slot assignment, Done, and keyboard focus at 320 by 360 and 320 by 180. A scrollbar around a 20 pt hole is not a usable editor.

### 3. P1. Back replaces the focused control without focusing the new menu

HTML lines 393 to 418 and 524 to 525.

In the small list, Tab to More, Return, Tab to Back, Return restored root but left focus on BODY. The radial equivalent, root 1, Return, Shift-Tab to Back, Return, did the same. Global key interception makes the next Tab appear to recover, but accessible focus has already left the command hierarchy. Initial focus and forward entry are repaired; return navigation is not.

**Exact fix:** After every level replacement that clears the command candidate, explicitly focus the displayed, labeled menu container. Use the radial group for radial mode and the visible list's menu group for list mode. Cover explicit Back, Escape, and Backspace through one return routine. Preserve no default executable leaf. Verify document.activeElement belongs to the displayed menu after each route, before pressing another navigation key.

### 4. P1. Screenshot leaves the persistent Clear snackbar in the modeled captured scene

HTML lines 419 to 445.

Clear, reopen, Screenshot leaves `snack.hidden === false` and computed `display: flex` during the animation-frame interval. The wheel reaches opacity 0 and toast feedback is removed, but the newly separated snackbar is omitted from capture's exclusion work. The prototype now demonstrates a scene containing Drawing cleared / Undo when its contract says all Quick controls feedback is excluded.

**Exact fix:** Temporarily suppress the snackbar along with every other Quick controls feedback layer before the capture frame boundary. Restore the same pending recovery afterward if no intervening document edit or explicit dismissal expired it. Do not call hideSnack as a shortcut, because that would consume the persistent recovery state. Check the pre-capture scene with Clear recovery present, in both motion settings. An actual native capture and its error path remain separate release gates; this finding charges only the incorrect HTML exclusion sequence.

### 5. P2. Narrow footer sizing is calculated before the browser is displayed

HTML lines 456 to 466 and CSS lines 128 to 130.

openBrowser calls renderBrowser while the panel is hidden. clientWidth is zero, so the `|| 560` fallback suppresses narrow mode. At the first 296 pt-wide opening, the long Edit Quick controls label and count remained; the focused-name field had about 42 pt of width and the count wrapped. Clicking Edit caused a later render to discover the correct width. Width changes while open also have no footer-size update.

**Exact fix:** Set responsive footer presentation after making the panel measurable, and update it on panel resize, or use CSS/container queries. Ensure the initial narrow opening already uses Edit favorites and its intended count policy. Keep the footer on one text line and expose the complete candidate name accessibly when visual ellipsis is necessary.

### 6. P2. The Clear reference crops away the recovery action

[states-v5/clear-snackbar.png](../claude/states-v5/clear-snackbar.png) is 760 by 780. It cuts through the top of the bottom snackbar; its Undo and dismissal controls cannot be reviewed. Settled colors do not make this a usable full-state reference.

**Exact fix:** Capture the complete stage or use a taller image so the entire snackbar, both controls, and surrounding clearance are visible. Retain the corrected selected-focus reference. Do not treat a crop of the cleared slide as evidence that the recovery UI is visually finished.

## What remains before 90

Finish the six fixes above, then repeat the failed tasks. In particular, editing must keep the live pointer unchanged through candidate activation, preserve focus through assignment, and show complete slot controls at short sizes. Back must retain menu focus, and Screenshot must temporarily exclude the persistent recovery UI without deleting its state. Fix initial narrow footer detection and supply a complete Clear reference. Those are the remaining HTML requirements; no new command map or visual theme is needed. Completing them earns a new review, not an automatic six-point addition.

## Native release gates, excluded from this HTML score

- Replace stand-ins with real SF Symbols and verify native system typography, optical bounds at 1x/2x, material, and contrast over real bright/busy content. No deduction here merely because HTML uses stand-ins.
- Verify VoiceOver, Full Keyboard Access, Voice Control, larger-text list operation, enlarged cursor, real command actions, and prior application/responder restoration. HTML focus bugs above remain chargeable independently.
- Capture real local success and failure outcomes, verify the saved file, and prove exclusion of wheel, marker, browser, toast, and snackbar. Absence of a real capture operation in HTML is not itself charged.
- Verify the native modifier trigger, stale-release/session checks, ordinary-input policy, claimed key/button-pair draining, and no click-through. Synthetic PointerEvents cannot prove those.
- Verify menu-bar/Dock/full-screen edges, mixed Retina scales, negative-coordinate/multiple displays, ownership crossing, and display removal.
- Run ROUND2's three physical experiments locally: reanchoring with mouse/trackpad; eight versus six root choices including Clear slips and recovery; and edge/display/accessibility behavior under actual system settings. No HTML grade can substitute for them.

No source or prototype was edited, no Mac app was built or launched, no hosted CI ran, and no commit was made. This report is the only repository file written. My temporary server was stopped after review; Claude's 127.0.0.1:8777 server was left untouched.
