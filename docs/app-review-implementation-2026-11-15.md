# App review implementation, 15 November 2026

Austin authorized all 18 recommendations from the Sol 6.1 and Opus 5.5 High review, with Sol 6.1 **High** subagents and no Max setting. For recommendation 8 he explicitly requires wrapping on Stream Deck too. This milestone supersedes earlier limits that kept S-005, S-006, S-012 and other review ideas out of scope. The original review remains in `dist/reviews/app-review-2026-11-15.html`.

Implementation branch: `feature/app-review-improvements-20261115`. Baseline: `5586924`. Use isolated T3 worktrees for parallel work and integrate reviewed commits here. No nested delegation. All tests, UI checks, builds, signing and notarization run locally on Austin's Mac. Hosted CI stays disabled. Preserve bundle identity, existing data, hand files, pins, shortcuts, profiles and grants. New optional commands start unassigned.

## Recovery

Verified off-volume Git bundle, untracked-file archive, previous installed app ZIP, normal preference export and hand archive are under `/Users/apresley/Library/Application Support/Look Here Please/Backups/app-review-20261115`. Existing root PNGs and untracked branding assets are preserved. No source is pushed or uploaded as part of backup.

## Queue

### S-36 Preserve drawings across displays

Review recommendation: 1.

Acceptance:
- Per-display documents and Undo history survive cursor crossings. Pointer Off hides and retains drawings for explicit reactivation; system wake never reactivates automatically.
- Add focused regression coverage for behavior changes. Parent verifies integrated UI and packaging before final acceptance.

UX:
- Use the existing overlay. No new permission, window or automatic wake behavior. Clear Drawing remains explicit.
- Escape cancels temporary UI. Native text editing keeps its usual keys. Errors say what failed and how to recover.

Status: implemented; integrated 192-test suite passed, native and packaging acceptance pending

### S-37 Make annotation fading consistent

Review recommendation: 2.

Acceptance:
- Whole-line and trail expiration exclude invisible markers from hit-testing. Text follows the selected fade policy. Undo/Redo preserves full geometry with defined restored visibility.
- Add focused regression coverage for behavior changes. Parent verifies integrated UI and packaging before final acceptance.

UX:
- Keep expiry separate from semantic history. Visible-state counts drive drawing controls; expired history remains recoverable.
- Escape cancels temporary UI. Native text editing keeps its usual keys. Errors say what failed and how to recover.

Status: implemented; integrated 192-test suite passed, native and packaging acceptance pending

### S-38 Keep radial input compatible with normal clicks

Review recommendation: 3.

Acceptance:
- A short bare-modifier hold opens radial controls; earlier mouse/key chords pass normally. Canceled or missed releases cannot leave the trigger stuck. Retain owned input pairs.
- Add focused regression coverage for behavior changes. Parent verifies integrated UI and packaging before final acceptance.

UX:
- Use a 180 ms starting hold threshold. Cancel pending opening on ordinary mouse/key input. No default modifier.
- Escape cancels temporary UI. Native text editing keeps its usual keys. Errors say what failed and how to recover.

Status: implemented; integrated 192-test suite passed, native and packaging acceptance pending

### S-39 Isolate shortcut registration failures

Review recommendation: 4.

Acceptance:
- An unavailable binding does not unregister unrelated bindings. Conflicts are shown at their command and surfaced outside Settings. Existing assignment rollback remains.
- Add focused regression coverage for behavior changes. Parent verifies integrated UI and packaging before final acceptance.

UX:
- Keep all hotkeys user assigned. Name the conflicting command and combination; offer a route to Shortcuts.
- Escape cancels temporary UI. Native text editing keeps its usual keys. Errors say what failed and how to recover.

Status: implemented; integrated 192-test suite passed, native and packaging acceptance pending

### S-40 Recover deleted custom hands

Review recommendation: 5.

Acceptance:
- Removing a custom hand is reversible and includes its gesture artwork, metadata, enabled state and pins. File errors leave the library intact.
- Add focused regression coverage for behavior changes. Parent verifies integrated UI and packaging before final acceptance.

UX:
- Use Move to Trash/recoverable storage plus Undo. Make removal available without a hover-only target.
- Escape cancels temporary UI. Native text editing keeps its usual keys. Errors say what failed and how to recover.

