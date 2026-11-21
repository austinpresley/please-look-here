# Native usability review, round 2

18 November 2026. Branch `feature/usability-rethink-icons`, including its uncommitted work.

**Overall: 91/100. Verdict: approve-with-notes. No P0 or P1 design blockers.**

All 12 round 1 design findings are resolved in the reviewed captures and supporting source. This now meets the owner's intent. The main controls teach Cursor versus drawing, favorites are direct choices, and the inspector makes customization manageable without another window. The fixes improve clarity without adding explanatory paragraphs. One P2 remains in Suggested when an existing assignment differs from the proposed keys.

## Scores

The rubric and equal weighting are unchanged from round 1. Scores cover usability, approved design intent, copy, icon meaning, consistency, native layout, both appearances, accessibility plausibility and preservation of capabilities. The mean is 91.2, rounded to 91.

| Area | Round 1 | Round 2 | Assessment |
| --- | ---: | ---: | --- |
| Menu popover | 88 | 93 | The access warning precedes the tool choice, and the footer explains the retained tool. Show pointer, direct favorites and persistent history make the hierarchy easy to scan. |
| Floating toolbar | 88 | 91 | Stable shared-button positions, a recognizable current-tool picker and separate pointer visibility remain strong. The fix record addresses the picker visibility failure; this review does not independently exercise proximity behavior. |
| Quick controls wheel | 91 | 91 | Still the strongest match to the approved intent. The current-hand hub, checked Cursor/Draw and established directions remain clear in both appearances. No score increase for unchanged work. |
| Welcome and practice | 76 | 91 | Held-key wording, a useful canvas, grouped history/help, completion checks and visible step counts repair the teaching flow. The real exercise begins empty and gates Next on local completion. |
| Pointers | 83 | 92 | Shadow is named, long names wrap, capacity is clear, and Tap/Motion has a visible menu affordance. This/Defaults and independent reset indicators remain legible. Non-hand previews have distinct artwork and size terminology. |
| Tools | 84 | 91 | The behavior pictures and local preview carry the explanation. Removed introductory prose and shorter Capture guidance make the three native tabs easier to scan. Advanced controls remain available. |
| Shortcuts | 72 | 88 | Compact rows, assigned-only Clear, distinct OK/Shaka art and recording-time instructions are substantial improvements. Suggested still needs to distinguish proposed keys from existing custom assignments. |
| Presets and backup | 82 | 92 | Current and browsed cards are distinct, current Apply is disabled, and card heights align. Import names its file and leads with changes. Restore names the affected preset. Now passes the actual pixel contrast checks. |
| General | 78 | 91 | Routine settings fit a 640-pixel capture with About closed. Permission descriptions are short, Practice stays visible, and credits no longer interrupt routine settings. |
| Gesture art in-app | 92 | 92 | Lavender, pixel and robot OK/Shaka previews retain their materials, distinct silhouettes and rod attachment. No visible clipping or duplicate rod in the reviewed samples. This remains a sampled visual assessment. |

## Round 1 finding status

`F` means `dist/verification/usability-icons-fix1/`. Capture stems below refer to both `-light.png` and `-dark.png` unless specified. Status is based on the images and relevant source, not the implementation's statement that everything is fixed.

| Finding | Status | Verification |
| --- | --- | --- |
| R1-P1-01: Quick controls does not teach hold | Fixed | `F/shortcuts-default` and `shortcuts-added` visibly say Hold beside the Option keycap. `SuggestedShortcuts.Assignment.accessibilityLabel` supplies the full held-key action. Welcome and the local wheel lesson repeat the hold instruction. The separate configured-key ambiguity is R2-P2-01 below. |
| R1-P1-02: Shadow uses the wrong visual meaning | Fixed | `F/pointers-this-overrides` and `pointers-defaults` show a layer symbol and the visible word Shadow. The style row, override dot and independent resets remain. The ordinary hand no longer has to explain Shadow. |
| R1-P1-03: Now has poor dark contrast | Fixed | `F/presets-cards`, `presets-included` and all eight accent captures show primary Now text with a separate accent checkmark. Independent sampling of the recorded text/background pixels reproduces 8.97:1 dark, 11.93:1 light and a 7.89:1 minimum across the accent checks. |
| R1-P2-01: Shortcuts retains the old density and prose | Fixed | `F/shortcuts-expanded`, `shortcuts-pointer` and `shortcuts-recording` show compact command rows and headers. Only assigned rows have Clear. Scope paragraphs have moved to help, and the fitted recorder says Press keys; Esc cancels. Source retains the 26-command list and conflict handling. |
| R1-P2-02: Practice wastes space and lacks progress semantics | Fixed | `F/practice`, `practice-progress`, `practice-completed` and `practice-wheel` show a 300-point drawing canvas, history in its header, help beside the title, completion checks and an explicit step count. Source supplies the current-step announcement and selected trait. The empty drawing capture has Next disabled; the completed capture enables it. |
| R1-P2-03: Gesture shortcuts share an unrelated icon | Fixed | `F/shortcuts-pointer` and `shortcuts-recording` show distinct real OK/Shaka thumbnails and named commands. `ShortcutGestureArtwork` supplies generic pose artwork for non-hand selections. Suggested and the Quick controls group reuse the wheel glyph. |
| R1-P2-04: Browsed and current presets share a signal | Fixed | `F/presets-cards` gives browsing a neutral outline and reserves accent fill, accent outline and Now for the current match. Its Apply is disabled. Save current and saved cards have equal 176-point outer heights and aligned edges. |
| R1-P2-05: Backup reviews lack identity and emphasize inventory | Fixed | `F/presets-import-review` names Workshop Backup.json and leads with the changed stroke width. Unchanged inventory is behind Details in `presets-import-details`. `presets-restore-review` says Remove 1 and names Workshop. The recovery-copy promise and local-only exclusions remain visible. |
| R1-P2-06: General is unnecessarily long | Fixed | `F/settings-general` removes the introduction, shortens both permission descriptions and collapses About. `general-about` preserves credits and legal links on demand. The expanded credits view being longer is appropriate. |
| R1-P2-07: Tools repeats avoidable prose | Fixed | `F/tools-ink-advanced`, `tools-magnifier` and `tools-capture` remove the tab summary, invocation paragraph and smoothing explanation. Capture uses the requested short guidance. The preview expresses the active fade/trail behavior once, while Color, Line width and Opacity remain named. |
| R1-P2-08: Pointer names and secondary actions are hard to discover | Fixed | `F/pointers-favorites8` shows Presentation pointer on two lines and 8 of 8. `pointers-missing-artwork` wraps its full name. The preview has a play/menu chevron, with Tap and Motion named in help and accessibility. Library and favorite actions now say Use and inspect when choosing also makes a pointer current. |
| R1-P2-09: Permission warning is duplicated | Fixed | `F/popover-permission` puts Drawing needs access before the tools and Pen kept for later in the footer. The pending tool keeps its dashed outline, Cursor remains available, and history stays visible. Hidden-pointer captures retain editable choices. |

