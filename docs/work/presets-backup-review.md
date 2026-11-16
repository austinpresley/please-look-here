# S-051 presets and portable backups

Worktree: `/Users/apresley/.t3/worktrees/Please Look Here/t3-89cc737a`
Branch: `t3/named-presets-safe-backups`
Scope: recommendation 16, S-051 only. Implementation uses gpt-6.1-sol with High reasoning. No delegation, PR, push, delivery, normal preferences, actual Hands, GUI automation, installation, signing, notarization or packaging.

## Native workflow and state effects

Settings has a new `presets` section. Existing section raw IDs are unchanged.

- Save names the current setup. Return in the name field saves. Names are trimmed, case-insensitively unique and limited to 160 UTF-8 bytes. There are at most 100 presets.
- Apply restores the selected setup. Update from Current Setup replaces that preset's captured settings while retaining its ID/name. Remove removes the saved preset. Every operation creates a local recovery record first.
- A setup captures the raw selected pointer ID, ordered pins, separate disabled IDs, shared visual/ink/sound settings, master mute/volume and the complete validated override document. Missing or unknown pointer IDs remain in pins, disabled state and overrides. No catalog compaction discards them.
- The native adapter supplies current catalog availability. Applying an unavailable selection chooses an enabled available pointer before creating its recovery record. This avoids treating the app's normal catalog repair as a later edit during Undo. A setup with no enabled available pointer rejects application before mutation. Imported valid custom hands count as available. The saved preset retains its original selected ID.
- Pointer On/Off and Interact are never written. Shortcuts, gesture shortcut assignments, radial trigger, login/startup/update settings, capture folder, toolbar position, host profiles and bundle identity are excluded. There is no opt-in shortcut/startup restoration in version 1 and no new assigned hotkey.
- Capture copy/save booleans are supported. The current Mac's capture destination always remains local.
- Import first opens a read-only preview. It shows settings before/after, new hands/artwork/presets, selection, ordered pins, disabled IDs, override IDs and conflicts. Cancel performs no writes. Different existing artwork, manifest identity/settings or saved presets block the whole import. Existing files are never silently replaced. Matching content is reused; new hands append to the existing manifest.
- Import validates again and compares the preview's file plan and complete allowlisted preference snapshot immediately before applying. A stale preview must be reopened. Image validation/export and import work run off the UI queue. Completion invalidates hand/gesture caches and sends the existing native preference notification.

## Version 1 format

A self-contained JSON file named `Look Here Please Backup.json` by default. No ZIP extraction, source tree, credentials, whole defaults domain or recovery packages are exported.

Top-level fields are exactly:

```text
format: "look-here-please-portable"
version: 1
setup: { selectedID, pinnedIDs, disabledIDs, settings, pointerOverrides }
presets: [ { id: UUID, name, setup } ]
hands: [ { id, name, ink: UInt32 RGB } ]
artwork: { canonical relative PNG filename: base64 image bytes }
```

`pointerOverrides` is base64 data containing `PointerConfigurationDocument` version 1. Decode goes through its existing strict public API. Shared defaults plus the full override archive reconstruct effective values while retaining each field's inheritance.

`settings` requires exactly these keys, with strict booleans, finite bounded numbers or supported enum strings:

```text
pointerSize, showShadow, shadowStyle, pointerMotion, theme,
showToolbar, showInkButton, interactKeepsHand, drawingTool,
inkChoice, strokeWidth, inkOpacity, strokeSmoothing,
fadeSeconds, inkFadeStyle, trailDelay, trailSpeed,
magnifierZoom, magnifierDiameter, tapSwing,
sound.hands, sound.laser, tapSound, sound.volume, sound.muted,
capture.copy, capture.save
```

Capture materializes defaults without writing them and preserves legacy fade-mode semantics. Sound output includes master mute and volume independently of saved tap choices/enabled flags. `sound.laser` preserves the legacy scalar; the override document remains authoritative for per-pointer sound.

Bounds:

