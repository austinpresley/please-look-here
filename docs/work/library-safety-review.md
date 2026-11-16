# Library safety review

Assigned stories: S-040 and S-044, recommendations 5 and 9.

## S-040 recovery

UX: Settings > Pointers > Remove Hand removes a custom hand from the library.
A visible Undo Remove [hand name] button above the library restores it. Removal
also remains in the context menu; the older hand chip action is always visible
and has an accessibility label. No global shortcut is assigned. Recovery survives
relaunch. Errors stay inline, name the failure and identify the recovery folder
when manual repair is needed. Native text-editing keys are unchanged.

HandRecoveryStore owns a versioned receipt and durable copies in Hands/.Removed.
It saves metadata, original manifest position, artwork, both existing per-hand
gesture files, toolbar pins, enabled state and the previous selection ID. The
manifest commits atomically after recovery preparation. Removal errors restore
missing original files before returning an actionable error. Interrupted removals
are repaired when CustomHands reloads. Undo retains recovery copies, never
replaces conflicting files, and can retry after a file or manifest failure. A
Undo restores the prior toolbar pin snapshot, including a sole pin. A
restored hand does not steal the current pointer selection or change activation.
Symbolic links and unsafe IDs are rejected by the transaction.

Per-pointer override integration hook: pass a versioned encoded payload in
CustomHands.remove(style, extensions: ["pointer-overrides": data]). The receipt's
state.extensions preserves opaque data. After CustomHands.restore succeeds,
restore that ID's overrides from receipt.state.extensions in the same preferences
batch as pins/enabled state in SettingsModel.undoHandRemoval. Retain existing
per-ID overrides until the removal transaction succeeds. The current code does
not invent or clear unknown override keys.

Glossary/copy proposals: Remove Hand means recoverable removal from the pointer
library. Undo Remove [name] restores the removed hand and its saved settings.
Recovery copy means the private on-disk package retained inside Hands/.Removed.
Use Remove, rather than Delete or Move to Trash, because storage is app managed.

Verification: 13 focused recovery, Settings and gesture tests passed locally with
a unique TINYHAND_DEFAULTS_SUITE and temporary TH_HANDS_DIR, including
manifest and partial-file failures, restart recovery, retryable Undo, conflict
protection, missing artwork and invalid path/symlink rejection. Successful Undo
checks decoded manifest order and exact artwork bytes; rollback checks the
original manifest bytes too. PointerLibrary grid lint passed. Command: `swift test --filter 'HandRecoveryTests|HandRemovalSettingsTests|GestureTests'`.
Parent owns integrated Settings
light/dark snapshots, keyboard/VoiceOver checks and packaging. No normal settings,
real hand files, installs, signing or UI automation are used in this worktree.

## S-044 thumbnails

Implementation and test evidence pending.
