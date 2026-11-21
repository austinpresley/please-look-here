# Native usability review, round 1

18 November 2026. Branch `feature/usability-rethink-icons`, including its uncommitted work.

**Overall: 83/100. Verdict: revise.**

The redesign is substantially easier to use. Cursor replaces the confusing Interact contract, favorite hands replace the dropdown, the toolbar stops changing shape, and Pointers finally puts selection and editing together. The native implementation follows most of the approved design's structure. It does not yet meet the brief consistently: a few icons hide meaning, Shortcuts retains much of the old density and copy, and a new dark-mode status label has poor contrast.

## Scores

Scores cover usability, fidelity to the approved intent, copy, icon meaning, consistency, native layout, both appearances, accessibility plausibility and preservation of capabilities. The overall score is the rounded equal-weight mean, 83.4.

| Area | Score / 100 | Assessment |
| --- | ---: | --- |
| Menu popover | 88 | Much clearer tool and pointer choices. Good persistent history controls and pending-permission treatment. Some duplicated status copy remains. |
| Floating toolbar | 88 | Strong improvement. One stable row and a real picker. Sparse favorites leave space deliberately, as required for eight favorites. |
| Quick controls wheel | 91 | The most faithful implementation. Current-hand hub and checked Cursor/Draw preserve the learned wheel layout. |
| Welcome and practice | 76 | Welcome teaches more with fewer words. Practice still has weak progress semantics and excessive unused space. |
| Pointers | 83 | The inline inspector and independent resets are excellent. Shadow's icon is misleading; some names and secondary actions are harder to discover than before. |
| Tools | 84 | Behavior pictures, practice, width chips and labeled tabs work well. Old explanatory copy and loose form spacing dilute the simpler design. |
| Shortcuts | 72 | Useful reversible suggestions and keycaps. The held-key instruction is missing, and the expanded list still looks like the old form. |
| Presets and backup | 82 | Picture cards, durable Undo and restore review are real gains. Selection versus Now needs clearer treatment, and Now has insufficient dark contrast. |
| General | 78 | Five-page navigation is simpler. General has become an unnecessarily long combination of settings and About. |
| Gesture art in-app | 92 | The sampled lavender, pixel and robot poses retain their materials, read as different gestures, and fit their rods without visible clipping or double composition. |

## Evidence and limits

The approved references are `README.md`, `index.html` and `review-sol-r1.md` through `review-sol-r4.md` in this directory. I rendered all eight current HTML sections at 1100 CSS pixels in light and dark using the supplied Playwright Core and Chrome. Screenshots stayed in memory. No page errors were observed. I compared those renders and the existing section captures with the native windows and before-captures.

Paths below use these prefixes:

- `B2` = `dist/verification/usability-icons-phaseB2C/`, the latest popover, toolbar, wheel, welcome, practice, Tools, Shortcuts, Presets and gesture evidence.
- `B1` = `dist/verification/usability-icons-phaseB1/`, used for General and additional Pointers states not recaptured in B2.
- `Before` = `design/usability-icons-2026-11-18/before/`.
- `Sources` = `Sources/TinyHand/`.

I also read the Phase A, B1 and B2/C entries in `docs/VALIDATION.md`, `docs/INTEGRATION.md`, the gesture handoff, layout exports and relevant view code. The recorded build is 1.2.0, build 20261118195702. Test and packaging results in those documents are implementation evidence, not checks rerun by this reviewer.

This was a read-only review apart from this file. No app launch, real preferences, native input, live-smoke, build, test run, delegation or commit. Static images and source inspection support an accessibility plausibility assessment, not a VoiceOver pass. Native popup menus, real desktop drawing, capture, sound and physical shortcut operation remain unverified here. Native gesture evidence samples three materials, not all 36 hands.

## P0 findings

None found in the reviewed evidence.

## P1 findings

### R1-P1-01: Suggested does not teach that Quick controls requires a hold

Evidence: `B2/shortcuts-default-light.png`, `B2/shortcuts-default-dark.png`, `B2/shortcuts-added-dark.png`; `Sources/SuggestedShortcuts.swift`, `Assignment.display`; `Sources/ShortcutsSettings.swift`, `suggestedCard`.