Status: implemented; integrated 192-test suite passed, native and packaging acceptance pending

### S-41 Preview drawing settings live

Review recommendation: 6.

Acceptance:
- Finish S-005/S-006 with one local sample for width, opacity, color, smoothing and fading. Preview never changes live annotation history.
- Add focused regression coverage for behavior changes. Parent verifies integrated UI and packaging before final acceptance.

UX:
- Replace instruction-heavy rows with concise help and a practice canvas. Retain current Drawing controls.
- Escape cancels temporary UI. Native text editing keeps its usual keys. Errors say what failed and how to recover.

Status: todo

### S-42 Customize each pointer with shared defaults

Review recommendation: 7.

Acceptance:
- Implement S-012 with independent sound, size and applicable shadow overrides. Use Default restores inheritance per field. Existing preferences migrate without changing effective values.
- Add focused regression coverage for behavior changes. Parent verifies integrated UI and packaging before final acceptance.

UX:
- Edit a selected pointer in Settings. Clearly label Default or Customized. Spotlight aperture and rod thickness have appropriate names.
- Escape cancels temporary UI. Native text editing keeps its usual keys. Errors say what failed and how to recover.

Status: todo

### S-43 Wrap pointer cycling everywhere

Review recommendation: 8.

Acceptance:
- Next and Previous cycle all enabled available pointers and wrap. Stream Deck also wraps, supports cycle direction, and preserves existing keys and saved settings.
- Add focused regression coverage for behavior changes. Parent verifies integrated UI and packaging before final acceptance.

UX:
- Pins remain toolbar favorites. All entry points preserve Pointer On/Off and Interact. Existing Stream Deck cycle keys keep forward behavior.
- Escape cancels temporary UI. Native text editing keeps its usual keys. Errors say what failed and how to recover.

Status: implemented; integrated 192-test suite passed, native and packaging acceptance pending

### S-44 Cache thumbnails and isolate test files

Review recommendation: 9.

Acceptance:
- Catalog polling reuses unchanged thumbnail files and does not repeatedly encode them on the main thread. Empty/unavailable control directories cannot write into the checkout.
- Add focused regression coverage for behavior changes. Parent verifies integrated UI and packaging before final acceptance.

UX:
- No extra UI. Preserve existing custom-hand thumbnails; use isolated temporary output for tests. Do not delete preexisting root PNGs.
- Escape cancels temporary UI. Native text editing keeps its usual keys. Errors say what failed and how to recover.

Status: implemented; integrated 192-test suite passed, native and packaging acceptance pending

### S-45 Make controls accessible from the keyboard

Review recommendation: 10.

Acceptance:
- Sidebar, pin ordering and swatches work without dragging. Selected values are announced. Verify keyboard flows and document actual VoiceOver/hardware coverage.
- Add focused regression coverage for behavior changes. Parent verifies integrated UI and packaging before final acceptance.

UX:
- Keep native controls, logical focus and visible focus cues. Add labeled Move Left/Right actions for pins.
- Escape cancels temporary UI. Native text editing keeps its usual keys. Errors say what failed and how to recover.

Status: todo

### S-46 Browse and filter the pointer library

Review recommendation: 11.

Acceptance:
- Search and Enabled/Pinned/Custom filters work together. Tiles show pin and enable state. Gesture editing follows the selected pointer without burying the gallery.
- Add focused regression coverage for behavior changes. Parent verifies integrated UI and packaging before final acceptance.

UX:
- Keep the gallery near the top. Provide an empty-result message and Clear Search; retain independent Enabled and Pinned.
- Escape cancels temporary UI. Native text editing keeps its usual keys. Errors say what failed and how to recover.

Status: todo

### S-47 Preview pointer appearance locally

Review recommendation: 12.

Acceptance:
- A local preview demonstrates selected pointer size, shadow, follow and tap swing on light/dark/patterned samples without activating the desktop overlay.
- Add focused regression coverage for behavior changes. Parent verifies integrated UI and packaging before final acceptance.

UX:
- Use an inline sample and explicit Preview Tap. Keep the real pointer and annotations untouched.
- Escape cancels temporary UI. Native text editing keeps its usual keys. Errors say what failed and how to recover.

