# Recoverable hand settings integration

The S-040 receipt now stores a strictly validated S-042 override snapshot for its
own pointer ID. An empty snapshot restores inheritance. Undo merges that one ID
into the current archive and leaves other pointers' later changes intact.
Existing receipts without a configuration payload keep their earlier behavior.

Removal validates the configuration archive before changing files. Saved
overrides stay retained while an ID is absent. Undo validates and encodes the
restored archive before restoring artwork, so corrupt or mismatched payloads do
not partly restore a hand. The encoded archive and pin/enable changes apply in
the same preference notification batch.

The first integration regressions failed with five expectations before the hook.
The local log is `/tmp/lhp-review-recovery-overrides-red.log`. The corrected
HandRemovalSettingsTests pass using the isolated test runner. A separate mismatch
test checks that a receipt cannot replace another pointer's settings.

Screenshot result visual checks can opt into `TH_FOCUS_CAPTURE_RESULT=1` together
with test mode. This makes only the result window key for certified native
snapshots. Normal results remain nonactivating and do not take keyboard focus.