The row shows Quick controls, a status and a lone Option symbol. The approved mock explicitly says "hold". This is a different interaction from the neighboring key chords, but the native row presents all assignments alike. `Assignment.display` reduces a hold to the last symbol of its title, and the keycap accessibility label receives only that symbol. A new user can tap Option and conclude the feature does not work.

Fix: show **Hold Option** with the Option keycap. Give the assignment an accessibility label such as "Hold Option to open Quick controls". Preserve the supported single-modifier trigger and the existing conflict and Undo behavior. Do not put this instruction only inside the collapsed Quick controls group.

### R1-P1-02: The Shadow switch uses the wrong visual meaning

Evidence: `B2/pointers-lavender-gestures-light.png`, `B2/pointers-pixel-gestures-dark.png`, `B1/pointers-defaults-light.png`; compare `B2/popover-cursor-light.png` and `Before/customize-light.png`. Source: `Sources/PointerCustomization.swift`, the Shadow row.

The inspector represents Shadow with an ordinary filled pointing hand. Elsewhere a hand beside a switch means show or hide the pointer. These two controls do different things but look like the same concept. The old customization sheet named Shadow plainly. The new tooltip and accessibility name help after discovery; they do not make the visible icon understandable.

This ambiguity also exists in the approved mock. Faithfully carrying it over does not satisfy the owner's request for understandable icons.

Fix: use an actual cast-shadow illustration, or retain the short visible label **Shadow** beside its switch. Keep the separate shadow-style row, per-value override indicator and reset.

### R1-P1-03: Now is hard to read in dark mode

Evidence: `B2/presets-cards-dark.png`, `B2/presets-included-dark.png`; `Sources/PresetsSettings.swift`, `presetCard`.

The current-preset label uses 11-point accent-blue text on an accent-tinted dark card. In `presets-included-dark.png`, fully covered text pixels are RGB `0,122,255`, and the adjacent card background is `45,57,70`. Their sRGB contrast is approximately **2.93:1**. This is status text, not a disabled control. The checkmark helps identify the state but does not repair the text contrast.

Fix: render Now with primary text and retain the accent checkmark, or use an appearance-aware foreground that reaches at least 4.5:1 on the actual card background. Check both appearances and customized accent colors. Apple's [accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility) recommends contrast checks; [WCAG 2.2](https://www.w3.org/TR/2023/REC-WCAG22-20231005/#contrast-minimum) specifies 4.5:1 for ordinary text.

## P2 findings

### R1-P2-01: Shortcuts adds a new card without simplifying the old list

Evidence: `B2/shortcuts-default-light.png`, `B2/shortcuts-expanded-light.png`, `B2/shortcuts-recording-dark.png`; compare `Before/shortcuts-light.png` and approved section 05. Sources: `Sources/ShortcutsSettings.swift`, `Sources/SettingsComponents.swift`, `Row` and `SettingsDisclosure`.

Closed groups consume about 56 points each plus gaps. After Suggested, expanding Pointer occupies almost the entire remaining 1054-pixel capture. Every unassigned command also has an "Unassigned" field and a disabled Clear button. The mock's tighter rows and single clear affordance were not carried through.

Leftover copy includes "Global. Works with the pointer off.", "Hold while an available hand is on.", "Current pointer only. App mute still applies.", and the full paragraph beginning "Click a field and press keys. Escape cancels." Suggested also repeats "Already set" on three rows after applying.

Fix: use compact command rows around 32 to 36 points, compact group headers, and a single trailing recorder with an assigned-only clear affordance. Move scope explanations to help or one group note. Teach "Press keys; Esc cancels" when recording. Keep the visible result and Undo. Preserve all 26 commands and conflict details.

### R1-P2-02: Practice wastes space and weakens progress information

Evidence: `B2/practice-light.png`, `B2/practice-dark.png`; compare approved section 07 and `Before/practice-light.png`. Sources: `Sources/GettingStartedPracticeWindow.swift`, `Sources/UsabilityGlyph.swift`.

The canvas ends around y343, then history and two small help controls occupy separate rows. Roughly 160 pixels of empty space follow before the footer. The available space should support the exercise. The progress strip also has no completed-step checkmarks or visible step count. `PracticeStepGlyph` hides its image from accessibility, while the enclosing construction supplies no explicit current-step value or selected trait. The old "Step 4 of 4" supplied progress in words.

