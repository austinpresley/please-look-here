# Pointer defaults and sound implementation

Worktree: `/Users/apresley/.t3/worktrees/Please Look Here/t3-49e5130b`
Branch: `t3/pointer-defaults-sound-volume`
Scope: S-042 / recommendation 7 and S-049 / recommendation 14.

## S-042

`PointerConfigurationDocument` is a version 1 Codable archive keyed by stable raw
pointer IDs. Each optional size, shadow, shadowStyle, soundEnabled and sound field
inherits separately. An empty override is removed. Catalog absence, disabled
state and unavailable artwork never prune the archive.

The existing global preferences remain defaults. Migration preserves size,
showShadow, shadowStyle, tapSound and handSound as they are. The legacy laser
sound flag becomes an explicit laser soundEnabled override. Spotlight and the
presentation rod continue to inherit handSound, including when it is enabled.
Migration reads do not write. Corrupt archives are preserved and edits fail.

Applicability follows the existing renderer. All pointers support size and sound.
Hands support shadow visibility and Original/Contact style. The presentation rod
supports shadow visibility with its existing rod shadow. Spotlight has an aperture
and no shadow; Laser dot has its existing glow and no configurable shadow.
The UI uses Hand size, Dot size, Aperture size and Rod thickness.

`PointerCustomization(style:model:)` is self-contained for the library agent to
place next to its selected entry. It is currently shown for the active pointer
above the library. Native controls retain keyboard focus and text editing keys.
Each field shows Default or Customized and has its own Use Default button.
Changes apply inline; Escape stops an audition. Save failures appear inline.
Appearance and Sound identify their shared settings as Pointer Defaults.

ArmView resolves configuration on selection and preference changes. Overlay
sound choice/enabled state resolves per pointer. Current-pointer sound toggles
customize only that pointer. Legacy `configure` size/shadow/shadowStyle/handSound/
tapSound retain global semantics; laserSound retains its laser-only semantics.
`configure.settings.pointerOverrides` accepts a dictionary of ID -> field patch.
Unspecified fields stay unchanged; a field null restores inheritance; an ID null
restores all defaults for that pointer. Validate the whole batch before writing.
Explicit pointerOverrides take precedence over laserSound in the same batch.
Status includes `pointerConfiguration`; styles include per-entry `configuration`.
Both report effective values, explicit overrides, applicability and archive health.

### Portable backup and custom-hand recovery hooks

- Export all: `try PointerConfigurationDocument.load(from: Preferences.storage).encoded()`.
- Import all: `let document = try PointerConfigurationDocument.decode(data)`, then
  `try Preferences.savePointerConfigurations(document)`. Decode and validate all
  other backup components before applying any of them.
- Capture one hand before deleting: load the document and retain `document.pointers[id]`
  in the recovery record. The optional `PointerOverride` itself is Codable.
- Remove after capturing: `try document.replace(nil, for: id)`, then save the document.
- Restore: `try document.replace(savedOverride, for: id)`, then save. Restoring does
  not require catalog membership; validate/recover artwork separately.
- Prefer leaving overrides saved while a hand is merely unavailable. There is no
  automatic cleanup tied to catalog refresh or deletion.
- `replace`, `patch`, `applying`, `decode`, `encoded` and save validate IDs, ranges,
  enum values and applicability. Portable import must use `decode`, rather than
  calling JSONDecoder directly. Unknown archive versions/fields fail closed.

### Local evidence

- Isolated `swift build` passed with Swift 5 language mode and the existing package
  macOS 13 deployment declaration unchanged.
- `TINYHAND_DEFAULTS_SUITE=com.austinpresley.pointer-defaults.s042
  TH_HANDS_DIR=/tmp/lhp-pointer-defaults-s042-hands swift test --filter PointerConfigurationTests`
  passed 8 tests. Covers all legacy enabled combinations, Spotlight sound,
  independent inheritance/reset, missing-ID round trips, export/remove/restore,
  invalid imports/patches, applicability, archive preservation and Preferences
  migration/readback/reset.
- Grid lint passed for PointerCustomization, SoundSettings and PresentationSettings.
- `git diff --check` passed.

## Copy and glossary proposals for parent

- Pointer Defaults: shared appearance and tap sound values for inherited fields.
- Customized: this pointer has an explicit value for this field.
- Use Default: remove this field's override and follow its shared default.
- Aperture size: Spotlight's transparent circle, relative to display height.
- Rod thickness: Presentation pointer's width, using the existing size range.

## Integrated checks reserved for parent

Native Settings layout in light/dark, minimum width and long titles; keyboard and
VoiceOver traversal; live selection/size/shadow/sound changes; native menu/radial
feedback and real control transport; packaging. No GUI automation, app install,
signing, notarization, packaging, hosted CI or normal preferences were used here.
