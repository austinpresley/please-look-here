# Quick controls, round 2

Sol review, 16 November 2026.

Keep Claude's eight root directions. Replace the outward fans with a full child ring. Drop my turn/pause gate. Use filled selection for commands, restrained selection around artwork and ink, and a separate searchable pointer browser.

This is the design I would approve for implementation, subject to the three local experiments below. The supplied prototype is not ready to become the implementation contract.

## Evidence and scope

I reread [REVIEW.md](REVIEW.md), [RESEARCH-NOTES.md](RESEARCH-NOTES.md), the brand brief, the radial source, the annotation history implementation, both existing native radial screenshots, [prototype.html](../claude/prototype.html), and all six supplied v2 screenshots. Prototype line numbers below refer to that HTML file.

I also loaded an in-memory copy of the HTML into an owned browser tab and exercised its existing selection and keyboard handlers. Those probes establish prototype state transitions, not native input behavior, material quality, or usability. Solid-color contrast and target chords were calculated locally. I did not edit source, build, launch the Mac app, commit, or upload anything. This document is the only file I wrote.

## The four disagreements

### 1. Eight root directions: Claude's

Undo earns direct access. Putting Undo behind History makes recovery harder precisely when someone is trying to recover. Clear can also be direct: `AnnotationDocument.clear()` checkpoints the complete annotation array before emptying it, and `undo()` restores that array. This is verified source behavior, not an inference from the prototype's counters. See [DrawingModel.swift](../../../Sources/TinyHand/DrawingModel.swift), lines 123 to 147.

I withdraw the six-item requirement. Keep the clockwise map from north: Pointer, Color, Draw, Clear drawing, Interact, Screenshot, Undo, More. Redo belongs in More. Keep all eight positions when commands are unavailable. Clear requires no confirmation because one Undo restores it. The hub must say that, and Undo must remain available after dismissal.