- At most 100,000,000 input/output JSON bytes, 64,000,000 total decoded artwork bytes, 8,000,000 bytes per PNG, 256 custom hands and 840 artwork entries.
- PNG only, one image per file, positive dimensions, maximum 8192 per side and 16,777,216 pixels. Decode must succeed. Custom base artwork must also pass the renderer's hand/stick geometry measurement. Custom gesture dimensions must match the base hand. Version 1 built-in gesture artwork uses the existing 1024 × 1536 canvas; all 36 bundled hand assets were checked to use it.
- Hand IDs use the existing custom-ID grammar plus a 128-byte limit. Pointer IDs use `PointerConfigurationDocument.validID`. Duplicate IDs and case-only hand/artwork collisions fail. Names reject control characters; RGB colors stay within `0x000000...0xffffff`.
- Paths are derived only from validated manifest IDs: `<custom-id>.png` or `Gestures/<hand-id>-first.png` / `-second.png`. Built-in gesture IDs are explicitly enumerated from built-in hands. Absolute paths, traversal, arbitrary filenames and symlinks fail. Existing user-controlled root ancestors and descendants must be real directories/files. Standard macOS `/var` and `/tmp` aliases are permitted.
- Unknown archive-owned object fields, unsupported versions, missing settings, wrong types, duplicate preset names/IDs, invalid enum values, nonintegral smoothing, out-of-range numbers, disabled selection and disabling both capture destinations reject before mutation.
- An incomplete/corrupt hand or override archive is reported rather than silently exported as a partial backup. Unknown local manifest/preset object fields also stop writes so a future schema is not dropped.

Saved presets live at `<Hands>/.Presentation/presets.json`, a versioned document capped at 4 MB. Imported presets merge with local presets by UUID and case-insensitive name. Different content at either identity blocks import.

## Recovery and failure behavior

Before writing artwork, manifest, presets or preferences, `PresentationStore` atomically writes:

`<Hands>/.Presentation/Recovery/<UUID>.json`

The record contains its version, token, date/title, before/after bytes for touched canonical files, and binary property lists containing only the setup preference allowlist. Missing raw preferences remain distinguishable from explicit values. No screenshot destination or shortcut data enters the record.

Undo Last Change reloads the latest unresolved record across Settings/app restarts. It checks every affected file and preference before writing. Values must match either the before or after state, permitting partial application, failed restoration and retries. Later conflicting edits stop recovery without replacement. Unchanged preferences are left alone during Undo, so removing a preset does not roll back subsequent ordinary setting edits. Existing unrelated files are untouched; newly imported files are removed on successful Undo. Before/after records are retained, and a separate `.restored` marker removes completed operations from Undo. Older recovery JSON files remain local backups. Discovery decodes only the newest unresolved journal rather than loading every retained artwork copy into memory.

A write failure attempts immediate rollback. If rollback also fails, the error names the retained recovery folder. Repair access/the unexpected file, then use Undo Last Change again. Recovery is explicit; opening Settings does not automatically overwrite current preferences/files after a previous interrupted import. There is no automatic journal pruning.

The parent-owned hand-removal methods and `HandRecoveryStore` behavior were not changed. `PointerStyle.swift` adds only a pure geometry-validation hook for the existing renderer.

## Local evidence

All commands ran on Austin's Mac in this worktree. Swift 5 language mode and Package.swift's macOS 13 declaration are unchanged. No hosted workflows were added or run.

```sh
TINYHAND_DEFAULTS_SUITE=com.austinpresley.presets.s051.tests \
TH_HANDS_DIR=/tmp/lhp-s051-test-hands \
swift test --filter 'PresentationArchiveTests|PointerConfigurationTests|SoundOutputTests|HandRecoveryTests/(removalAnd|manifestFailure|errorAfter|interruptedRemoval|failedUndo|missingArtwork|invalidManifest)'
```

Passed 48 tests in four suites: 22 new archive/storage tests, eight existing override tests, eleven existing sound-output tests using injected audio drivers, and seven existing file-only hand-recovery tests. The SettingsModel/GUI hand-recovery test was deliberately excluded. New tests use unique disposable defaults suites and temporary directories; image fixtures use Core Graphics without windows/audio devices.