Status: todo

### S-48 Improve screenshot results and recovery

Review recommendation: 13.

Acceptance:
- Result feedback supports Reveal in Finder and Copy. Permission errors alone offer permission settings; other failures offer Retry. Add region/window capture if supported by the established local capture workflow.
- Add focused regression coverage for behavior changes. Parent verifies integrated UI and packaging before final acceptance.

UX:
- Use one result panel, with named destination and error-specific actions. Capture app controls remain excluded.
- Escape cancels temporary UI. Native text editing keeps its usual keys. Errors say what failed and how to recover.

Status: implemented; active light/dark and native capture acceptance pending

### S-49 Control sound volume and audition

Review recommendation: 14.

Acceptance:
- Add app volume and master mute without losing saved choices. Previewing is distinct from selecting and never unmutes or changes the saved pointer sound.
- Add focused regression coverage for behavior changes. Parent verifies integrated UI and packaging before final acceptance.

UX:
- Separate Preview and selection controls, integrate per-pointer inheritance, and expose effective mute and volume.
- Escape cancels temporary UI. Native text editing keeps its usual keys. Errors say what failed and how to recover.

Status: todo

### S-50 Teach controls in a practice window

Review recommendation: 15.

Acceptance:
- Replayable practice teaches Pointer On, Interact, drawing and radial use. Shortcut links focus the relevant command and unavailable actions explain why.
- Add focused regression coverage for behavior changes. Parent verifies integrated UI and packaging before final acceptance.

UX:
- Use a small self-contained practice window reachable after onboarding. No forced setup and no default assignments.
- Escape cancels temporary UI. Native text editing keeps its usual keys. Errors say what failed and how to recover.

Status: todo

### S-51 Save presets and portable backups

Review recommendation: 16.

Acceptance:
- Named presets save visual/ink/sound setups. Export/import carries settings, custom hands and gestures with schema validation, preview and recoverable application.
- Add focused regression coverage for behavior changes. Parent verifies integrated UI and packaging before final acceptance.

UX:
- Manual preset selection first. Keep shortcut/startup imports explicit and off by default. Preserve existing data and reject unsafe paths or invalid files.
- Escape cancels temporary UI. Native text editing keeps its usual keys. Errors say what failed and how to recover.

Status: todo

### S-52 Edit individual annotations

Review recommendation: 17.

Acceptance:
- Object eraser or selection removes a chosen stroke, arrow, rectangle, text or marker with one Undo action. Add a highlighter using existing drawing controls.
- Add focused regression coverage for behavior changes. Parent verifies integrated UI and packaging before final acceptance.

UX:
- Keep edits within Draw/Interact Off. Extend tool choices consistently through toolbar, radial, menus, automation and Stream Deck without changing existing key UUIDs.
- Escape cancels temporary UI. Native text editing keeps its usual keys. Errors say what failed and how to recover.

Status: implemented; integrated 192-test suite passed, native and packaging acceptance pending

### S-53 Back up source and reconcile status

Review recommendation: 18.

Acceptance:
- Verify a recoverable source backup off Project Vault, including untracked assets. Reconcile project status and old story records against actual shipped work and acceptance gaps.
- Add focused regression coverage for behavior changes. Parent verifies integrated UI and packaging before final acceptance.

UX:
- Use local git bundles and explicit files. No public source push, hosted workflows, or deletion of old evidence.
- Escape cancels temporary UI. Native text editing keeps its usual keys. Errors say what failed and how to recover.

Status: implemented; final integrated source backup and status reconciliation pending

## Verification limits

Real multiple-display/mixed-scale, physical Stream Deck and host-inspector, actual sleep/lock, VoiceOver, Script Editor dictionary and Intel/older-macOS checks must be recorded as performed or explicitly still pending. Simulated checks do not establish physical acceptance. No story is marked done solely because its source compiles.

## Progress

- Recovery checkpoint completed before implementation.
- Coordinator owns this file, STORIES.md, GLOSSARY.md, FIXLOG.md and VALIDATION.md. Agents return per-job evidence in separate `docs/work/` files to avoid parallel edits.