## Remaining findings

### P0

None found in this design review.

### P1

None found in this design review. The three original P1 issues are closed.

### R2-P2-01: Suggested displays proposal keys for an already assigned command

Evidence: `F/shortcuts-added-light.png`, `F/shortcuts-added-dark.png`; `Sources/TinyHand/ShortcutsSettings.swift:63`, `:66`, `:67`, `:68`; `Sources/TinyHand/SuggestedShortcuts.swift:36`, `:44`, `:49`.

Suggested hides the Already set status, but always renders the template assignment and its accessibility instruction. Assignment detection only checks whether a stored value exists. It does not require that value to match the proposal.

For example, with Control configured as the held trigger, the Suggested Quick controls row still shows Hold Option and announces Hold Option to open Quick controls. A custom Pointer shortcut has the same problem. Add correctly preserves the existing assignment, so following the displayed keys can fail even after using Suggested. The supplied fixtures use assignments matching the proposals and therefore do not expose the mismatch. This edge case is established by source tracing, not a new native capture or a physical-input test.

Fix: for an already assigned command, show its actual stored assignment and derive the visible Hold instruction and accessibility label from it. A short Current label can distinguish it from a Will add proposal. For an occupied value that cannot be decoded, show Already assigned without inventing a key. Keep the current no-overwrite behavior. Verify one non-Option held trigger and one custom Pointer chord whose keys differ from the suggestions.

This is non-blocking for the design approval. The default proposals work, the full shortcut controls expose the stored assignments, and Welcome/practice derive their held-key instruction from the actual trigger. It should still be corrected because Suggested currently looks like a reliable shortcut reference.

## Evidence and limits

I read both round 1 reviews, the fix-round entry beginning near line 4015 of `docs/VALIDATION.md`, `findings.json`, `validation.json`, `contrast.json` and relevant view/model code. I independently hashed all 200 files in `F/source-manifest.json`; every hash matches the current checkout. The reviewed captures belong to review build 1.2.0, build 20261118205305.

I rendered all eight approved HTML sections in light and dark at 1100 CSS pixels using `/private/tmp/lhp-usability-tools/node_modules/playwright-core` and `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`. There were no page errors. Mock screenshots and native inspection crops stayed in memory. I opened the updated native entry controls, welcome states, practice progress, five Settings destinations, advanced Tools, backup reviews, non-hand inspectors and sampled gesture previews in both appearances. Existing evidence was sufficient; no new app launch or native capture was needed.

For contrast, I decoded the actual PNGs into an sRGB browser canvas, independently read the foreground/background pixels listed in `contrast.json`, and recomputed relative luminance. The results match the record, including all red, yellow, green and purple variants. The sampled dark Now pixels are RGB 223, 225, 227 over 45, 57, 70. This verifies that text, not every color combination or control in the app.

The recorded three full local test passes and code-review fixes are supporting implementation evidence, not tests rerun or a replacement code-review verdict from this grader. Accessibility findings here cover visible contrast and source plausibility. Physical shortcuts, live drawing/capture/audio, VoiceOver navigation and macOS 13 runtime checks are outside this review. Native gesture previews cover three materials and both poses, not a visual inspection of all 72 bundled assets.

This review created only this file. No source edits, commits, delegation, live-smoke, native input posting, real-preference changes, build, test run or hosted CI.

## Verdict

**Approve-with-notes, 91/100.** All original design findings are resolved. One non-blocking P2 remains in Suggested's representation of custom assignments. No design blocker remains within the agreed review scope.