Coverage includes named save/update/apply/remove, reload and Undo, exact archive round trip, custom/built-in gesture export, pin/enabled/missing-ID preservation, setting exclusions, default/mute/volume preservation, identical import reuse, identity/artwork/preset conflicts, stale preview files/preferences, failed journal creation, partial file-write rollback, failed rollback and recovery retry, interrupted application, later-edit conflicts, symlinked files/roots/ancestors, case-only collisions, slot-suffix hand IDs, unavailable selection resolution, no-available-pointer rejection, malformed data, 29 invalid component variants, unknown fields/types, count/total-size/dimension bounds and corrupt local storage preservation.

`swift build` passed with the same isolated suite/Hands overrides, using `.build` only. Grid lint passed for PresetsSettings and SettingsView. `git diff --check` passed. Logs: `/tmp/lhp-s051-focused.log` and `/tmp/lhp-s051-build.log`.

## Parent UI checks still required

No native UI acceptance or packaging claim is made by this worker. The parent owns these checks on a disposable integrated instance:

1. Open Settings > Presets via both sidebar and existing section-routing mechanisms. Check light/dark, minimum window width, largest supported text, long names, empty state, error text, sheet scrolling and toolbar/sidebar fit. Confirm old section IDs still route correctly. Run layout probes for the new page/card/sheet and inspect window-only snapshots.
2. Keyboard and VoiceOver: name field, Return to save, preset picker, Apply, Update from Current Setup, Remove, Export, Import, Undo Last Change. Escape cancels preview. Return confirms only a conflict-free preview. Controls have spoken names and no unintended global key registration.
3. Seed distinctive selected/enabled/pinned pointers, including a disabled pin, unpinned enabled hand, missing-ID override and independent inherited/custom fields. Save two names, apply each, update one and remove/Undo it. Check live pointer/ink/sound changes and persistence after restart.
4. Apply with Pointer On then Off and Interact On then Off, with valid drawing permission. Confirm activation/mode, existing hotkey assignments and login state do not change. Verify a missing selected hand uses the announced available fallback and Undo still succeeds. No-enabled-available setups must show an error without changes.
5. Export a disposable library with custom hand and both gesture slots plus a built-in hand's custom gestures. Import into another disposable suite/folder. Preview must explain before/after values and exact identity lists. Check artwork rendering, gesture geometry, manifest RGB/name/ID, saved presets, sound volume/mute and override inheritance. Re-export and compare semantic archive content.
6. Preview/cancel a conflicting import with different local artwork/name/preset. Import stays disabled. Re-preview after modifying local settings/files; stale application must refuse. Malformed/oversized/unsafe archives show an actionable message with no partial change.
7. Import and Undo, then restart and Undo a different import. Confirm raw absent/explicit defaults, existing hand bytes, manifest/presets, pins and disabled state restore; only imported files disappear. Confirm local capture folder, shortcuts, radial trigger, startup, toolbar position and unrelated files stay unchanged throughout.
8. Exercise real-file permission/disk failures in disposable storage. Verify immediate rollback, retained recovery path when rollback cannot finish, conflict refusal after a later edit, repair and retry. Large valid imports/exports should show progress and leave Settings usable. Verify profile/key settings and existing control integrations after the parent combines all work.
9. Parent performs final local build, integrated UI verification, signing/notarization and packaging under the existing release workflow. This worker did none of those host-affecting operations.

## Glossary and copy proposals

- Presentation preset: a named saved pointer, drawing and sound setup. It does not save Pointer On/Off, Interact or global shortcut/startup assignments.
- Portable backup: a bounded versioned JSON export of supported settings, named presets, custom hands and gesture artwork.
- Recovery copy: the local before/after record retained before a preset or backup changes saved data.
- Update from Current Setup: replace the selected preset's captured values while retaining its name and identity.
- Undo Last Change: restore the latest unresolved preset/backup transaction, preserving later conflicting edits by refusing replacement.

No known implementation gap remains in the assigned storage/validation/native-workflow scope. The integrated UI/runtime checks above remain unverified here by assignment. Version 1 intentionally has no selective conflict replacement, shortcut/startup import, automatic pruning or cross-Mac capture destination restoration.
