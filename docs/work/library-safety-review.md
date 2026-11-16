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

PointerThumbnailCache retains encoded PNG data and the source asset signature.
Unchanged polling skips AppKit icon rendering, PNG encoding and filesystem writes.
A changed source signature invalidates only that icon. Deleted or altered export
files are repaired from retained bytes without encoding again. Native generated
icons have an explicit renderer version. Existing hex-encoded filenames and the
128 px native cropped artwork are retained, including custom hands.

The first request resolves lazy AppKit artwork on the catalog queue. ImageIO PNG
encoding runs on an explicitly enqueued utility worker, because dispatch_sync can
run on the calling thread. The synchronous control reply waits for that first
export. Later polls use cached files. Removed/unavailable IDs release cached data;
existing export files are not deleted.

ControlTransport validates absolute paths before creating any URL, and rejects
empty/relative paths, root, home, the checkout and descendants, symbolic links,
non-directories, unexpected ownership and non-private directory permissions.
Thumbnail files must be regular same-user files. An unavailable endpoint omits
thumbnail paths instead of constructing a cwd-relative URL. With isolated defaults,
TH_THUMBNAILS_DIR must explicitly identify a disposable directory. The normal app
uses its existing private control directory.

scripts/run-tests.sh now uses a unique mktemp root, unique defaults suite and
separate Hands/Thumbnails paths, and accepts Swift test arguments. Its cleanup
removes only that newly created temporary root. No existing root PNG was removed.

Verification: five new thumbnail tests passed locally. They check repeated encode
and render counts, encoding off-main, stable file modification time and inode,
source invalidation, missing/tampered export repair, unsafe paths and symlinks,
custom asset changes, and actual repeated ControlBridge styles responses.

Combined final validation: 46 tests passed across seven suites with a unique
TINYHAND_DEFAULTS_SUITE and isolated TH_HANDS_DIR/TH_THUMBNAILS_DIR. The filter was
`HandRecoveryTests|HandRemovalSettingsTests|PointerThumbnailTests|PointerCatalogTests|GestureTests|ShadowTests|ControlTests`.
SwiftPM compiled the application and tests locally in the existing language mode.
`git diff --check`, `bash -n scripts/run-tests.sh`, and PointerLibrary grid lint
passed. No hosted workflow was created or run. No packaging helper, install,
signing, notarization, normal preference domain, real Hands folder or UI automation
was used.

Integration notes: ControlBridge changes are confined to its cache property and
styles() output loop. Existing cycling/transport protocol fields are unchanged.
CustomHands.remove now throws and returns its recovery receipt. Existing unit-test
cleanup call sites were updated explicitly. Parent should preserve that contract
when integrating other agents' library/settings edits. Parent still owns light/dark
Settings inspection, actual keyboard/VoiceOver flow, release builds and packaging.
The per-pointer override hook described above still needs the separate override
implementation to supply and restore its payload.
