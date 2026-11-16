# S-051 import audit fixes

16 November 2026. Implementation worktree `/Users/apresley/.t3/worktrees/Please Look Here/t3-d49a8c06`, branch `t3/import-recovery-races`, starting at `75ef26c`. Scope is the two round-3 preset/import P2 findings. The recovery implementation from that base and the parent's override receipt hooks remain intact. Swift 5 language mode and macOS 13 deployment support are unchanged.

## Reproductions on the current base

Both regressions failed before the fix with this local command:

```sh
TINYHAND_DEFAULTS_SUITE=com.austinpresley.tinyhand.import-audit \
TH_HANDS_DIR=/tmp/import-audit-hands \
swift test --filter 'PresentationArchiveTests/(importingRemovedIdentity|preferenceEditDuringArtwork)'
```

The first test exports a hand without gestures, adds a gesture, removes the hand, then imports the older backup. It follows the Settings reload recovery sequence through the real `HandRecoveryStore` and `HandRestoreTransaction`. Base `75ef26c` still accepts the import, restores the unpreviewed gesture, consumes Undo Remove, and leaves the gesture after Undo Import. The old removal receipt then cannot be restored. Its explicit restore phases fix interrupted restoration, but do not establish ownership between removal and import.

The second test edits `pointerSize` to `0.18` on the main queue inside the injected artwork write. The base accepts the import and replaces the accepted edit with `0.13`. It also publishes artwork, manifest and a recovery journal. The journal's before image predates the edit.

## Changes

`HandRecoveryStore.pendingImportHandIDs()` is a read-only query over existing validated version-1 receipts. Import preview rejects an imported hand ID with unfinished removal recovery, including case variants, legacy receipts, interrupted removals and incomplete restores. Completed restores remain importable. The query never repairs files, replays preferences or marks a receipt complete.

Import now has two phases. `prepareImport` runs off the main thread. It validates the archive and preview again, writes artwork and the complete recovery journal into a unique staging folder on the Hands volume, verifies staged bytes, and records file metadata. No canonical hand, gesture, manifest, preset or preference is changed during preparation. Failure can leave empty parent directories; discarded or interrupted staging contains no active Undo journal.

`commitImport` requires the main queue, which is also where native Settings and ControlBridge writers run. Without an await or run-loop handoff, it checks the original allowlisted preferences, current catalog availability, canonical file identities and timestamps, removal recovery phases, presentation Undo directory, and staged file metadata. PresetsSettings also checks catalog artwork signatures without decoding newly changed images on main. A conflict rejects before the first canonical file or preference write. The user's accepted edit and prior journals remain unchanged.

Successful publication first atomically renames the fully serialized journal into Recovery. It then moves existing manifest/preset originals into staging and renames staged files into place. Preferences commit only after all file publications succeed. Staging cleanup runs off-main. Main-queue work is metadata, same-volume moves, at most 842 file publications, and the fixed allowlisted preference batch. It does no PNG decode, full artwork read, large journal encoding or file copy. Preview rejects more than 512 historical removal packages with instructions to retain backups and move completed packages aside, bounding recovery metadata checks too.

A publication failure restores moved originals by rename and marks the import journal restored. Preferences have not yet changed. If rollback itself fails, the full journal remains actionable through the existing recovery path. A fresh preview can retry after access is repaired. No recovery schema changed.

## Concurrency and process interruption guarantees

- Edits accepted by a native/control writer before final commit are compared with preview and preserved on rejection. Writers queued after commit run afterward. The import uses their existing main queue rather than a private lock those writers would ignore.
- Changes to matching artwork that import would leave untouched, omitted gesture slots for imported hands, manifest/presets, catalog availability, removal phases and the Undo directory invalidate the preview. Staged bytes are checked off-main, then their inode, size and nanosecond modification/change times are checked at commit.
- Separately prepared imports cannot overwrite an earlier import from the same original preview. A new Undo journal also invalidates import when preferences are identical.
- Process interruption before journal publication leaves only inert staging. After publication, the journal exists before every canonical mutation and records all file before/after bytes plus exact allowlisted preference snapshots. Existing recovery accepts partial file/preference application and retry. This is recoverable publication, not a filesystem-wide atomic commit or a sudden-power-loss guarantee.
- Arbitrary external processes are outside the app's main-queue serialization. Metadata detects their changes up to final validation. This does not claim an OS-wide lock against a hostile writer during the short synchronous publication interval.

## Local verification

Final command:

```sh
TINYHAND_DEFAULTS_SUITE=com.austinpresley.tinyhand.import-audit \
TH_HANDS_DIR=/tmp/import-audit-hands \
swift test --filter 'PresentationArchiveTests|HandRecoveryTests'
```

Passed 54 tests in 3 suites. The command compiles the app and test targets locally in Swift 5 mode. Final build/test output contains no warnings or errors. `git diff --check` passes.

Coverage includes both failed-before regressions, exact file/preference/removal-receipt preservation, preference edits during writes and after preparation, matching-artwork and omitted-gesture edits, manifest/preset races, removal during staging, legacy/interrupted/completed recovery ownership, catalog and recovery marker changes, modified staging, two prepared imports, another Undo journal with identical preferences, publication rollback, failed rollback and recovery retry, and partial file/preference application after a simulated interruption. Existing hand-removal Settings tests and the parent's override restoration tests pass.

Only isolated test defaults and temporary Hands fixtures were used. No normal preferences, actual Hands, untracked artwork, host profiles, hosted CI, UI automation, installs, signing, notarization, packaging, pushes or deliveries were used.

## Copy and glossary proposals

Preview conflict copy now says: "Hand <id> has pending removal recovery. Finish Undo Remove in Settings > Pointers before previewing this backup again."

Stale preview copy now says: "The library or settings changed after preview. Preview the backup again before importing. Nothing was replaced."

Possible glossary addition: "Prepared import" means validated backup bytes staged locally with a frozen preview context. It has no user-visible effect until main-queue validation and publication succeed. No central glossary or status documents were edited.

## Parent acceptance checks

The implementation and focused regressions are complete. Parent owns integrated UI validation, builds for distribution and packaging.

1. In an isolated app instance, run the older-backup/newer-gesture/removal sequence. Verify the preview names the hand and points to Undo Remove. Cancel/reject must leave the removal Undo available. Undo Remove should restore the newer gesture and override state.
2. Use a large valid backup while editing size or another supported preference from native Settings and local control. Settings/control should stay responsive through validation and staging. Import must reject the stale preview and retain the accepted edit.
3. Verify successful import and Undo Import after restarting the isolated app, plus recovery after an interrupted publication. Confirm existing hotkeys, startup, activation, Interact and Stream Deck profiles remain unchanged.
4. Check the conflict and stale-preview messages in light/dark Presets preview at supported window sizes. No layout changed in this fix.
