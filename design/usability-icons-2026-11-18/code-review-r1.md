# Icon-first implementation review, round 1

Verdict: **request-changes**.

Reviewed the uncommitted implementation on `feature/usability-rethink-icons` against HEAD, using the three phase file manifests, the design README, and the phase entries in `docs/INTEGRATION.md` and `docs/VALIDATION.md`. Untracked implementation files were read directly. Findings below concern the icon redesign or integration gaps created by its new behavior. No source edits, commits, delegation, build-review, live-smoke, or native input posting were performed. Product failure scenarios below are established by source tracing, not a live UI smoke test.

## P0

None found.

## P1

### 1. The toolbar hides itself while the user enters its new tool picker

Location: `Sources/TinyHand/Toolbar.swift:243`, `Sources/TinyHand/Toolbar.swift:299`; visibility predicate at `Sources/TinyHand/OverlayController.swift:924`.

After the initial three-second reveal expires, open the drawing-tool picker on the default bottom toolbar and move toward the upper row containing Pen, Highlighter, Rectangle and Arrow. The picker opens above its button and contains two 28-point rows, spacing and padding. That upper row extends beyond the toolbar's 32-point vertical proximity margin. `updateToolbarVisibility` considers only the toolbar frame, so the next service tick calls `setRevealed(false)`, which explicitly closes the picker before the user can select that row. Opening the popover does not renew `revealUntil` or hold a visibility lease. The permission variant is taller still.

Fix: keep the toolbar revealed while its picker is shown, or include the popover window and the travel corridor in the proximity calculation. Retain explicit dismissal on pointer-off, toolbar-off and capture. Test the visibility decision with an expired reveal deadline and points inside both picker rows, rather than only taking a picker screenshot.

### 2. Restore Artwork creates user artwork that Export Backup silently omits

Location: `Sources/TinyHand/PointerArtworkRecovery.swift:10`, `Sources/TinyHand/PointerArtworkRecovery.swift:18`; incompatible export and archive rules at `Sources/TinyHand/PresentationStore.swift:170` and `Sources/TinyHand/PresentationArchive.swift:206`.

Choose Restore Artwork for Lavender and supply a replacement PNG. The new feature writes `Hands/hand_lavender.png`, which the normal asset lookup prefers over the shipped image. Export Backup succeeds, but `captureArchive` includes base PNGs only for manifest-owned custom hands. Built-in hands contribute gesture files only. The archive path validator would also reject `hand_lavender.png`. Restoring that apparently complete backup on another Mac, or after losing the Hands directory, loses the user's replacement artwork and shows the stock hand. The local `.ArtworkRecovery` folder is omitted too.

Fix: make locally replaced built-in base artwork portable through a validated canonical mapping, including import conflict checks and recovery support. Alternatively, constrain this action to restoring shipped bytes and provide arbitrary replacement as a custom hand that the existing backup supports. Add an export/import round trip with a visibly different built-in replacement and verify its actual bytes. A test of the inclusion-list strings cannot catch this loss.

## P2

### 3. Suggested Undo also rolls back later, unrelated shortcut edits

Location: `Sources/TinyHand/SuggestedShortcuts.swift:67` and `Sources/TinyHand/SuggestedShortcuts.swift:80`.

Apply Suggested, then assign a Pen shortcut in the full list, then click the Suggested result's Undo. The receipt snapshots every shortcut and `radialTrigger`; Undo rewrites every one of those keys without checking which ones Suggested changed or whether they changed again. The new Pen assignment disappears even though Suggested never touched Pen. The same operation can overwrite a later edit to a previously occupied command. The result row remains available while these edits are made.

Fix: record exact before/after values only for keys the operation actually changed, preserving absent keys and legacy dictionaries. Undo those keys only after checking their current values against the operation's after-values. Refuse a conflicting reversal or invalidate the receipt when a relevant manual edit occurs. Test an unrelated later assignment and a conflicting later edit to an added assignment.

### 4. A skipped suggestion cannot be retried after its conflict is cleared

Location: `Sources/TinyHand/SuggestedShortcuts.swift:93`; disabled Add button at `Sources/TinyHand/ShortcutsSettings.swift:49`.

