# S-040 recovery audit fixes

Worktree: `/Users/apresley/.t3/worktrees/Please Look Here/t3-590ba9a5`
Branch: `t3/recover-hand-removal`
Base: `e8a03cd`, including the override integration from `43dd33d`.

## Manifest protection

CustomHands reads and retains validated hands.json membership before inspecting
recovery receipts. A damaged receipt cannot turn a valid manifest into an empty
writable library. On a manifest read failure, an existing cache remains available
for display, but it does not authorize writes.

Every addition and removal refreshes and validates load/recovery state first.
Add rejects before writing artwork when that validation fails. Its private save
also rejects a changed manifest instead of replacing membership from a stale
cache. An absent manifest is accepted as a new library only without a .Removed
folder. A malformed manifest or a missing manifest with recovery packages blocks
mutation. Decode errors name hands.json or the damaged receipt.json and tell the
user to preserve the file/package, repair it from backup, then reopen Settings.
The hand draft now displays the actionable save error.

## Restore ownership and durable phases

The receipt schema remains version 1. Existing pending receipts and opaque
extensions remain readable. No portable preset/backup files or formats changed.

HandRecoveryStore owns files and journal markers. HandRestoreTransaction owns the
boundary between that store and preferences. Settings Undo and CustomHands startup
replay use the same transaction. CustomHands.restore keeps its existing facade;
direct file-store callers now use restoreFiles and completeRestore explicitly.

1. Validate the target pointer's override snapshot and current archive before any
   restore file changes. Preserve the parent's PointerRemovalConfiguration logic.
2. Atomically write `restoring` in the retained package before copying any artwork
   or changing manifest membership.
3. Restore identical/missing artwork and gestures, then atomically insert the hand
   at its saved manifest position. Conflicting files or metadata cause an error;
   recovery never overwrites them. Retries accept identical files and membership.
4. Merge only this pointer's override into the current archive, re-reading that
   archive at the preference boundary. Restore only this pointer's enabled flag.
   If the hand was pinned, restore its original toolbar snapshot, including a sole
   pin. Keep the current pointer selection, activation and shortcut assignments.
5. Persist preferences with UserDefaults.synchronize and check its result.
6. Only after that succeeds, atomically write `restored`. Retain receipt.json and
   every recovery file. A completion-marker failure is an error with retry advice,
   rather than a successful Undo with lost recovery UI.

Manifest membership alone never completes an unfinished receipt. A receipt with
restore intent, or an uncompleted legacy receipt whose hand is already present,
is replayed during CustomHands loading. Reopening Settings explicitly reloads.
Pending recovery includes file-restored hands until preference persistence and
completion succeed. Malformed payloads, failed preference persistence, partial
preference writes, and failed completion remain retryable. Removal rollback marks
its own receipt complete only after restoring files, before the caller has made
any preference changes.

## Local evidence

The initial regressions ran against the original implementation and failed with
eight expectations across three tests. They detected unsafe additions after
malformed receipts/corrupt manifests, changed manifest bytes, missing actionable
receipt paths, and recovery disappearing after files but before preferences.
Log: `/tmp/lhp-recovery-audit-red.log`.

The final focused run passed **48 tests across six suites**, compiling the app
and test targets locally with no reported warnings. Each invocation used a unique
TINYHAND_DEFAULTS_SUITE and a fresh temporary TH_HANDS_DIR/TH_THUMBNAILS_DIR.

```sh
TEST_ROOT=$(mktemp -d /tmp/lhp-recovery-check.XXXXXX)
TINYHAND_DEFAULTS_SUITE=com.austinpresley.tinyhand.recovery-check.$(uuidgen) \
TH_HANDS_DIR="$TEST_ROOT/Hands" TH_THUMBNAILS_DIR="$TEST_ROOT/Thumbnails" \
swift test --scratch-path .build/audit \
  --filter 'HandRecoveryTests|HandRemovalSettingsTests|PointerCatalogTests|GestureTests|PointerConfigurationTests|PointerLibraryFilterTests'
```

Log: `/tmp/lhp-recovery-audit-focused.log`.

After strengthening two preservation checks, those two tests passed again.
Log: `/tmp/lhp-recovery-audit-exact.log`. They compare the full preference dictionary
against the expected result and retry after simulated partial preference writes.

Coverage includes uncached valid manifest membership with a malformed receipt;
attempted add/remove without changing the manifest, receipt or file list; corrupt
manifest with a previously loaded cache; interruption after file restore; reopened
store and preference domain; startup replay through SettingsModel; invalid archive
repair and retry; persistence failure; interruption after preferences; completion
marker failure; legacy receipts without override payloads; exact artwork/gesture
bytes and manifest order; unchanged manifest bytes on repeat restore; unchanged
unrelated overrides, enabled flags, selection and shortcut data. Existing rollback,
file conflict, missing artwork and path/symlink protection tests also pass.

`git diff --check` passed. Package.swift still targets macOS 13 with Swift 5
language mode. No normal app preferences/Hands, root artwork, UI automation,
signing, installs, packaging, hosted CI, PRs, pushes or deliveries were used.
Central story/glossary/fix/validation/milestone documents remain unchanged.

## Limits and parent handoff

These are replay guarantees for process interruption and reported API failures.
Files and UserDefaults do not share an atomic transaction. Synchronize is the
checked preference persistence boundary; no sudden power-loss or filesystem fsync
ordering guarantee is claimed. External processes editing the same files/defaults
concurrently are not locked out by this change.

Already finalized legacy `restored` markers remain trusted. An older app's crash
after prematurely writing that marker cannot be distinguished from a completed
Undo followed by intentional preference edits. Automatically replaying those old
completed packages would risk overwriting later choices. Their backups remain
intact for deliberate recovery; this patch prevents that ambiguity for new
transactions and supports unfinished legacy receipts.

Toolbar Undo keeps the existing whole-snapshot policy when this hand was pinned.
It can replace later toolbar pin edits. Unrelated per-pointer overrides and
enabled flags retain their current values.

Parent owns integrated UI/keyboard/accessibility checks and packaging. No new
functional acceptance gaps were observed in the corrected transaction paths.

Glossary/copy proposal: “Restore in progress” means artwork may already be back
while saved settings still need replay. An inline failure should retain “Undo”
and name the recovery package and repair/retry action. No new shortcut is added.