Two parts of Claude's argument need qualification. No supplied usage data establishes that Clear and Screenshot are among Austin's most frequent actions. Also, the 89 pt chord at radius 116 is correct geometry, but the prototype puts ordinary root content at radius 99, where the chord is about 76 pt. Neither number establishes an error rate. Kando does recommend eight as a rule of thumb; that supports trying eight, not a claim of optimality. [Kando layout guidance](https://kando.menu/creating-menus/)

Exact change: retain eight 45-degree sectors, but use the 328 pt diameter and content radius 118 from my proposal. Use the full label "Clear drawing", wrapped if necessary. Do not squeeze eight labels into the prototype's smaller disc merely to preserve its dimensions.

### 2. Outward fans: hybrid

Keep my full replacement child ring and reanchoring. Remove my 30-degree turn or 80 ms pause requirement. Claude is right that this gate is an extra interaction rule that the drawing does not adequately explain.

The fan's decisive weakness is the combination of narrow angular tolerance, overlapping command directions, and screen-edge cost. Color has nine choices in 150 degrees, so each gets 16.67 degrees. Its chord is about 45 pt at the fan entrance and 56 pt at the artwork radius. Pointer's seven choices get 21.43 degrees and about 72 pt at the artwork radius. These are usable sizes for some people, but they offer much less directional tolerance than a full child ring. The larger radius partly compensates for angle; comparing angles alone would overstate the case against fans.

Keeping the root visible also promises more than the hit testing delivers. At radius 190 and angle 135, the prototype selects Clear when approached directly, but Number after hovering Draw. Color can capture Black at angle 128 even though its drawn fan ends at 120. Root commands therefore do not remain independently selectable to the screen edge. The current fan owns those directions. Fixing that requires an explicit choice of which level owns the gesture; the visible root does not resolve it.

A 464 pt maximum fan envelope also reverses much of the footprint improvement and makes clamping harder. This is not a claim that every fan occupies a 464 pt square. It is the diameter needed to accommodate every possible fan direction around a fixed origin.

Exact change: crossing radius 112 in a root group replaces the root with a complete child ring centered at the actual cursor position of that entry event. Consume that event as navigation only. The new hub begins under the cursor, with no candidate. Subsequent movement of at least 72 pt from that new origin acquires a child. A straight continuation is allowed. There is no turn recognizer, dwell timer, or replay of movement left over from the entry event. A coalesced event cannot both open and select a child.

This deliberately changes my round-1 position on straight-through selection. A fresh visible hub, a new origin, and another full acquisition distance provide the distinction between levels. Whether that is enough is the first experiment below. A moving origin still has a cost, and I am not calling it proven.

Persistent mode enters a group only on a completed click, Return, Space, or an accessibility action. Hover previews the group in the hub. It does not navigate. Show one ring at a time, an explicit Back sector, and the current group name. Do not retain a second selectable root behind the child.

### 3. Filled coral highlight: hybrid

A filled selection is a stronger pending-action cue than my thin arc alone. It is appropriate for commands and monochrome tool glyphs. The prototype's white-on-coral gradient fails the contrast requirement, however. White against `#ff8a63` is about 2.32:1; against `#e8503c` it is about 3.72:1. Both are below 4.5:1 for these small labels. The resemblance to NSMenu does not make arbitrary brand colors safe.

Exact change: use a flat, contrast-tested selection token for commands and Draw choices. A starting light-mode pair of `#B6423B` with white gives about 5.48:1. In dark mode, `#FF9589` with `#302736` gives about 6.75:1. Treat these as solid-color starting pairs, not measured glass results. Use an on-selection foreground token, rather than hard-coded white.

Pointer artwork and ink retain a quiet tint plus a 2 pt outer arc. Do not flood a colored hand or ink sample with coral. Keep the current-state check separate from pending selection. A coral ring alone cannot mean both "already selected" and "will select". Keyboard focus needs its own outline. Apple calls for appearance-specific colors, adequate contrast, and alternatives to color-only meaning. [Apple color guidance](https://developer.apple.com/design/human-interface-guidelines/color)

### 4. All grid inside the wheel: Sol's

The native persistent browser is the better design for 39 or more pointers. The embedded grid currently demonstrates only 16. Its 236 pt width produces four small columns, no search, no persistent names, no favorite editing, and no scrolling policy. Extending it to 39 at the existing spacing needs ten rows and about 580 pt of height. That already exceeds the 560 pt demo stage.

Exact change: All pointers… closes and drains the radial gesture, then opens a separate key-capable browser. Start at 560 by 600 pt, with search, All/Favorites, seven columns of 64 by 72 pt cells, 8 pt gaps, 36 pt artwork, readable names, and a current-state check. Adapt columns and scroll on smaller displays. Search and keyboard navigation must work for the full enabled, available catalog, including unpinned and custom pointers. Disabled styles remain manageable through the existing settings path.

Selecting closes the browser. Escape cancels. A separate favorite control edits one of six dedicated Quick controls slots without selecting a pointer. Do not make this an expanding third level of the radial session.

## Prototype defects, ranked

P0 means a command or cancellation defect that blocks adoption. P1 means a required interaction is broken. P2 means visual, semantic, or review-evidence defects that still need correction. Command stubs are distinguished from implemented behavior below.

1. **P0. An outside click can execute Clear.** `hit()` has no persistent-mode outer bound, and the click handler immediately calls `commit()`. A handler probe at angle 135, radius 800 in click mode set `S.ink_on` from true to false. That was a direct state probe, not a physical click; the same unbounded hit test applies to reachable stage positions beyond the root rim. Root command sectors extending to the screen edge are a held-mode policy. Fix lines 196 to 211 and 243 to 245: persistent hit testing stops at the visible active ring. Outside click dismisses, consumes its input pair, and performs no command. Commit a persistent click on mouse-up after a matching press, with drag-away cancellation.

2. **P0. Keyboard navigation can execute disabled Redo.** Pointer hit testing clears `hlCell` for a disabled item, but keyboard cycling does not. `commit()` never checks the fan item's disabled flag. Entering More, pressing Up, then Left three times and Return decremented `S.redo` from zero to minus one and incremented Undo. Fix lines 207 to 208, 216 to 220, and 260 to 264: keep a focused item distinct from an eligible command, and revalidate every activation path at commit. A disabled item can receive explanatory focus and must never execute. With a disabled mouse target, commit must not fall through to the root parent.

3. **P0. Clamping changes the origin without arming.** `show()` clamps immediately, then the hold timer calls `hit()` at the real cursor relative to the displaced center. Invoking at a corner can begin with a command already eligible. There is no center-reset state. Fix lines 230 to 233 and 247: if relocation exceeds 8 pt, clear eligibility until the cursor enters radius 52. Show the real cursor and a visible route to the hub. Apply the same policy to children. No shrink, rotation, or pointer warp.

4. **P1. Escape does not implement its advertised contract.** At a click-mode root, Escape leaves `open=true`. In held mode inside a fan it only backs out, so release can still act afterward. Click mode also reopens 900 ms after closure. Fix lines 234 to 235 and 258: held Escape cancels the entire session; persistent Escape goes back one level and closes at root. Successful selection and cancellation stay closed. An optional demo reset must be an explicit control outside the interaction being reviewed.

5. **P1. All closes on the next movement where it was opened.** After choosing the All fan cell at angle 64.29, radius 193, the grid opens. Calling `hit()` again at that same position closes it because the cursor is outside the grid's 24 pt margin. The person must cross the very region that dismisses the grid to reach it. Fix lines 198 to 202 and 217: launch the separate persistent browser and remove radial hover-exit dismissal entirely.

6. **P1. The same endpoint changes meaning with hover history and event sampling.** Direct movement to angle 135, radius 190 yields Clear; visiting Draw first yields Number there. A first event at angle 45, radius 193 yields a Color preview; a second identical event yields Green. Fans also accept 10 degrees beyond their drawn edges, clamping that space onto the first or last item. Fix lines 203 to 210 with an explicit root/child state transition, navigation-only entry events, and one active level. Remove the invisible fan padding. If fans survive in another experiment, specify ownership, entry/exit hysteresis, and exact angular targets before comparing performance.

7. **P1. Disabled explanation works for root Undo but fails for fan Redo.** Hovering disabled Redo sets `hlCell=-1`, so the hub says More. Clicking returns "stay" by activating the parent branch. The item's identity and reason have been discarded. Fix lines 180 to 185, 208, and 221 to 223: retain the hovered disabled item as an inspection target, show "Redo / Nothing to redo", and keep the executable candidate empty. Use readable disabled text rather than fading the complete cell to 40 percent.

8. **P1. The no-hold path is not keyboard- or accessibility-complete.** Tab does not navigate sectors. The grid has no keyboard selection model; arrows continue changing the radial state behind it and Return cancels when `hlGrid=-1`. SVG groups and grid divs have no command roles, focus model, or accessible state. Fix lines 167 to 176, 192 to 193, and 257 to 264: real accessible command elements, stable identities, clockwise Tab/Shift-Tab and Left/Right navigation, explicit Back, and grid-specific spatial arrows. Native persistent mode must own and restore focus. A document-level key listener is not evidence that this works with VoiceOver.

9. **P1. The filled highlight reduces text contrast.** White tool labels in the Draw screenshot sit on the failing gradient described above. The 8 px ON/OFF badge and 10 px hub explanation also undershoot my 11 pt floor for necessary text. Fix lines 34, 40 to 63, 159, and 176: contrast-tested foreground/background pairs, 13 pt root labels, 12 pt child labels, and at least 11 pt state and explanation text. Preserve logical point sizes at every display scale.

10. **P2. The drawn hub and neutral region disagree.** The hub is drawn to radius 50, but root hit testing begins at 46. A probe at radius 48 west highlights Undo inside that drawn hub. Fix lines 182 and 204: use the acquisition and retention thresholds in the merged spec below. A release inside the hub must never select a command.

11. **P2. Preview copy omits the consequences that matter.** The fan-preview rendering branch only draws artwork and title. The later "Starts drawing" and "Current" copy is unreachable for an active leaf. More toggles do not show explicit On/Off states or pending results. "Off", "Mute", and "Settings" lose scope or the dialog-opening ellipsis. "Last stroke" is wrong when Undo would restore a clear or another edit. Fix lines 145 to 153 and 180 to 186: "Pointer off", "Mute all sounds", "Settings…", "Last change", full pending toggle actions, and "Starts drawing" when selecting a tool exits Interact. Wrap "Match the pointer" instead of cutting it to "Match the poin…".

12. **P2. Match makes Pointer and Color look identical at root.** Both show the current lavender hand in the Color screenshot. The accepted artwork treatment needs the linked ink chip as well. Fix `swatch()` and the root Color art in lines 138 to 142: keep a clear ink sample or stroke plus a small linked pointer cue. Give color choices visible names. Replace the coral current-item rings and tiny state dots with separate, two-tone check badges. The six defaults must include Cursor glove; the prototype silently substitutes Spotlight. The actual seed is Lavender, Glove, Coral, Plush, Robot, Laser in [PointerStyle.swift](../../../Sources/TinyHand/PointerStyle.swift), line 79. Store an explicit six-slot order rather than a live toolbar-pin projection.

13. **P2. The material and screenshot evidence need cleanup.** The fan is a nearly opaque SVG fill; `.fanglass` is declared but never instantiated. It does not share the root's backdrop treatment. The disabled-Undo screenshot also shows a pale, unsettled-looking menu and a rectangular coral region under Pointer while the hub names Undo. That image cannot serve as a clean disabled-state reference. Fix the material in the native implementation with one regular glass host for the active ring, then capture settled light/dark states. Regenerate the disabled reference from a neutral invocation and an actual disabled hover. Do not infer a native rendering defect from that single anomalous PNG.

The screenshot/save/settings/off actions are stubs, and the drawing/history counters are illustrative. The demo neither removes the drawn SVG ink on Clear nor restores it on Undo. That is an evidence limit, not a defect in `AnnotationDocument`. No screenshot here validates capture exclusion, real undo restoration, native focus, or event-pair draining.

## Round-1 requirements missing from the summary

These still belong in the implementation contract, even where an HTML sketch reasonably omits them.

- Session IDs, stale-release cancellation, cancellation on ordinary input during pending invocation, second-modifier cancellation, and input-pair draining. Do not replace the existing protected input layer with the prototype's pointer listeners. No pre-open flick recognition. Delete the dead `marking` branches and the misleading "A quick flick works too" teaching copy, or explicitly limit that phrase to post-open movement.
- Different held and persistent ownership policies. Only held directional targets extend to the owned display boundary. Crossing onto another display clears eligibility. Persistent outside clicks cancel. Held Escape always cancels everything. A held release over an unentered group does not silently convert to persistent mode.
- Edge arming, display ownership, cancellation on display removal or invalidated layout, no pointer warp or direction rotation, and a native list fallback below the required usable size. The prototype's width-based shrinking is not that policy.
- The real cursor marker and overlay-hand suppression. Keep the marker at the actual cursor, reserve space at the hub origin, and avoid a decorative hand plus system arrow plus selection dot. Support the enlarged system cursor and ordinary cursor use in persistent mode.
- Stable favorites, unavailable favorite placeholders with reasons, current unpinned-pointer visibility, and no automatic recency or toolbar-pin reshuffle. Adding favorites must not limit the full browser.
- Current state, pending action, and keyboard focus as three distinct signals. Draw must explain leaving Interact. Match must resolve to the current pointer's actual ink. Pointer off and Interact keep separate meanings.
- Availability updates in the new locations. Existing `updateHistory()` updates the History group only. Moving Undo and Clear to root requires updating those root items and More's Redo, while preserving their directions. Revalidate through the command bridge when committing.
- A key-capable persistent panel, accessible Back, ordinary menu-bar alternatives, prior-focus restoration, stable AX identities, and no swallowing VoiceOver's Control-Option commands.
- Reduce Transparency, Increase Contrast, Reduce Motion, readable opaque fallbacks, 1x/2x checks, and a larger-text list alternative. CSS blur and a manual Reduce Motion segment establish none of these native behaviors.
- Close the wheel, cursor feedback, and success feedback before screenshot capture. Report actual capture outcomes instead of unconditionally saying "Screenshot saved". Menu sounds default off and respect Mute all sounds; error information must outlast a 700 ms toast. Clear's Undo remains accessible after feedback vanishes.

## Merged implementation specification

**Eight 45-degree root sectors; one replacement child ring; 328 pt visible diameter in a 384 pt panel; child entry at 112 pt; acquisition at 72 pt; no turn or dwell gate; 180 ms held invocation and immediate persistent invocation.**

All dimensions are logical points. Angles run clockwise from north. Freeze catalogs, order, and command directions for a session; update availability and state without moving slots.

### Geometry and maps

- Hub radius 56. Ring from radius 64 to 164. Neutral cancel radius 52. Acquire a new target at 72; retain it down to 64, then clear. No executable candidate inside the drawn hub. Root icon/label groups start at radius 118, with 24 pt symbols and 32 pt pointer art. Child art is 32 pt, preview art up to 36 pt. Keep labels horizontal and check their actual frames at 1x and 2x.
- Root centers are 0 Pointer, 45 Color, 90 Draw, 135 Clear drawing, 180 Interact, 225 Screenshot, 270 Undo, 315 More. Interact has a stable label and separate On/Off badge.
- Pointer has eight 45-degree sectors: north Cursor glove, northeast Lavender toy, east Coral vinyl, southeast Plush, south Back, southwest Robot, west Laser dot, northwest All pointers…. These are dedicated favorites. The initial arrangement is explicitly saved and does not track later toolbar changes.
- Draw has eight 45-degree sectors: seven tools plus Back. Color has ten 36-degree sectors: the nine existing inks plus Back. More has seven sectors of exactly 360/7 degrees: Redo, Tap sound, Mute all sounds, Toolbar, Settings…, Pointer off, plus Back. No third radial level.
- For Draw, Color, and More, center Back on the reverse of that root group's fixed axis. Place the listed choices clockwise immediately after Back. This uses the category axis, not the user's incoming trajectory. Never squeeze out a disabled slot.
- Use 4-degree angular hysteresis on every active ring. Logical angular targets include the small visual separator gaps. A boundary with no previous target goes to the clockwise item. No invisible extension outside a drawn fan, because fans are removed.

### Navigation and commitment

- Held mode opens after 180 ms at the latest real pointer position. The first group-entry event at radius 112 opens the child at that event's cursor position and is navigation only. Discard its remaining travel. Only subsequent displacement of 72 pt from the child origin can acquire a leaf. Straight movement is allowed; turn threshold is zero and pause requirement is zero. Root is replaced immediately without animating a disc across the screen.
- Root group release before entry cancels the held session. Release in neutral cancels the whole session. Hover never changes the live pointer, drawing tool, ink, or sound. Release commits one validated, enabled leaf exactly once.
- In held mode, acquiring Back returns to the saved parent origin, consumes that event, and clears the candidate. Require entry into the parent's neutral radius 52 before another outward selection, so a distant return cannot reopen the same child immediately. Returning to the saved parent center can also go Back when parent and child origins are at least 104 pt apart; otherwise use the explicit Back target.
- Persistent hover only previews. A completed click on a group opens its child under that click position and consumes the click. A subsequent click chooses a leaf. Outside the active visible ring, a click dismisses. Keyboard or AX group entry uses an origin 112 pt along the group's fixed axis and focuses the child group without a default executable leaf. Pointer arming never blocks keyboard or AX operation.
- Held Escape cancels the entire session. Persistent Escape or Backspace returns one level, then closes at root. Tab/Shift-Tab and Left/Right cycle clockwise/counterclockwise. Return/Space opens or executes. Number keys 1 to 8 address root directions only while root is active. Browser arrows navigate the grid spatially.
- Held directional selection extends beyond the active ring to the invocation display's usable boundary. Another display is outside the session. Persistent targets stay inside the active visible ring. Finish ownership of every claimed key/button pair after closing.

### Edges, appearance, and feedback

- Inset the owned display's usable frame by 192 pt to place the panel. If root or child clamping moves its natural center by more than 8 pt, show a cursor-to-center cue and remain unarmed until radius 52 is entered. Do not move an already armed origin. Cancel if the display disappears or the layout becomes invalid. Use a native command list if either usable dimension is below 384 pt.
- Use one regular native glass host for the active ring, semantic text, warm cream/plum fallbacks, and the brand glove. No glass stacked on glass, ornamental bevel, footer, or screen-wide scrim. Filled command/tool selection uses contrast-tested on-selection colors; artwork and ink use tint plus a 2 pt arc. Current state gets a check, keyboard focus an outline, and disabled inspection a reason with no executable highlight.
- Root text 13 pt, child text 12 pt, explanations and badges at least 11 pt. Wrap names that fit two lines, including Match the pointer. Give longer custom names full browser and AX treatment. Keep the 20 by 20 pt origin reserve free of text when the cursor is neutral.
- Open with 120 ms ease-out, cubic 0.2,0,0,1, opacity and optional scale 0.98 to 1. Hover fill changes over 60 ms, hub content over 80 ms, and child replacement content over 100 ms. Dismiss over 80 ms. No bounce, nudge, sweep, or execution delay tied to visual settling.
- Reduce Motion removes scale and spatial interpolation: 80 ms opening opacity, immediate highlight/hub/child replacement, and immediate cancellation. Routine success feedback may last 1.2 seconds; errors remain discoverable. Screenshot capture waits for overlay removal from the captured scene and excludes all Quick controls feedback.
- All pointers… opens the separate 560 by 600 pt browser after ending and draining the radial session. Search receives focus. The seven-column grid adapts and scrolls. Escape cancels, Return selects, and a favorite-edit control never selects as a side effect.

## The three riskiest assumptions to test on Austin's Mac

1. **Reanchoring without the turn/pause gate is understandable and safe.** Use Austin's mouse and trackpad for first-use browsing and repeated Pointer/Color/Draw selections. Include straight fast strokes, turns, coalesced movement, release immediately after entry, overshoot, and Back. Record unintended leaves, cancellations, corrective travel, and completion time. Compare against the fan prototype with its defects repaired. If people cannot identify the active level before releasing, this hierarchy needs another design pass.

2. **Eight root choices improve real annotation work enough to justify narrower directions.** Run draw, Undo, Clear, restore-Clear, Screenshot, and Interact tasks with real artwork and labels. Compare the six-root map and eight-root map after equal practice. Include slips near Clear and a genuine multi-annotation Clear/Undo/Redo round trip. Check what Austin actually uses; the frequency argument is currently an assumption. The model's undoability does not eliminate interruption or embarrassment during a presentation.

3. **The compact native overlay remains operable under real display and accessibility conditions.** Try every corner, Dock/menu-bar edges, mixed Retina scales, multiple displays with negative coordinates, and display removal. Confirm the shifted-center cue is understood. Then complete the persistent keyboard and VoiceOver path through Back and the pointer browser, restoring prior focus. Check light/dark, Increase Contrast, Reduce Transparency, Reduce Motion, and enlarged cursor over bright slides and busy imagery. These are properties of the native panel and input layer, not conclusions available from the HTML screenshots.

Run those checks locally. Keep hosted CI disabled. This is my proposed implementation contract. The native runtime checks remain unverified.