Fix: put Undo and Clear in the canvas header, group help beside the exercise title, and let the canvas grow or the window shrink. Show completion checks. Expose one reliable progress announcement such as "Step 2 of 4, Drawing" and mark the current step. Keep the initially empty canvas and disabled Next until a real local completion.

### R1-P2-03: Gesture shortcuts use the same unrelated icon twice

Evidence: `B2/shortcuts-recording-dark.png` versus `B2/pointers-pixel-gestures-dark.png` and `B2/pointers-lavender-gestures-light.png`. Source: `Sources/ShortcutsSettings.swift`, `commandSymbol`.

Hold Gesture 1 and Hold Gesture 2 both use `hand.thumbsup`. Neither action is a thumbs-up. Pointers correctly shows OK and Shaka. Quick controls also changes from the custom wheel in welcome and practice to a hexagonal cluster in Shortcuts.

Fix: use distinct OK and Shaka silhouettes for the two shortcut commands, with matching accessible names. Reuse `UsabilityGlyph.wheel` wherever Quick controls is identified. The bundled per-hand artwork should remain in the inspector; the shortcut list only needs clear pose silhouettes.

### R1-P2-04: Preset selection and current state share a visual signal

Evidence: `B2/presets-cards-light.png`, `B2/presets-cards-dark.png`. Source: `Sources/PresetsSettings.swift`, `presetCard`.

Quiet demo has a blue outline while Workshop has a blue outline and Now. Both also offer Apply, including the preset already in use. This is defensible as two states, but unnecessarily subtle for a redesign intended to reduce interpretation. The Save current card is also taller than the preset cards; their top and bottom edges do not align in the light capture.

Fix: reserve the accent treatment and checkmark for the current setup. Use a neutral selection or focus treatment for browsing. Disable or replace Apply on an exact current match. Give saved cards and Save current the same outer height and aligned action baseline.

### R1-P2-05: Backup reviews still expose too much structure and too little identity

Evidence: `B2/presets-import-review-light.png`, `B2/presets-import-review-dark.png`, `B2/presets-restore-review-light.png`, `B2/presets-restore-review-dark.png`. Source: `Sources/PresetsSettings.swift`, import and restore preview views.

Import does not name the selected backup. A one-setting change is followed by separate New hands, New artwork and New presets sections saying None, then an unchanged six-line toolbar list. Important replacement information competes with unchanged inventory. Restore names only "Saved presets" when that file changes, without saying which presets disappear or return.

Fix: put the backup filename in the import heading, show changes first, and collapse unchanged inventory into Details. Summarize preset changes by count and name in restore review. Keep the persistent recovery-copy promise and the explanation of settings that stay local. The new review step resolves the existence of the round-4 restore omission, but its precision can improve.

### R1-P2-06: General is longer than its task requires

Evidence: `B1/settings-general-light.png`, `B1/settings-general-dark.png`; compare `Before/general-light.png`. Source: `Sources/SettingsPages.swift`, `GeneralPage`.

The earlier General capture was 568 pixels tall; this one is 972. About, attribution, repository links, notices and build information now sit between settings and Reset All Settings. Keeping five destinations is sensible, but it should not make a routine settings page a long credits page. "Set up access, startup and app appearance." repeats its contents.

Fix: remove the introductory sentence and put About, attribution and legal links in an About disclosure or standard About panel. Keep permissions, startup, appearance, Practice and Reset easy to scan. Shorten permission detail to "Drawing and Quick controls" and "Capture and magnifier". Do not treat "Updates are not set up in this build" as a release regression; this is a review-build state.

### R1-P2-07: Tools retains avoidable prose and duplicate explanations

Evidence: `B2/tools-ink-fade-light.png`, `B2/tools-ink-advanced-light.png`, `B2/tools-magnifier-dark.png`, `B2/tools-capture-light.png`. Source: `Sources/SettingsPages.swift` and the drawing settings views.

"Set up drawing, magnification and capture." repeats the three tabs. Magnifier explains toolbar/menu invocation above a separate permission status. Capture retains "Captures include the display, pointer and annotations. Capture the full display or choose a region from the toolbar, menu or a shortcut." The advanced Smoothing row retains "The end of a line stays at the pointer." These are specific leftovers from the more verbose form.

Fix: remove the tab summary, put invocation instructions in help, and shorten capture guidance to "Includes pointer and ink. Choose Full Display or Region when capturing." Keep the short Color, Line width and Opacity labels. Retain the behavioral distinction between whole-mark fade and Trail, but express it once beside the selected behavior or preview.