Assign the proposed Pointer shortcut to Clear Drawing, then apply the other suggestions. Pointer is recorded as Skipped. Clear the conflicting Clear Drawing assignment. `suggestedRows` returns the old skipped reason from `suggestedResult` before calling the current conflict checker, so Pointer still appears unavailable. With the other suggestions occupied and Screenshot reserved, Add remains disabled. Even a normal model refresh cannot recover it. The user must undo the successful suggestions or recreate the model before retrying.

Fix: derive current row eligibility from live assignments and conflict checks. Keep the previous operation's result summary separate from current eligibility, or provide an explicit Retry that clears stale outcomes and rechecks. Test clearing an app-owned conflict after a partial successful Apply.

### 5. Non-hand pointers lost independent override resets

Location: `Sources/TinyHand/PointerInspector.swift:67`, especially `Sources/TinyHand/PointerInspector.swift:79`.

Give Presentation pointer explicit shadow, sound-enabled and sound-choice overrides. To make only sound-enabled inherit again, the new UI offers only Use Default Sound and Effects, which clears all three fields. It cannot preserve the chosen sound and shadow while resetting just the enabled override. Laser and Spotlight have the same coupling between enabled and sound choice. Toggling to the currently inherited boolean value does not restore inheritance; it saves an explicit override. The previous customization view provided a per-field Use Default action for these supported non-hand fields.

Fix: retain separate inherited/customized indicators and reset actions for sound-enabled, sound choice and Presentation shadow in the More submenu. Reuse the five-field override policy and reset only the requested optional field. Test the actual non-hand editing/reset actions, not just `PointerInspectorState.handControls`.

### 6. One broken historical recovery copy prevents Undo of a newer valid change

Location: `Sources/TinyHand/PresentationStore.swift:497` and `Sources/TinyHand/PresentationStore.swift:511`; caller at `Sources/TinyHand/PresetsSettings.swift:28`.

Leave an older UUID-named recovery JSON unreadable or truncated, then save a new preset successfully and open Presets. `latestRecovery` now calls `recoveryCopies()`, which decodes every journal before looking for the newest un-restored receipt. The old error throws before the valid new receipt can be returned. On a fresh model, Undo stays unavailable despite a valid recovery journal for the successful change. Previously the newest usable receipt could be returned without reading older journals.

This eager scan also reads and retains all artwork payloads synchronously from the UI, twice per refresh: once through `latestRecovery` and once for the list. Each journal permits up to 150 MB, and journals are deliberately retained. Merely opening Presets can therefore block the main thread and retain hundreds of megabytes after several artwork imports, even with Recovery copies collapsed.

Fix: use a lightweight, asynchronous recovery catalogue. Resolve the newest applicable receipt without decoding every older payload, show a preserved unreadable entry with an error, and load full bytes only for review/restore. An unreadable historical copy must not hide a newer valid Undo. Test that scenario and verify that listing does not eagerly load all file payloads.

### 7. The permission window's primary button has the wrong accessible action name

Location: `Sources/TinyHand/WelcomeWindow.swift:135`; changing visible title at `Sources/TinyHand/WelcomeWindow.swift:66`.

The new explicit accessibility label is permanently Show Pointer. When drawing permission is missing, the same button visibly says Open Settings and opens System Settings; after permission is granted it says Start Drawing. VoiceOver still announces Show Pointer in both states, concealing the permission-repair action and then misidentifying the drawing action.

Fix: update the accessibility label alongside the title in `refresh`, or remove the explicit label and let AppKit use the current title. Check all three states through the native accessibility properties.

## InputTap abort and local checks

`scripts/run-tests.sh` exited **1** during this review. The build completed, but Swift Testing aborted during `PresentationControlsTests.toolSelectionEntersDrawingAndModeShortcutReturnsToLastTool`, while processing its Pen case, with:

```text
Object 0x76b9de5b80 of class InputTap deallocated with non-zero retain count 3.
This object's deinit, or something called from it, may have created a strong
reference to self which outlived deinit, resulting in a dangling reference.
```

The script stopped before its Python test and layout lints. This was not an assertion failure or a successful full-suite run.

