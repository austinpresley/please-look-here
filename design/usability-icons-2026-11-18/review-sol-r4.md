# Usability and icons review, Sol round 4

**Overall: 89/100. Verdict: approve-with-notes.**

The three round 3 blockers are corrected at proposal level. Defaults has a trustworthy scope boundary, Presentation is recognizable as a rod, and Suggested uses an assignable wheel trigger. The proposal makes the main choices easier to recognize while keeping text short. The remaining inconsistencies deserve cleanup during implementation, but do not justify another design round.

## Evidence

Read `review-sol-r3.md` first, compared the current HTML with `r3/index-r3.html`, and rendered the archived Defaults and Presentation states for direct comparison. Used the supplied `playwright-core` installation and Chrome executable. Followed `parts.cjs`'s section-capture approach with screenshots kept in memory, and ran `t4.cjs` unchanged.

Rendered and visually inspected all eight current sections at **1100, 728 and 390 CSS pixels, in light and dark**. Repeated the Defaults transitions, all three non-hand selections, Presentation favoriting, keyboard range changes and practice Clear across all six combinations. Current-page checks found no page/console errors or broken images. Document width stayed within the viewport. At 390 px, all five horizontal mock containers reached their right edge and showed a scroll cue, including Shortcuts.

Checked `RadialTrigger`, `RadialCatalog`, `PointerStyle` and the glossary against the claims. This is proposal evidence, not native accessibility or release verification. No app launch, live-smoke, native input, delegation, build, commit or hosted CI occurred. This review is the only authored file created.

## Round 3 P1 status

| Finding | Status | Verified result |
| --- | --- | --- |
| R3-P1-01, Defaults scope | Resolved | Defaults retains **Pointer defaults**, labels its preview **Sample**, hides the inspector favorite, More and gesture controls, and shows both shared shadow rows. Entering from Presentation, Spotlight or Laser gives the same global policy. Selecting Cursor glove or another library entry explicitly selects **This**, restores the local title and controls, and shows local values. Returning from Defaults to Presentation restores the rod state. |
| R3-P1-02, Presentation identity | Resolved at proposal level | Library, added favorite and large inspector preview use `#i-rod`, with a dark grip, gray shaft and `#EE6B61` tip. Spotlight retains its circle; Laser retains its dot. All three hide the inapplicable shadow and gesture rows. The miniature This and size artwork still need the P2 correction below. |
| R3-P1-03, supported suggestion | Resolved | Suggested now shows **hold Option**, which `RadialTrigger` supports. Add 2, Already set, skipped Screenshot and the reversible result still agree. The example/conflict-check qualification remains visible. |

**Remaining P0: none. Remaining P1: none.**

The smaller fixes are also visible: correct wheel positions with Back south and All pointers northwest, theme-aware destructive text, explicit gesture-artwork/window-position backup boundaries, three recovery copies, the restore safety-copy note, a first-run **Set key** button, and the idempotent Cursor contract. Keyboard changes now show matching volume, smoothing and tail-speed labels. Clear removes the practice sample.

## P2 notes

| ID | Remaining issue and next step |
| --- | --- |
| R4-P2-01 | Non-hand selection leaves the previous hand in the **This** tab, while the size row always shows lavender hands and a generic percentage. Reproduced after Cursor glove → Presentation, Spotlight and Laser. Use each type's artwork and explain radius/thickness where applicable. See `index.html:680`, `index.html:684` and `index.html:1165`. |
| R4-P2-02 | Tail speed and smoothing now update their labels, but do not affect the drawing simulation. Trail still filters points by age and Replay uses fixed timing. Connect those controls or mark the preview as illustrative before treating it as behavioral evidence. See `index.html:1197` and `index.html:1208`. |
| R4-P2-03 | The wheel map is corrected, but **Wheel direction** still stops before the named submenu. Specify the selected slot, swap outcome and disabled/unavailable saved assignment. A small static frame is enough. See `index.html:716`. |
| R4-P2-04 | Popover tap-sound help and Match pointer help are useful additions. Toolbar equivalents still lack hover help, and quick controls do not depict pointer-muted versus app-muted output. Carry the same vocabulary and distinct states into those entry points. See `index.html:556`, `index.html:579` and `index.html:595`. |
| R4-P2-05 | Three recovery entries and a new safety copy establish a credible escape route. **Restore…** still lacks a review identifying what will be replaced and what local settings survive. Add that scope to the eventual restore sheet. See `index.html:975`. |
| R4-P2-06 | Keep an equal-scale Pointers editing comparison for handoff. The overview still compares three small before windows with one much larger after window. Small muted menu annotations and the fixed-green Already set text also need stronger dark-mode contrast. |

Closed shortcut-group contents, Magnifier/Capture contents, capture-progress/rejected-selection frames and the remaining first-run lessons are accepted proposal omissions. Preserve those capabilities and states in the implementation handoff; this approval does not claim they were demonstrated.

## Verdict

**Approve-with-notes. No blockers.** The proposal answers the owner's brief well enough to proceed. Keep the P2 notes attached to implementation, especially the non-hand miniature controls and the limits of the practice preview.