### R1-P2-08: Pointers loses some readability and action discovery

Evidence: `B1/pointers-favorites8-light.png`, `B1/pointers-missing-artwork-light.png`, `B2/pointers-lavender-gestures-light.png`; compare `Before/appearance-dark.png`. Sources: `Sources/PointerLibrary.swift`, `Sources/PointersSettingsPage.swift`, `Sources/PointerPreview.swift`.

The library uses 10-point, single-line names, producing truncated labels such as Presentation and Missing artwork in the constrained cards. "8 is the most" is an awkward replacement for the otherwise consistent capacity count. Preview Motion also moved from a visible button into the tap-preview button's context menu, but its hover help only says "Preview a tap in this sample". That capability survives in code but has become difficult to discover.

Fix: allow two-line names at 11 points, keep full accessible names, and use "8 of 8" at capacity. Give the preview an explicit Tap/Motion menu or a small menu indicator with help naming both actions. Also change "Inspect" accessibility labels to disclose that choosing an available hand makes it current; `SettingsModel.inspectPointer` performs that change.

### R1-P2-09: The permission popover repeats the same warning

Evidence: `B2/popover-permission-light.png`, `B2/popover-permission-dark.png`; compare approved section 01. Source: `Sources/MenuBarControls.swift`.

"Drawing needs access" appears in the banner and again in the footer, below the tools and colors. The mock puts the permission explanation before the tool choice and uses the second line to explain the retained selection. Native selection retention is useful, but the copy does not explain it as directly.

Fix: put the access banner before the tool row and make the footer "Pen kept for later" or "Pen · Waiting for access". Preserve the dashed pending outline, enabled Cursor route, editable choices while hidden, and visible Undo/Redo/Clear.

## Excellent work to keep

- Cursor, the independent Show pointer switch, direct favorite artwork and persistent history controls remove the old Interact ambiguity. The native label "Show pointer" is worth its few words.
- The 632 by 48-point toolbar and 284-point context allocation keep shared buttons stationary. The exported Cursor and Pen layouts agree. Do not shrink that space based on the current favorite count.
- The wheel retains its established directions, Pointer and Color entry points, disabled history feedback and explanatory labels. Its neutral hand hub and checked Cursor/Draw are effective improvements.
- This/Defaults is a meaningful editing boundary. The Defaults Sample, separate per-field resets, hidden/missing entries and distinct Laser, Spotlight and Presentation artwork address the mock's most important implementation notes.
- Tools combines real practice, recognizable stroke behavior pictures, width examples, nine ink choices including Match pointer and white, and reachable advanced settings. Labeled native tabs are a good adaptation of the web mock.
- Suggested is opt-in and reversible. The recorded result, existing assignments and explicit skipped screenshot proposal are more trustworthy than silently installing defaults.
- Presets keeps selection separate from applying, provides durable Undo, and now reviews recovery restoration before replacing data. Inclusion text explicitly covers custom hand and gesture artwork and local-only settings.
- The lavender, pixel and robot OK/Shaka tiles and preview pairs retain their material identities. The sampled previews show one rod, stable attachment and no clipped fingers. Keep direct full-canvas loading and the documented custom-artwork precedence.

## Preservation and accessibility assessment

No confirmed lost command was found. Quit and the fuller commands menu remain in `Sources/MenuBarCommands.swift`; the old popover's More affordance is replaced by the status item's right-click commands route. Magnifier and Capture settings remain present. Non-hand sound/effects and Preview Motion remain in code, although their disclosure is less obvious. Existing stored IDs, six wheel directions, eight toolbar favorites, shortcut assignments and backup encodings are documented as preserved.

The implementation supplies help and accessibility names for most new icon controls, native recorders, reset descriptions and distinct audible/pointer-muted/app-muted values in quick-entry code. That is a credible foundation. It does not prove keyboard traversal, announcements or VoiceOver navigation. The missing hold instruction, progress semantics, misleading Inspect action names and dark Now contrast deserve correction without adding a new page of explanatory text.

## Verdict

**Revise.** Fix the three P1 issues before approval. The remaining work is targeted wording, icon meaning, contrast and layout polish. Preserve the redesigned structure and the per-hand artwork.