Attribution: the native callback's unretained `self`, event-thread startup, and `deinit` invalidation/stop sequence at `Sources/TinyHand/InputTap.swift:116`, `:129` and `:150` are already present in HEAD. InputTap is outside the three phase implementation manifests. The retained prior diagnostic in `dist/verification/usability-icons-phaseB2C/test-teardown-intermittency.txt` and its `.ips` report show the same abort in a different test. I found no evidence that the icon redesign introduced the underlying teardown defect. The new parameterized control test does create and destroy real taps, exposing the existing lifetime problem more often. Its hard dependency on a working native tap also weakens isolation.

Fix direction for the existing defect: shut down the native tap explicitly while its owner is still alive, drain or synchronize outstanding callbacks on the owning run loop, then release the callback context. Do not infer a precise root cause from this diagnostic alone. Give OverlayController an injectable tap connection so model tests do not require the system event tap. Keep a separate bounded lifecycle test for real installation/teardown.

A subsequent focused run completed successfully:

```text
scripts/run-tests.sh --filter 'UsabilityB1Tests|UsabilityB2CTests|GestureArtworkTests'
30 Swift tests in 3 suites passed.
1 Python Stream Deck package test passed.
All 36 grid-lint invocations passed.
Exit 0.
```

This focused pass does not supersede the failed full run. No packaging build or macOS 13 runtime check was performed.

## Coverage and remaining code

- Cursor requests are idempotent mode requests, while the separate mode shortcut toggles against the retained tool. Tool selection does not activate a hidden pointer. Capture rejection occurs before the new control handler changes the tool; protocol permission rejection still precedes mutation. The stored mode/tool vocabulary and AppleScript terms remain compatible. Legacy Settings routes are retained and canonicalized.
- The star adapter preserves independent pin order and six wheel IDs. Explicit wheel assignment uses the existing swap behavior. The legacy archive's default-wheel decoding predates this redesign in the retained radial review source; it is not attributed here as a new migration change.
- The restore-copy transaction saves its safety journal before writes and checks both reviewed preferences and affected file bytes. Existing local-only backup exclusions remain intact, subject to the new artwork omission in finding 2.
- Gesture resolution follows custom, per-hand bundled, then generic. Corrupt custom artwork remains unavailable; custom hands use generic composition without a custom pose; non-hands return no gesture. The existing packaging wildcard covers all 72 assets. The focused resource/pixel tests passed. The signature incorporates the active base and relevant pose sources. No new retain cycle was found in the new weak callback wiring. The toolbar remains nonactivating, and its picker is exposed in the toolbar window list for lifecycle/capture handling.
- The fixed toolbar context and shared-button frame test is useful. It does not exercise the visibility lease, so it misses finding 1. The 72-resource tests meaningfully verify decoding and direct canvas selection. Their anchor assertion at `Tests/TinyHandTests/GestureArtworkTests.swift:24` only verifies that `HandAsset.replacingImage` copies base anchor fields, as its implementation does at `Sources/TinyHand/PointerStyle.swift:413`; it does not measure artwork alignment. The backup inclusion test at `Tests/TinyHandTests/UsabilityB2CTests.swift:129` largely repeats literal UI strings instead of checking exported contents. Exact-Undo tests cover an immediate reversal, not intervening edits. Symbol existence tests run against this Mac's symbol catalogue and do not establish macOS 13 availability; the hidden-hand symbol has an explicit fallback.
- Dead UI remains: `ToolbarFavorites` and its old picker/drag helper tree in `Sources/TinyHand/PointerSettings.swift:6`; `SoundPage`, `DefaultTapSoundSettings` and `AppSoundSettings` in `Sources/TinyHand/SoundSettings.swift:6`; and the unused `HandGestureSettings`/`HandGestureShortcutSettings` views in `Sources/TinyHand/HandGestureSettings.swift:4`. Remove these unused trees and their unused model hooks after retaining shared helpers. The old Customize sheet and Appearance page are removed. `AboutPage` is **not** dead: General embeds it at `Sources/TinyHand/SettingsPages.swift:46`, and the old About route correctly selects General.

The two P1 findings should be fixed before approval. The reproduced teardown abort must remain visible in the validation record rather than being represented by a later passing run alone.
