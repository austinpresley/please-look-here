# Look Here Please validation

## Native Settings redesign, 18 November 2026

The approved third design pass is implemented natively in the current working
checkout. The isolated signed Review app is version 1.2.0, build 20261118005910,
with bundled Stream Deck plugin 1.1.0.0. The normal installed app and normal
preferences/grants were not replaced. Changes remain uncommitted; no push or PR.

- `bash scripts/run-tests.sh`: 400 tests in 53 suites passed. The new Settings
  tests cover collapsed sections with saved assignments, explicit links, legacy
  routes, every save/copy transition, actual native control mounting, typed hand
  names during valid image loading, and cancellation of a recorder on collapse.
- After the final navigation/layout adjustments, the focused Settings and
  ShortcutNavigation suites passed 13 tests; local grid lints passed.
- `python3 scripts/verify-settings-redesign.py`: 54 live checks passed against
  the packaged release executable in a disposable test bundle/domain. All seven
  groups were closed and no recorders mounted on normal visits in both themes.
  Expanding all groups mounted all 26 native destinations. A practice link opened
  only Tool keys; returning to the page reset it to closed.
- 40 app-owned active-window captures cover all seven pages, the three Tools
  panes, every shortcut group separately, all-open and linked states, Customize
  and New Hand in light/dark. All associated layout checks passed. The script
  keeps the headless display awake during capture; it does not bypass locks.
- Visual QA corrected the native menu image intrinsic size that widened Pointers,
  kept full sidebar/direction labels visible, and verified the complete gesture
  sheet and sound preview controls.
- The original populated-preset verification loop exceeded its control deadline
  because metadata edits invalidated all artwork caches. Preset-only edits now
  retain artwork; import/restore still invalidates changed artwork. The original
  populated loop passed after this correction.
- `PATH="$PWD/.build/settings-packaging-venv/bin:$PATH" bash
  scripts/build-review.sh --package-only`: universal arm64/x86_64 build,
  Developer ID signing, notarization, stapling, Gatekeeper, exact ZIP extraction
  and bundled plugin contract verification passed. Pillow was installed only in
  that project-local environment for the existing icon generation script.
- App notarization: `ec541652-397d-4885-87f3-0da13b656059`.
- Evidence: `dist/verification/settings-implementation/validation.json`,
  `tests-final.log`, `tests-focused-final.log`, `package-final.log`,
  `native-results.json`, and `native/`. The finished gallery is
  `design/settings-redesign/native-review/settings-native-review.html`.

No hosted CI was created, enabled or dispatched. This is an isolated review
build, not a public update or replacement of the normal app.


## Quick controls v9 semantic item roles, 17 November 2026

`CODE-REVIEW-7.md`'s P2 is fixed on `feature/radial-quick-controls-v9`.
Changes remain uncommitted. This section supersedes the round 6 package below.

Every item now requires a semantic role. The catalog assigns root-command kind,
pointer favorite identity, ink, tool, More-command kind, Back or All pointers.
Artwork, tinting, hub artwork, ON/OFF badges, selected checks, submenu cues,
optical offsets, list row state and accessibility labels/state use those roles.
Current-state refresh and history availability also use roles; history still
validates the fixed level/slot and request operation. Press and AX identities
include role alongside level/slot/ID, with AX generation/epoch validation retained.
Practice's Pen lookup now uses its tool role. The whole-change audit found no
remaining production item-ID literal comparisons or ID switches. Data lookup and
slot-identity validation remain ID-based.

Two new regression methods cover 26 wheel/list collision cases. Both cover
`pointer`, `color`, `draw`, `interact`, `clear`, `undo`, `redo`, `screenshot`,
`more`, `all` and `back`; the wheel also covers `match`, `sound`, `mute` and
`toolbar`. Tests exercise the real catalog/session, measured geometry, artwork,
native list cells and AX elements, including selected/unselected missing entries
and rejected activation. Reserved `all`/`back` storage/archive rejection remains
unchanged; those IDs are also injected at the session boundary. The pre-fix run
failed with **21 issues**. Before sources, the exact red test source, `red.log`,
focused green output and the repair diff are retained under
`dist/verification/radial-v9/review7/`.

Two complete `scripts/run-tests.sh` runs pass **393 tests in 52 suites**, the
Python package contract and all **20 grid checks** each. Swift test times are
**93.153** and **84.193 seconds**. No compiler warnings. `test-results.json`
records both runs. `git diff --check` passes.

The snapshot harness now settles initial accessory-app activation and drains
asynchronous focus restoration after fixture closure. Its stale recovery
assertion now checks that the relinquished wheel closes when recovery returns
the original restoration token, matching the existing focus tests. The retained
initial snapshot failures are separate from the collision red evidence. No
measured snapshot state is retried.

The complete pre-fix and final-package `scripts/snapshot-radial.py` matrices
both pass **206 snapshots**. All 206 normalized layout/state reports match;
all **144** wheel/list measured item and panel frames match exactly. **179**
images are pixel-identical. The remaining 27 differ by at most 13/255 in any
channel and less than 0.034/255 mean channel intensity. Visual inspection of
`normal-states-contact-sheet.png` confirms unchanged artwork, badges, child
positions, hub labels and Back arrows in light/dark. Normal and short scrolling
lists retain their labels, checks and keyboard outlines. Material, opaque,
contrast and Reduce Motion states pass. See `snapshot-comparison.json`,
`snapshots-before-final.log`, `snapshots-after.log` and `snapshot-before/`.

`scripts/build-review.sh --package-only` produced universal arm64/x86_64 Review
**1.2.0 (20261117022832)**, bundle ID
`com.austinpresley.pleaselookhere.review`. App notarization is Accepted,
receipt `886b0fe5-795b-492a-aa3c-356e93f2d251`; plugin 1.1.0.0 is Accepted,
receipt `ba8a3b7e-5722-43f1-b6ae-7b3ff91ad7dd`. Deep/strict signing,
secure timestamps, stapling, Gatekeeper, ZIP integrity, extracted-app checks
and the bundled installer contract passed. No compiler warnings. See `package.log`
and `package-result.json`. Archive: `dist/Look Here Please Review-review.zip`.
SHA-256: `94bef7f4e9e9969f98eeffce4a1877fa931af9865ff10bbe65201023075553ce`.

All **177** packaged source/test/script hashes match `build-source-manifest.json`.
Root PNGs, research files and assets retain their pre-fix bytes; the regenerated
`assets/Assets.car` was restored from its exact pre-build copy. A concurrent
change to unrelated `design/s024/BRAND.md` is recorded in
`concurrent-protected-changes.json` and was left untouched. No hosted CI,
live-smoke, posted native input, normal-app/prefs/grant changes, installation,
commits, pushes, PRs, delegation or external delivery. The package remains in
`dist` for local handoff.

## Quick controls v9 round 6 fixes and deterministic tests, 17 November 2026

All requests in `design/radial-redesign/grades/CODE-REVIEW-6.md` are addressed
on `feature/radial-quick-controls-v9`. Changes remain uncommitted. This section
supersedes the round 5 package below.

Held release and click now validate native focus before moving selection or
executing a command. The check covers both key-window loss and app deactivation
before notification delivery. Command-Tab revokes keyboard-owned Hold input and
its queued generation synchronously, while claimed pairs still drain. App resign
and external-activation observers require prior keyboard ownership. Pointer-only
Hold remains usable with another app frontmost, including external activation.
Explicit recovery transfers retain their separate focus owner.

History availability updates only root Clear at slot 3, root Undo at slot 6,
and More Redo at stored slot 0, validating each ID and request operation.
Missing favorites named `clear`, `undo` and `redo` retain their disabled state.
The identity audit also changed pointer press matching to level, slot and ID,
and command preparation to the validated request operation. AX already validates
generation, level, slot and ID; catalog refresh and pointer lookup already use
specific levels. Reserved Back/browser IDs remain rejected in favorites.
The older annotation test now uses the real catalog and its actual history slots.

Settings takes the wheel's original restoration token through AppDelegate,
without restoring or recapturing focus during opening. Settings owns the token
until closure, clears ownership before restoring, retains the first obligation
across repeated shows, and consumes it once. The delayed-activation regression
uses the production AppDelegate callback and an injected Settings focus driver.

Nine new regression methods cover 18 cases. Retained red evidence under
`dist/verification/radial-v9/review6/` includes `red.log` with 19 issues,
`flake-replay-red.log` with five, `active-red.log` with four, and
`identity-red.log` with three. Each behavior fix has a failing pre-fix assertion.
The focused green run and before/red/after source copies are retained there.
All constructed input is unposted; focus operations are recorded in memory.

The reviewer's two issues were both in
`LifecycleTests.nativePressReleasedOverOurOwnUIStopsBlockingGestures`, at its
initial and final gesture-availability assertions. The original failure dump
contains a desktop menu rectangle `(938, 30, 352, 149)` in `menuRects`.
`activate`/`tick` sampled global popup windows through
`CGWindowListCopyWindowInfo`, so another app's menu changed this test's
preconditions. It was ambient desktop state, rather than pair-drain timing.
Replaying that exact rectangle through an injected menu source reproduced both
assertions. The fixture now supplies an empty menu source; production retains
the native sampler. A separate positive regression verifies that a sampled
external menu still blocks gestures. `reviewer-flake.json` records the original
review thread/item, failed lines and relevant dump values.

Three consecutive complete `scripts/run-tests.sh` runs pass **391 tests in
51 suites**, the Python package contract and all **20 grid checks** each.
Swift test times are **81.243**, **81.715** and **80.867 seconds**. No compiler
warnings. Logs are `tests-run1.log`, `tests-run2.log` and `tests-run3.log`;
`test-results.json` records zero exit status for all three. The earlier broader
pre-audit run also passed 389 tests. `git diff --check` passes.

`scripts/build-review.sh --package-only` produced universal arm64/x86_64 Review
**1.2.0 (20261117020207)**, bundle ID
`com.austinpresley.pleaselookhere.review`. App notarization is Accepted,
receipt `4e9f3958-049b-4ffe-a499-81b36a5dbe39`. Bundled plugin 1.1.0.0
is also Accepted, receipt `b5416756-5d25-4a76-826e-826c236316fd`.
Deep/strict signing, secure timestamps, stapling, Gatekeeper, ZIP integrity,
extracted-app verification and the bundled installer contract passed. No compiler
warnings. Packaging used the existing local Pillow environment at
`~/Library/Caches/look-here-please-build-python`. Log: `package.log`.
Archive: `dist/Look Here Please Review-review.zip`, SHA-256
`3e8aaeffd9493f54e924ce8bc49116e5457c9b2b36ae289021efd993ddab5132`.

All **177** files in `build-source-manifest.json` match the tested and packaged
source/test/script tree. All **441** protected root PNG, research and design
files match their pre-fix hashes. Packaging's regenerated `assets/Assets.car`
was restored from its exact pre-build copy; all asset hashes match.
`package-result.json` and `validation.json` record these checks and receipts.
No layout changed. No hosted CI, live-smoke, posted native input, normal-app,
prefs or grant changes, installation, commits, pushes, PRs, delegation or
external delivery. The Review app and archive remain in `dist` for local handoff.

## Quick controls v9 focus, recovery and AX fixes, 17 November 2026

All three findings in `design/radial-redesign/grades/CODE-REVIEW-5.md` are fixed
on `feature/radial-quick-controls-v9`. Changes remain uncommitted. This section
supersedes round 4's ordinary-deactivation recovery behavior below.

Unexpected key-window loss, app deactivation or activation of another app now
cancels Quick controls without restoring the saved app/window/responder.
Command-Tab revokes input ownership synchronously and stays a native pair.
Workspace Space/session changes, sleep and the existing distributed lock and
screensaver notifications use the same cancellation path. Mission Control is
covered through observable key/activation/Space changes; no live Mission Control
or screen-lock test was performed. System stop/recovery cancels the wheel before
ordinary overlay cleanup. Claimed key repeats/releases and mouse releases still
drain. An ownership generation rejects queued input after closure or revocation,
including when another session has opened. Activation also checks the injected
native focus owner before executing a key, pointer-up or AX item activation.

Recovery's expected key handoff retains its token and remains usable. If focus
later leaves recovery, the old wheel closes without restoring or taking that
token back. Browser handoff and delayed cancellation retain their round-4
behavior. Ordinary deactivation and Pointer Off preserve Clear recovery and its
Undo. Only `AppDelegate.applicationWillTerminate` explicitly dismisses recovery
before teardown, including when the pointer is already inactive.

AX identities now contain the frozen slot, ID, session generation and level.
Press and focus validate that exact live slot; a disabled missing `all` cannot
activate the All pointers browser item. Favorites storage, assignment and archive
validation reject reserved IDs `all` and `back`, including named preset imports.
Missing nonreserved pointer IDs remain valid frozen favorites.

Five regressions, with 14 cases, ran before the behavior fixes and failed with
**89 issues**. They cover eight focus-loss routes with queued Clear and owned
key/mouse pairs, recovery Undo after active/inactive Off, duplicate AX IDs,
reserved IDs in storage/assignment/setup/preset imports, and queued activation
against a replacement input session. A further recovery-handoff regression
caught **two issues** in the first fix and now passes. Another check proves a
queued activation samples native focus before the resign notification arrives.
All seven new regressions have 16 cases. Two older drainage tests now deliver
navigation while ownership is live, then verify repeats/releases after closure;
the new generation regression requires undelivered activation to be rejected.
Focus drivers record operations in memory; constructed input is never posted.

Final `scripts/run-tests.sh` passes **382 tests in 51 suites** in **79.486
seconds**, the Python package contract and all **20 grid checks**. No compiler
warnings; `git diff --check` passes. The initial full run exposed the two older
queue-order expectations described above. Logs and before/red/after source copies
are under `dist/verification/radial-v9/review5/`: `red.log`, `handoff-red.log`,
`green.log`, `tests-attempt1.log` and `tests-final.log`.

`scripts/build-review.sh --package-only` produced universal arm64/x86_64 Review
**1.2.0 (20261117012841)**, bundle ID
`com.austinpresley.pleaselookhere.review`. App notarization is Accepted,
receipt `f05ae9d4-afb0-4f9f-9ae9-7d7ecc560c94`. Bundled plugin 1.1.0.0 is
also Accepted, receipt `d361b6fb-8d0b-4a6d-b598-c99a17de3ab6`. Deep/strict
signing, secure timestamps, stapling, Gatekeeper, ZIP integrity, extracted-app
verification and the bundled installer contract passed. No compiler warnings.
The first packaging attempt stopped at icon generation because default Python
lacked Pillow. The successful retry used the existing local environment at
`~/Library/Caches/look-here-please-build-python`; no dependency or system Python
change was needed. Logs: `package-initial.log` and `package.log`. Archive:
`dist/Look Here Please Review-review.zip`, SHA-256
`a147bdda0c671c9d5f3a2c554f298c76336c93510e6a46991071943db8b5e366`.

All **177** files in `build-source-manifest.json` match the tested and
packaged source/test/script tree. `validation.json` records the results and
receipts. Root PNGs and `docs/research/*` match their pre-fix hashes. Concurrent
changes under unrelated `design/brand-refresh/` belong to other work and were
left alone. No design file was written by this task. Packaging's regenerated
CAR, ICNS and menu icon PNGs were restored from exact pre-build copies.

No layout changed. No hosted CI, live-smoke, posted native input, normal app,
prefs or grant changes, installation, commits, pushes, PRs, delegation or external
delivery. The Review app and archive remain in `dist` for this local handoff.

## Quick controls v9 browser handoff and quit fixes, 17 November 2026

Both P2 findings in `design/radial-redesign/grades/CODE-REVIEW-4.md` are fixed
on `feature/radial-quick-controls-v9`. Work remains uncommitted. This package
supersedes the repeated recovery handoff package below.

All pointers now takes the wheel's original restoration token before closing
the wheel. The pending browser handoff owns that token through input drainage,
then transfers it into PointerBrowser without restoring or capturing another
context. Pending replacements retain the first obligation, as recovery does.
Cancellation clears the task and owner before restoring; browser closure clears
its owner before consuming the token. Repeated cancellation/closure is inert.
Direct browser opening still captures a context when it has no inherited token.

Termination explicitly dismisses Clear recovery before stopping the control
server, unregistering hotkeys or deactivating the overlay. Deactivation also
dismisses recovery before its already-inactive guard. The transferred token is
consumed once before teardown; later dismissal, revision/capture updates and
repeated termination cannot reactivate the saved app or responder.

Three new regressions, with five cases, failed before these fixes with **30
failed expectations**. Only injectable browser focus and AppDelegate construction
were added for the red run; wheel handoff and termination behavior were unchanged.
The delayed-activation browser test caught early restoration, recapture and
restoration to the wheel instead of the original app/window/responder. Cancellation
tests cover pending-task cancellation by capture and inactive deactivation. Quit
tests cover active and already-inactive overlays after the wheel transfers focus
to recovery and closes. They require one original-context restoration before
teardown, and no further activation during repeated cleanup. Focus operations
use an injected driver; constructed input is never posted natively.

Evidence is under `dist/verification/radial-v9/review4/`. `red.log` records the
failures; `green.log` passes **10 focus tests with 22 cases** in 9.253 seconds.
Final `scripts/run-tests.sh` passes **375 tests in 51 suites** in 76.246 seconds,
the Python package contract and all 20 grid checks. `tests-final.log` records
the final run. No compiler warnings; `git diff --check` passes. Before/red/after
source copies and `validation.json` retain the regression and build evidence.

`scripts/build-review.sh --package-only` produced universal arm64/x86_64 Review
**1.2.0 (20261117010052)**, bundle ID
`com.austinpresley.pleaselookhere.review`. App notarization is Accepted,
receipt `cc07ac92-4b9f-47c4-bf0e-9518b0ec4941`. Bundled plugin 1.1.0.0 is also
Accepted, receipt `3373e265-16c5-42c9-9b2f-02bbdf5b6ba5`. Deep/strict signing,
secure timestamps, stapling, Gatekeeper, ZIP integrity, extracted-app verification
and the bundled installer contract passed. No compiler warnings. Build log:
`package.log`. Archive: `dist/Look Here Please Review-review.zip`, SHA-256
`51774df0b81f9929ecd65d95db81857bc8a941adb56fb9d320b64d88681afac0`.

All 178 source/test/script files match the final validation manifest. All 246
protected root PNG, research and design files match their pre-fix hashes.
Packaging's regenerated icon assets were restored from exact pre-build copies.
No layout changed; no new live native-input or external-app activation evidence
is claimed. No hosted CI, live-smoke, posted native input, normal app/prefs/grant
changes, installation, commits, pushes, PRs, delegation or external delivery.
The Review app and archive remain in `dist` for this local implementation handoff.

## Quick controls v9 repeated recovery handoff fix, 17 November 2026

`CODE-REVIEW-3.md`'s remaining P1 is fixed on
`feature/radial-quick-controls-v9`. Changes remain uncommitted. This package
supersedes the earlier focus-ownership package below.

Clear recovery now calls `takingRestoration` on every valid focus handoff,
before checking `tookFocus`. Each wheel relinquishes its token and keyboard
ownership. Recovery adopts the returned token only when it has no existing
restoration obligation. Otherwise it retains the original token and drops the
later token without restoring it. The wheel has already cleared its reference,
so closing that session cannot restore the external app or steal Undo focus.

The handoff audit covered the panel shortcut and Edit-menu recovery routes,
wheel/list focus and close paths, pointer-browser opening, capture exclusion,
focus failure, invalidation and recovery completion. Both recovery routes share
`RadialMenu.focusRecovery`; no other transfer callback is gated on prior focus.
Browser opening closes the wheel before showing the browser. Existing recovery
completion paths clear ownership before consuming the original token.

Two regressions cover held and persistent controls, each with Undo and Dismiss
variants. They focus recovery in session 1, close the wheel, simulate focus
leaving, and reopen the wheel from a second context with a different window
and responder.
After refocusing recovery, refresh and trigger release or persistent close must
leave recovery focused with zero restoration calls. Undo/Dismiss must restore
the first context exactly once, including after repeated cleanup. The injected
driver records focus operations; constructed input is never posted natively.
All four cases failed before the fix with **36 failed expectations**, including
early restoration, wrong window/responder and two restores after completion.
The red log and before/after source copies are under
`dist/verification/radial-v9/refocus-*`.

The focused run passed **7 tests with 17 cases** in 7.680 seconds.
The complete `scripts/run-tests.sh` passed **372 tests in 51 suites** in
74.394 seconds, the Python package contract and all 20 grid checks. No compiler
warnings. Logs: `refocus-red.log`, `refocus-green.log` and
`refocus-tests-final.log` in the verification directory. `git diff --check` passes.

`scripts/build-review.sh --package-only` produced universal arm64/x86_64 Review
**1.2.0 (20261117004143)**, bundle ID
`com.austinpresley.pleaselookhere.review`. App notarization is Accepted,
receipt `56eae8ce-2906-4b50-9cb3-c3e139b718d1`. Bundled plugin 1.1.0.0 is
also Accepted, receipt `353683d3-1af7-4e22-9d65-6ad7779aa7f6`. Deep/strict
signing, secure timestamps, stapling, Gatekeeper, ZIP integrity, extraction and
the bundled installer contract passed. No compiler warnings. The initial attempt
stopped because system Python lacked Pillow; the successful retry used a
disposable local virtual environment. Logs: `refocus-package-initial.log` and
`refocus-package-final.log`. Archive: `dist/Look Here Please Review-review.zip`,
SHA-256 `d2ad0614368bfbcafef7dd7ab7efc5029f6760c9bad376e19f24bb555adee9af`.

All 178 source/test/script hashes match the tested and packaged tree. All
245 protected root PNG, research and design files match their pre-fix hashes.
Packaging's regenerated `assets/Assets.car` was restored from its exact pre-build
copy. `refocus-source.json`, `refocus-protected-files.json` and
`refocus-validation.json` retain these checks. No layout changed and no new
native-input or external-app activation test is claimed. No hosted CI,
live-smoke, posted native input, normal app/prefs/grant changes, installation,
commits, pushes, PRs, delegation or external delivery. This remains a local
implementation handoff; the Review app is packaged in `dist`.

## Quick controls v9 focus ownership fix, 17 November 2026

`CODE-REVIEW-2.md`'s remaining P1 is fixed on
`feature/radial-quick-controls-v9`. Changes remain uncommitted. This package
supersedes the earlier polish package below.

Quick controls saves the original app, window and first responder in one
consumable restoration obligation. The scoped Command-Shift-U route and the
Edit menu transfer that obligation to Clear recovery before focusing its panel.
The wheel relinquishes keyboard ownership and its restoration reference. Later
history refreshes cannot reclaim focus, and a queued wheel close cannot restore
the external app. Recovery consumes the transferred obligation when Undo,
Dismiss, revision invalidation, stale Undo rejection or capture hiding finishes.
Capture completion can reveal still-valid recovery without restoring twice or
reopening the wheel. Restoration clears ownership before invoking native focus
operations. A failed attempt to focus recovery also returns the original context.

`QuickControlsFocusTests.swift` adds five regressions with 13 parameter cases.
They construct real wheel/recovery panels and a fixture window/responder. An
injected focus driver records app activation/restoration without activating an
external app. The cases route constructed, unposted input through RadialInput's
main-queue callbacks, Tab into the wheel, and invoke the real panel equivalent
and OverlayController-installed recovery handler. Held release queues cancellation;
recovery retains focus through that close until its actual Undo button or Dismiss
finishes. Persistent controls, edits before queued cancellation, stale revision
rejection, and capture with/without intervening edits verify exactly one restore
to the original app/window/responder. The production responder test starts at the
actual panel's first responder and verifies Ink Undo/Redo plus Command-Z, rather
than assigning a standalone handler. It exposed NSWindow intercepting standard
selectors; AnnotationResponderPanel now forwards them to scoped annotation history.

All five tests failed against the pre-transfer behavior with only the injectable
focus seam present: **97 failed expectations**, including early external restore,
wrong recovery context, double restore and disconnected selector routing. Exact
pre-transfer/fixed source copies and logs are retained under
`dist/verification/radial-v9/`: `focus-red-final.log` and
`focus-green-final.log`. Restoring the fix passed all five tests in 7.280 seconds.
The complete `scripts/run-tests.sh` passed **370 tests in 51 suites** in 76.413
seconds, the Python package contract, and all 20 grid checks. No compiler warnings.
Full log: `focus-tests-final.log`. `git diff --check` passes.

`scripts/build-review.sh --package-only` produced universal arm64/x86_64 Review
**1.2.0 (20261117002652)**, bundle ID
`com.austinpresley.pleaselookhere.review`. App notarization is Accepted,
receipt `f6391802-f39f-4510-9303-c3d40722162e`. Bundled plugin 1.1.0.0 is
also Accepted, receipt `981a2749-cbb2-4277-a00f-10361f81d223`. Deep/strict
signing, secure timestamps, stapling, Gatekeeper, ZIP integrity, extraction and
the bundled installer contract passed. No compiler warnings. Build log:
`dist/verification/radial-v9/focus-package-final.log`.
Archive: `dist/Look Here Please Review-review.zip`, SHA-256
`4331423b005f5025bfcd7574accb25e1fbc799448c4c6555242fe197788fc3f7`.

All 178 source/test/script hashes match the tested and packaged tree. All
244 protected root PNG, research and design files match their pre-fix hashes.
Packaging's regenerated `assets/Assets.car` was restored from its exact pre-build
copy. `focus-source.json`, `focus-protected-files.json` and `focus-validation.json`
retain these checks. No visual layout changed; the prior native grade remains
historical evidence, and no new native-input or external-app activation test is
claimed. No hosted CI, live-smoke, posted native input, normal app/prefs/grant
changes, installation, commits, pushes, PRs, delegation or external delivery.

## Quick controls v9 release candidate polish, 17 November 2026

Claude accepted review-fix round 1. This follow-up implements the three P2
snapshot findings on `feature/radial-quick-controls-v9`, still uncommitted.
The package and snapshot identity recorded here replace the previous round's RC.

- Browser names use the actual 64-point label width, with no horizontal inset.
  Visible glyph bounds and direct per-line drawing avoid both excess side-bearing
  measurement and a second wrapping pass. Gingerbread's ink is 63.45 points wide
  at 11 pt, so it stays on one line. Presentation uses the English hyphenation
  dictionary and reads `Presenta-` / `tion pointer`. Explicit soft hyphens take
  precedence and disappear when no break is needed. Unknown words break only at
  composed characters, with a visible hyphen. The two-line limit, 11/14 pt type,
  ellipsis policy and full footer, tooltip and AX name are preserved.
- Clear and the command-error HUD share `QuickRecoverySurface` and
  `QuickRecoveryButton`. The error card has 12-point corners, matching material,
  transparency/contrast fallback and palette, a 13-point semibold title and
  12-point secondary reason. Primary actions are 28 points high, using
  `#FF9589` / `#302736` in dark and `#B6423B` / white in light. Dismiss is a
  28-by-28-point cross with AX name "Dismiss". Error persistence, announcement
  deduplication and nonactivating appearance are unchanged.
- Undo, Clear Dismiss and both error buttons share a 2-point system-blue keyboard
  ring over a contrasting 4-point halo, or 5 points with Increase Contrast. The
  ring sits 3 points outside the fill. It appears only for the key window's actual
  first responder. Existing Clear recovery focus/return behavior is preserved.
  New appearance fixtures select Dismiss directly, without depending on Full
  Keyboard Access preferences or posting native input.

`scripts/run-tests.sh` passed **365 tests in 50 suites** in 72.592 seconds,
plus the Python package contract and all 20 layout lints. No compiler warnings
were emitted. The new name regression first failed all seven assertions against
the old implementation. Logs are `dist/verification/radial-v9/polish-red.log` and
`polish-tests-final.log` in that directory.

`scripts/build-review.sh --package-only` built universal arm64/x86_64 Review
**1.2.0 (20261117000204)**, bundle ID
`com.austinpresley.pleaselookhere.review`. App notarization is Accepted,
receipt `4f6c5ff1-57ea-4e4b-a397-f8c416a35840`. Bundled plugin 1.1.0.0 is also
notarized, receipt `302f234b-0424-4652-9629-e086cf3316a8`. Deep/strict signing,
secure timestamps, stapling, Gatekeeper, ZIP integrity, extraction and the bundled
installer contract passed locally. The build emitted no compiler warnings.
Log: `dist/verification/radial-v9/polish-package-final.log`.
Archive: `dist/Look Here Please Review-review.zip`, SHA-256
`7ed137cf8918aa081c434f91801a18404b5b5b67cab0e1687bca99cac023a4ac`.
Packaging's regenerated `assets/Assets.car` was restored from its exact clean
pre-build copy. No installed app was replaced or launched by packaging.

The exact notarized app passed the full **206-state** snapshot matrix, comprising
144 wheel/list states, 42 browser/editor states, eight error HUD states, ten Clear
recovery states and two exclusion witnesses. Each PNG has adjacent state/layout
JSON. Log: `dist/verification/radial-v9/polish-snapshots-final.log`; all paths are in
that directory's `manifest.json`.

Forty-two affected browser/HUD/recovery images were visually inspected in native
size light/dark pairs. The final package's 62 quick-surface images were also
compared against the preview: 51 are pixel-identical; all 11 changed browser images
were reinspected. Browser long names fit at wide, narrow/tall, narrow, short/wide
and minimum short sizes. HUD title/reason/action/cross are readable in both themes.
Every recovery/error button shows a blue ring with a contrasting halo on explicit
focus, separated from the fill. Nonfocused appearance has no ring. Fixture checks
confirm nonactivating error appearance and Clear focus return after Undo/Dismiss.
Final comparison sheets are in `dist/verification/radial-v9/polish-rc-contact-sheets/`;
`polish-inspection.json` records observations, pixel comparisons and artifact identity.

All 176 source/test/script hashes still match the final tested and packaged tree.
All 242 protected root PNG, research and design files match their pre-polish hashes.
The records are `polish-source.json` and `polish-protected-files.json` in the same
verification directory. `git diff --check` passes. No hosted CI, live-smoke,
posted native input, normal app/prefs/grant changes, commits, pushes, PRs,
delegation or external delivery occurred. The user requested a local sub-agent
handoff; the Review app remains packaged in `dist` and is not installed.

## Quick controls v9 review fixes, 16 November 2026

Branch `feature/radial-quick-controls-v9`. The implementation remains uncommitted,
pending Claude's acceptance of S-054. Both `CODE-REVIEW-1.md` and
`NATIVE-GRADE-1.md` were read in full. All six requested fixes were accepted.

### Findings and implementation

- Persistent opening goes through `InputTap.openQuickControls`. It installs and
  enables the shared connection before RadialInput can enqueue an opening event,
  including when Hold is unassigned. Failed installation/enable never opens a
  session. OverlayController uses the existing permission-recovery path.
- RadialSession has a unique generation. Each AX element captures that generation,
  level and item ID, validates against the live session and resolves the ID again
  before activation or focus. Level changes and reset invalidate retained elements
  and clear both children arrays. List AX frames use actual table-to-view geometry
  after clip-view movement and layout, including keyboard autoscroll. Off-viewport
  elements are hidden and omitted from AXVisibleChildren.
- AnnotationUndoResponder handles Undo/Redo selectors and Command-Z/Shift-Command-Z
  within the wheel, list and recovery responder chains. Search field editors keep
  their text undo; external Interact input remains native. Draw's existing scoped
  shortcuts are unchanged. Command-Shift-U, also in Edit > Focus Clear Recovery,
  explicitly focuses valid recovery. Appearance keeps prior focus; Undo/Dismiss
  restore the prior visible key window and responder. Recovery does not retain a
  visible focus ring when reopened without keyboard focus. Input routing gives the
  focused recovery native keys and its own mouse region while retaining outside
  dismissal-pair ownership.
- Screenshot closes the wheel, list and browser, cancels pending browser handoff,
  retains exclusion IDs and drains owned input pairs. It restores only a still-valid
  Clear revision. Capture completion cannot reopen a browser or controls session.
- QuickCommandResult preserves bridge rejection reasons. A persistent,
  nonactivating error HUD presents the reason, a recovery action and Dismiss.
  A distinct visible failure announces once. Accessibility and Screen Recording
  actions open their named Settings pages. File-write errors offer Choose Folder;
  capture timeouts/encoding/display errors offer Retry Screenshot. Successful
  command feedback remains transient. Quick-controls capture errors use this same
  HUD; the ordinary Screenshot result behavior is preserved.
- Browser cells wrap oversized words at measured character boundaries within two
  lines at 11/14 pt. Type never shrinks. Presentation pointer fits, with the full
  name retained in the footer, tooltip and AX label.

### Local tests and packaging

`QuickControlsReviewTests.swift` adds 13 regression tests across three suites.
Coverage includes fresh InputTap installation/enable ordering and failure, outside
press/release drainage, stale AX generation/level/reset and focus, actual list
clip geometry and visible children through keyboard/programmatic scrolling,
responder-chain Undo and standard equivalents, search-field preservation,
external Interact Command-Z, held-focus/recovery routing, capture shutdown with
both key and mouse pairs, error persistence/announcement/recovery mapping and
measured long names. The existing capture test now requires session closure.

The retained red run reproduces stale AX press actions and children surviving
reset: `dist/verification/radial-v9/review-fixes-red.log`.
The final `scripts/run-tests.sh` passed **364 tests in 50 suites** in 72.446 s,
plus the Python Stream Deck package test and 20 grid checks. No compiler warnings
were emitted. The exact final-tree log is
`dist/verification/radial-v9/review-fixes-tests-final.log`. `git diff --check` passes.

The final `scripts/build-review.sh --package-only` built universal arm64/x86_64
Review **1.2.0 (20261116234426)**, bundle ID
`com.austinpresley.pleaselookhere.review`. App notarization is Accepted,
receipt `459fad8f-3218-44bd-8339-9d24d8306fd5`. The bundled plugin 1.1.0.0 is also
notarized, receipt `3f2779b6-d265-4aa1-8fe0-8702ce267d6d`. Deep/strict signing,
stapling, Gatekeeper, ZIP integrity, extraction and the exact bundled installer
contract passed locally. Log:
`dist/verification/radial-v9/review-fixes-package-final.log`.
The archive is `dist/Look Here Please Review-review.zip`, SHA-256
`b8dbebe429c6ec2e479a686cb614cfaf34fd84510ad59e725ea4483dc8872739`.

The earlier package receipt in `review-fixes-package.log` predates the last AX
visible-children update and is superseded by this final package. The final binary
contains that setter. `review-fixes-source.json` records 149 source/test/script
hashes, all rechecked unchanged after packaging and snapshots. Packaging regenerated
`assets/Assets.car`; its initially clean tracked copy was restored to avoid a
compiled-asset-only source diff. No installed app was replaced.

### Snapshots and visual inspection

The matrix uses only the isolated Review bundle, a disposable defaults suite,
temporary hand/cache paths and process-local Accessibility denial. It does not
post native input or request capture permission. The command-error rejection
fixture activates a real wheel command and receives the actual ControlBridge
Accessibility rejection. Recovery fixtures invoke the real scoped equivalent
handler directly and check actual focus return after Undo/Dismiss. Exclusion
fixtures require both browser and controls to remain closed after restoration.

Early snapshot runs exposed compositor timing in the fixtures and the diagnostic
witness hiding on deactivation. They were corrected with settling intervals and a
witness that remains visible when focus returns. They are not counted as passing
matrix runs. Visual inspection also caught the stale recovery focus ring, which
was fixed before final snapshots.

The final run captured the **exact notarized Review app** and passed **198
states**: 144 wheel/list images, 42 browser/editor images, four error HUD images,
six recovery images and two exclusion witnesses, with adjacent state/layout JSON.
All 7,712 measured wheel corners pass sector and outer-clearance checks. The log
is `dist/verification/radial-v9/review-fixes-snapshots-final.log`; `manifest.json`
indexes the final matrix.

All 54 affected images were inspected in light/dark pairs. Forty-two final images
are pixel-identical to the already inspected previews; the 12 changed images were
inspected again. The final 27 comparison sheets are in
`dist/verification/radial-v9/review-fixes-rc-contact-sheets/`.
`review-fixes-inspection.json` records the observations and artifact identity;
`review-fixes-visual-checks.json` records corner checks and pixel comparisons.
Browser names and footer copy are legible at every tested width/height. Error
reasons/actions are readable in both themes and do not take focus. Recovery has
no ring on appearance, a visible Undo ring on explicit focus and verified return
to the prior wheel/list key window. The short list's bottom selection remains
inside its scroll viewport. Diagnostic witnesses report closed controls/browser
and retained recovery, without claiming real screen-capture output.

### Limits and preservation

No hosted CI, live-smoke, posted native input, normal installed-app access,
normal preference/grant changes, commits, pushes, PRs or delegation. Root artwork,
`docs/research/*` and unrelated design files were left alone. Package-only mode
keeps the installed app unchanged. This is a local implementation handoff for
Claude's release acceptance.

The snapshots prove app-owned visibility, layout and focus state. Exclusion
images are labelled diagnostic witnesses, not desktop captures. Real saved/copied
captures, actual event-tap/TCC behavior, external-app focus restoration, spoken
VoiceOver, Full Keyboard Access/Voice Control, physical mouse/trackpad input,
multiple displays/mixed scales, native 2×, Intel/older macOS runtime and material
contrast over busy content remain manual acceptance gates. Automated unit events
are constructed and routed directly, never posted into the native input stream.

## Coordinator final review and delivery, 10 November 2026

All eleven requested areas have implementation and local evidence. The coordinator
accepted S-023's native control/state/routing/keyboard/AX checks and S-024's icon,
branding, packaging and publication checks. Those stories are now done. S-013
remains implemented/review for the unresolved historical reopen issue and manual
review. S-020/S-021 remain implemented/review for physical Stream Deck and actual
host-inspector acceptance. Passing bounded replays does not close those gaps.

The final combined app 1.0.2 build 20261110224547 is installed and normally running,
with the accepted menu bar and completed softer-shadow sources together. Plugin
1.0.3.2 is installed. Reviewed final local evidence includes 104 tests in 15 suites,
seven grid lints, package checks, 25 controls plus four denied checks, 32 radial
plus four denied checks, 13 native regressions and 66/66 relevant Deck replays.
Actual light/dark UI, icon appearances, native Finder/Dock-service icon and final
About were reviewed. Broader physical, VoiceOver, multi-display, older OS and Intel
runtime coverage is not claimed.

Fresh coordinator checks confirmed the installed version/build, normal state,
Contact shadow, both grants and absence of test capabilities. Deep/strict signing
passed. App ZIP, plugin and branding SHA-256 values match the final child's handoff.
The icon source/build inputs and extracted app's packaged icon agree. All reviewed
functional code remains local; only 11 curated presentation paths are published
on GitHub at 7017192888053ec37bcc96fc4b4cdeb92c4213b9. The coordinator shortened the
live repository description to "A playful native Mac pointer utility by Austin
Presley. Point it out." The homepage remains cleared. Actions is disabled and both
inherited workflows are disabled_manually. No hosted run or public binary release
was performed.

The app ZIP, plugin installer, branding ZIP and default icon were uploaded with
agent-deliver using request ID look-here-please-controls-build-20261110224547.
Delivery 20261111T041104Z--8de0779bf7b7 returned state delivered and a verified
[Austin Deliveries folder](https://drive.google.com/drive/folders/12u7hvtX73uec-qABMkIQN8kuK8eiDmCn).
Original preferences, custom hands, existing profiles/keys and grants remain
preserved. Earlier child artifacts are unchanged. No implementation agent remains
active. The backlog records the remaining review work without marking it done.
The final backlog snapshot is also [delivered](https://drive.google.com/drive/folders/1LBenJPCDC-yFoGMKDc8q_YhY_9LkDnP3),
delivery 20261111T041359Z--21f0d66ade51. It records acceptance of the S-021
fixed-key correction while leaving its hardware and host-inspector checks open.

## S-024 branding and final combined build, 10 November 2026

Outcome: implemented/review, with parent review and Austin Deliveries upload still
pending. Only S-024 branding and final combined validation were performed. No
subagents, local staging/commit/reset/restore/clean/switch, PR, public binary
release, Pages deployment or upload. Local HEAD is unchanged. Evidence and exact
handoff are in `dist/verification/s024/`.

### Identity and source boundary

Recorded doing, three icon concepts, chosen direction, owned links and UX before
code. The original pointing glove reaches toward an attention dot on coral, with
a plum cuff. Dark keeps a cream glove on plum. Icon Composer owns the mask,
glass, lighting and tinted/clear appearances. No SF Symbol or donor glyph is used
in the identity. Menu symbols reuse the filled geometry with a hollow/filled dot.
All 1x/2x/3x template PNGs are regenerated. `make-icons.py` compiles CAR/ICNS;
`build-review.sh` now runs it after the plugin leaf and before app assembly.
Python needs Pillow, plus librsvg and Xcode Icon Composer. This task used a local
virtual environment and installed librsvg locally. No runtime dependency changed. The verified build-generated CAR was copied back
to the shared generated asset; its bytes match the final package.

About now says By Austin Presley and links to the verified owned repository.
TinyHand by Kamran Ahmed remains explicit, and LICENSE is byte-identical. Bundle
copyright identifies Austin and the upstream origin. README/banner/logo and the
former upstream index and referenced marks/social image now identify this product.
Upstream analytics, social identity, canonical domain and download/release lookup
were removed from that index. Old unreferenced demo/hand/stock assets remain for
history and app use; they are not linked as this fork's identity or download.

The build source is the frozen combined checkout, not S-023's isolated candidate.
All four completed shadow files match this task's starting hashes. Accepted S-023
menu/input modules and the rest of the functional source are preserved. Only
About copy/links, copyright and branding/build inputs changed. Plugin 1.0.3.2
changes only plugin/category identity PNGs and its version. Existing action IDs,
profiles, inspectors, observed key art and behavior remain unchanged. The leaf
copies those PNGs after its existing renderer; all PNGs are in its source contract.

### GitHub publication

Owned repository: https://github.com/austinpresley/please-look-here

Curated main commit: `7017192888053ec37bcc96fc4b4cdeb92c4213b9`. Parent `c5fb36b7c4d7c87480958872a724b30a52427a47`.
Only the 11 files in `publish-files.json` changed remotely, preserving all other
remote files and ancestry with a fresh tree and non-force ref update. No dirty
functional source was published. The default branch still contains earlier
functional code; README, status doc and index state this explicitly.

Description is Look Here Please by Austin Presley. A playful Mac pointer utility;
expanded app in local review. Branding-only publication, based on TinyHand.
Homepage is cleared. Pages GET returned 404; no owned site/domain or release URL
is invented. All 15 published references passed local existence/exact remote tree
or HTTP 200 checks. T3 preview inspected the live heading, description, README and
loaded banner. Its snapshot calls timed out, so T3 html_preview rendered the local
page in light and dark; screenshots are saved locally.

Actions was disabled before and between publishing writes and remains disabled.
GitHub automatically indexed the two inherited workflow files after the commit;
this task explicitly disabled both, now disabled_manually. There are zero runs.
No workflow file, default branch, repository name or fork relationship changed.

### Local validation and native review

- Frozen combined `scripts/run-tests.sh`: 104 tests / 15 suites, package-contract
  test and seven grid lints. No compiler warnings in final test or build logs.
- Native controls: 25 checks; injected denial: 4. Exact-suite LaunchServices and
  public-fixture focus/bounds guards apply. Existing-owner repeats, More AX reply,
  live automation under menu tracking, tool/chooser/history/capture and toolbar
  hiding checks pass. Keyboard Tab/Space/arrows/Escape passed separately, with
  AppleKeyboardUIMode temporarily 2 and restored to original 0.
- Full radial: 32 named checks, 35 diagnostic rows and 33 sampled openings;
  denial: 4; existing native regressions: 13. No source fix or intermittent-reopen
  closure is claimed. Six generated radial layout reports pass.
- Relevant new plugin replay: 66/66 checks, including actual selected-pointer
  art, catalog changes, missing art, faults, duplicate/pending handling and restart.
- Six native icon appearances plus 16/32/64 sizes inspected in icon-review.png.
  The actual installed NSWorkspace file icon reads at 16/32/64/128 pt. A temporary
  regular native preview placed that same resolved icon in the actual Dock,
  captured only its tile and quit. The utility's normal Dock policy is unchanged.
  Normal status-icon capture shows the legible new template glyph. Earlier two
  status crops under the covering fixture are blank and are not visual evidence.
- About and General are active native light/dark captures. New name, credit,
  owned links, icon and bundled version fit. Eight popover states, native commands,
  chooser/edge checks and 21 controls/Settings layout reports pass. No new control
  flow or focus behavior was introduced. Radial light/dark captures remain readable.
- Actual installed ArmView/Metal output is ready at rest, press and release.
  Rest is diffuse, press is denser, release softens. Shadow source is unchanged;
  the seven production shadow tests pass and the prior approved native matrix
  remains applicable to the unchanged shadow sources.
  Full fixture captures include unrelated system alerts above the hand; detail
  crops show the hand/shadow only. No shadow redesign is claimed.

Early fixture helpers initially used the wrong disposable path prefix and wrong
probe suite. Their readiness guards stopped before input. They were corrected to
the existing supported prefixes and a floating menu-bar fixture. The first controls
run did not select Laser with End/Return under keyboard mode 0 and extra fixture
choices. The accepted run uses the original narrow fixture and full keyboard
access, with no production change. An initial shadow probe remained hidden under
Settings; closing Settings before aiming produces ready GPU output. Raw setup
logs/failures are preserved, not counted as acceptance passes.

### Final packages and installed state

Final app **1.0.2 / 20261110224547**, plugin **1.0.3.2**. The plugin leaf
build/validation/notarization ran first; exact archive/version/hash/Accepted
receipt embedding preceded app signing. Both are universal arm64/x86_64 with
macOS 13 minimum metadata. Bundle ID, TinyHand executable, team G2R8798RLT and
original installed designated requirement are retained.

App Accepted `4aeb5567-741d-4f1c-9805-c9249200f202`; plugin Accepted `e3264692-97b9-432c-928d-cc7a245c82e3`.
App signature/deep/strict, ticket/staple, Gatekeeper and independently extracted
ZIP checks pass. Extracted and installed app trees match every file. Their icon,
MIT notice and embedded plugin/receipt match the frozen build and installer bytes.
Hashes and paths are in final-packages.json. Branding ZIP is `b09853ae5b9c16049a86ab242ac0482cd7b4c0986e920f937fe680a582939e78`.

The real Settings Install Stream Deck Plugin button opened the exact embedded
installer. Stream Deck 7.6.0 confirmed installation, displayed the new icon,
Austin Presley and 1.0.3.2; all 21 installed files match the signed package. All
39 original profile-related files are unchanged. Of 2,892 protected originals,
none were removed; intentional changes are six plugin files and the host-owned
application cache. Real hands/preferences match. There was no saved-state folder
to restore. No key/profile/device was created or reassigned.

The final combined app remains normally running at ~/Applications/Look Here
Please.app. Original active/style/Interact/tool/settings/shortcuts/pins/enabled set
and windows match; test capabilities are absent; both real grants remain allowed.
Contact remains the original saved shadow choice. Keyboard mode is restored to 0.
Original older app is retained only as a backup and was not reinstalled.

S-013's historical reopen failure remains unresolved. Physical Stream Deck and
host-inspector acceptance for S-020/S-021 remains open. This task adds no usable
USB hardware evidence. Intel is cross-built only; older macOS, additional displays,
full VoiceOver/Accessibility Inspector and physical feel remain manual limits.
Parent owns final review and delivery, so S-024 remains implemented/review.

## S-023 menu bar controls, 10 November 2026

Outcome: implemented/review. The final candidate is app **1.0.2 / 20261110220842**,
with bundled plugin **1.0.3.1**. S-024 branding was not started. One agent worked
locally on Austin's Mac; no hosted CI, delegation, staging, commit, push, PR,
upload, host plugin installation, profile edit or key edit occurred. Parent owns
delivery. The final package is built from the starting source plus S-023 in an isolated
copy. Concurrent shadow edits remain in the shared checkout and are excluded.
Evidence, original copies, exact source manifest and isolated patch are
in `dist/verification/s023/` and its `HANDOFF.md`.

### Controls and shared actions

Left click opens a native compact popover; the same click closes it. Right click
or Control-click opens grouped Pointer, Drawing and Presentation commands, then
Settings and Quit. More Commands opens that same native menu. Pointer On/Off and
Interact have separate switches. The native pointer chooser includes every
`PointerCatalog.selectableStyles` choice, including unpinned/custom pointers.
Selecting a pointer preserves activation and Interact. A tool uses the existing
validated `tool` operation, turns Interact off and preserves activation/selection.
History, current hand/laser sound, capture, toolbar preference and Settings use
ControlBridge. Native menu checks and controls read observed state. Missing drawing
access, empty history and pending capture disable affected commands.

`MenuBarControls` and `MenuBarCommands` own presentation. `ControlInput` routes
new claims under the existing InputTap lock after existing owners have first refusal. No
second tap or factory presentation shortcut was added. The native app-local Quit
shortcut remains Command-Q. Settings editing commands remain in the responder
chain. The S-016 native toolbar gate and S-017 keep-hand logic remain intact.

### Native failures found and corrected

- A final overlap audit found that a radial Escape already owned after cancellation
  could be claimed again by newly opened controls. The matching up then drained
  only the new owner. Focused actual-InputTap tests failed for that key and for a
  repeated captured drawing mouse-down. Native red state retained Escape in both
  routers. Existing radial pairs now have first refusal through a read-only
  ownsPair query; repeated downs for existing drawing presses stay with that owner.
  New unit and native tests cover original-owner retention, no fixture leak,
  matching release and a fresh Escape positive control. This requires S-023's new
  controls and does not explain or close the pre-S-023 historical reopen failure.

- Transient status-item dismissal initially reopened on the same click, then a
  narrower test found a forwarded fixture mouse-up. The final router owns both
  halves of a status click begun with controls open and acts on release.
- Native secondary-menu outside dismissal replayed one full fixture click.
  The existing tap now reads this process's live native menu rectangles only on
  menu mouse-downs, consumes outside pairs and cancels native tracking.
- More Commands now uses a native NSPopUpButton pull-down with an icon face.
  Its AX Menu Button Press returns success before tracking. A custom NSButton
  with synchronous NSMenu.popUp, even deferred through a run-loop block, could
  leave its AX reply waiting until the menu closed.
- Opening a secondary status menu inside the tap's main-dispatch callback blocked
  control-server requests until dismissal. Scheduling the opening on the main run
  loop keeps reads and external pointer/sound changes live during tracking.
- Status-item appearance overrode the app's Light choice. The popover, chooser and
  secondary menus now explicitly use the app appearance. Accepted metadata reports
  Aqua for Light and DarkAqua for Dark, with distinct native screenshots.
- Reassigning an unchanged native selected segment reset arrow-key focus.
  The observed selection is assigned only when changed. Arrows now focus another
  segment without changing app state; Space applies it through ControlBridge.

Raw red traces and pre-cleanup native state are retained. A fixture environment
mismatch during the regression setup posted no input and was corrected by closing
that disposable fixture before launching the exact radial environment. Two
keyboard-runner assertions also assumed Pen despite a retained Rectangle choice;
the final runner explicitly seeds Pen. These setup errors are not product fixes.

### Commands and accepted checks

`HANDOFF.md` contains complete launch/reproduction commands. The final checks use
LaunchServices, exact isolated defaults suites, temporary hands and public fixture
state, with focus/bounds guards before posting input. Both real grants stayed
allowed; permission rejection tests injected denial rather than revoking TCC.

- `bash scripts/run-tests.sh`: 101 tests in 15 suites, package-contract check and
  seven grid lints. New tests cover existing-owner precedence, control/status/native-menu ownership, repeated
  downs, overlapping releases, Escape repeats and real native-menu target validation.
- `python3 scripts/menu-bar-smoke.py`: 25 named checks with actual fixture counters,
  native Window Server visibility and tap ownership. Includes all three outside
  mouse pairs through pointer-off, pre-existing native drag routing, Escape repeats,
  keyboard chooser selection, AX controls/history, external automation during
  tracking, Settings/text editing, capture pending/completion, radial eligibility
  and hidden native toolbar windows. Right/Control-click cases prove both state
  service and external pointer/sound changes work while menus track.
- `python3 scripts/menu-bar-smoke.py --denied`: four checks. Disabled tools/Interact,
  explicit access wording, rejected stale tool request and usable native Pointer
  activation in Interact.
- Real keyboard navigation: Tab order, switch activation with Space, arrow focus
  and Space tool selection, native chooser End/arrows/Return, and Escape. Global
  AppleKeyboardUIMode was recorded as 0, temporarily set to 2, and restored to 0.
- Final radial regression: 32 named checks, 35 diagnostic rows, 33 sampled Option
  openings; four injected-denial checks; 13 existing native input regressions.
  Public fixture counters, callback/native-button diagnostics and actual panel
  visibility remain part of these checks.
- Nineteen native layout reports pass: eight Pointer/Interact/appearance states,
  four native narrow/edge placements, two custom Draw states, long-name state and
  two injected-permission states and two active Settings captures. System cell optical alignment rects are measured.
  Window captures use the real compositor, not cached view rendering.

### Signed packages and restoration

The leaf plugin is built, validated, signed and notarized first. App packaging
embeds its exact archive and app-bound receipt before signing. The final app and
plugin both returned Accepted; receipts and independent extracted ZIP checks are
in `app-notarization.json`, `plugin-notarization.json`, `plugin-package.json` and
`packages-isolated-final.log`. Deep/strict signatures, the original designated requirement,
staple, Gatekeeper, exact installer hash/receipt and both universal architectures'
macOS 13 minimum pass. No unchanged host plugin was reinstalled.

The final candidate was temporarily installed at the normal path for
LaunchServices checks. Normal candidate/restore state and protected-file results
are recorded in `normal-candidate.json`, `normal-restore.json` and
`protected-final.json`. The original normally installed build **20261110193126**
is restored after testing; the S-023-only candidate remains in
`dist/verification/s023/Final.app` and its versioned ZIP under `packages` for parent review/delivery. Real preference
values, custom hands, saved state, prior evidence and Stream Deck files are retained.

### Concurrent-work boundary

A separate shadow change modified ArmView, PointerShadow, ContactShadowRenderer,
ShadowTests, the S-007 story and a validation appendix while this task ran. Those
changes are preserved, excluded from the S-023 patch and excluded from the final
isolated build. Shared-root testing reported 104 tests with three shadow additions;
the S-023-only snapshot reports 101. One shared-root radial attempt stopped at 29
checks when app.setbeam.chat-polish-light took focus. Its guard posted no Control
modifier event and preserved failure state. This is not the historical reopen
failure. The final evidence uses the isolated package and exact fixture launches.

### Review limits and retained risk

S-023 stays implemented/review for coordinator/manual acceptance. Native posted
input, AX names/values/actions and keyboard flows passed on this arm64 Mac,
macOS 27.0, one 1920 by 1080 display. A full VoiceOver/Accessibility Inspector
audit, physical mouse/trackpad feel, actual narrower/multiple/mixed-scale displays,
older macOS and Intel runtime were not exercised. Narrow width 280 and edge
anchors use real native popovers on this display. Reduce Motion/Transparency use
native material behavior and disabled popover animation; their enabled system
settings were not toggled in this round. Actual TCC revocation was not tested.

The historical S-013 reopen failure remains unresolved. Successful final checks
and the earlier 300 focused openings do not establish its cause or close it.
S-020/S-021 physical Stream Deck/host-inspector checks also remain pending.


## S-013 focused reopen reliability review, 10 November 2026

Outcome: **bounded diagnosis, retained failure unresolved**. S-013 stays
implemented/review on unchanged installed app 1.0.2 build **20261110193126**.
No production fix, app/plugin rebuild, new visual acceptance or S-023 work.
This round changes only native test tooling and STORIES/VALIDATION/FIXLOG.
Evidence and baseline/round copies are in `dist/verification/s013-reopen-review/`.
Parent owns final delivery. No delegation, hosted CI, staging, commit, push, PR,
upload, Stream Deck install or profile/key change occurred.

### Retained failure and falsifiable loop

The retained overlap PASS had right down/up 1/1, flagsChanged 100 and nine
user-input-disabled notifications. Failure state had 2/2, 104 and eleven, with no
other-button events. This narrows the failed open to the other-button case after
the right-button case cleared and reassigned the trigger. State was read after the
runner posted cleanup flags. Individual modifier delivery/native button state was
not retained, so the totals cannot identify a lost transition or establish cause.

Ranked predictions before testing were a transition lost during tap recovery,
a native button still down, an eligibility/modifier latch, or main-queue/panel
ordering. The loop reads actual callback counts, native combined/HID flags and
all 32 button states, public app tap state, and both logical/Window Server panel
visibility. Every gesture must succeed on its first attempt. Failure capture runs
before modifier cleanup. No opening retry, larger sleep or app restart is used.
`DIAGNOSIS.md` records the predictions and their limits.

Two initial focused attempts stopped before reaching the retained sequence.
Before Option, eligibility/enabled were false; native flags advanced but there
were zero opening callbacks. An unrelated Backblaze notification, then the
computer-use cursor overlay, occupied popup-menu level 101. Dismissing the
notification and stopping that temporary helper removed the setup obstructions.
Backup/settings were untouched. Those setup failures are distinct from the
retained failure and do not establish its cause. No private desktop was captured.

The runner now asserts eligibility and enabled state before posting opening
Option. It fails immediately with condition/state output rather than waiting.
This is justified by the recorded ineligible setup attempts, not a claim that a
readiness guard fixes the retained failure. Callback/native/visibility assertions
still fail if an otherwise-ready gesture is lost. The prior runner is preserved
byte-identically and was also exercised at its original cadence.

### Exact commands and bounded results

Launch uses `open -n --env ...` with an isolated S-013 defaults suite, hands and
fixture state. Readiness matches the exact suite/test mode/grants; event posting
requires a frontmost public fixture and in-bounds coordinates. See COMMANDS.md
and `launch-test.py` for complete setup and red-capable commands.

```sh
TINYHAND_VERIFICATION_DIR="$PWD/dist/verification/s013-reopen-review" TINYHAND_REOPEN_TRACE=focused-third-trace.json python3 dist/verification/s013-reopen-review/reopen-loop.py 10
TINYHAND_VERIFICATION_DIR="$PWD/dist/verification/s013-reopen-review" TINYHAND_FULL_ROUNDS=3 python3 dist/verification/s013-reopen-review/original-full.py
PYTHONDONTWRITEBYTECODE=1 TINYHAND_VERIFICATION_DIR="$PWD/dist/verification/s013-reopen-review" python3 scripts/radial-smoke.py --reopen-stress 10
PYTHONDONTWRITEBYTECODE=1 TINYHAND_VERIFICATION_DIR="$PWD/dist/verification/s013-reopen-review" python3 dist/verification/s013-reopen-review/fast-stress.py
PYTHONDONTWRITEBYTECODE=1 TINYHAND_VERIFICATION_DIR="$PWD/dist/verification/s013-reopen-review" python3 scripts/radial-smoke.py
```

- Diagnostic stress: **10 cycles / 100 openings**. Every opening produced exactly
  one Option flags callback, with buttons up and held/open/visible true.
- Original runner: **three full sequences, 32 named native checks each**, without
  new pre-open sampling or changed posting cadence. `original-full-{1,2,3}.json`
  and `original-full.log`. These are successful original scenarios, not a causal
  before/after fix. The retained red remains in the prior review-fix folder.
- Permanent strict stress: **10 cycles / 100 openings**. Exact overlapping
  left/right sequence, right/other release after trigger clear/reassign, ordinary
  close, Escape, outside cancellation, Draw/Interact changes and off/on. Checks
  include each expected callback, retained ownership, no fixture leak/annotation,
  empty input after release and actual native toolbar hiding.
- Faster stress: **10 cycles / 100 openings**, removing only the runner's extra
  120 ms settle. Native helper spacing remains 80 ms. Every callback/native-state
  assertion passes. No enlarged sleep was used.
- Final updated runner: **32 named checks / 33 sampled Option openings**, all
  callback deltas exactly one. Includes the accepted Escape-repeat correction,
  ordinary keys, full selection/catalog/geometry behavior, right/other draining,
  AX, all four modifiers, toolbar OFF, Settings, capture and text guards.

All these runs used the **same app PID 64248**, with no reset/relaunch between
attempts or cycles. There were **300 focused openings**, plus four full suites.
All 233 openings sampled by the final strict diagnostics had successful public
tap-list reads with the app tap enabled and native buttons up. Successful runs
also received user-input-disabled notifications, so those notifications alone
cannot prove the retained cause. `results-summary.json` and the raw traces/logs
retain counts. The retained product failure was not reproduced in this finite review. Rare lost
modifier delivery, transient eligibility or ordering remains possible.

### Final checks, packages and restoration

- Injected denial on a separate LaunchServices test instance: **4 PASS** checks.
  Real TCC grants were not changed. `denied-final.log`, `denial-smoke.json`.
- Fresh allowed test instance, visible/frontmost fixture and unassigned trigger:
  **13 PASS** existing native regressions. `regression-native.log` and its JSON.
- `bash scripts/run-tests.sh`: **91 tests / 14 suites**, package-contract test and
  five grid lints pass, no compiler warnings. `local-tests-final.log`.
- Reused signed app **1.0.2 / 20261110193126**, bundle
  `com.austinpresley.pleaselookhere.integration`, TinyHand, team G2R8798RLT;
  plugin **1.0.3.1**. Strict/deep signature, staple and embedded contract pass.
  App/plugin package bytes and prior Accepted notarization receipts are unchanged.
  No new build, archive or notarization is claimed. See prior review-fix packages.
- Normal app state/settings/shortcuts/pins/enabled set/windows and preference
  values restored; radial trigger Unassigned, test capabilities absent, grants
  allowed. `normal-restore.json`, `normal-final.json`, `restore-normal.log`.
- **11,011 protected originals byte-identical, no removals**, including all prior
  evidence, installed app, real preferences/hands/saved state and Stream Deck
  plugin/profile/key files. `protected-final-check.json`. Baseline copies of all
  289 source files and exact round-only manifest/diff are retained in this round.

No new visual audit is needed because rendering is unchanged. Physical
mouse/trackpad feel, full VoiceOver/Accessibility Inspector, status-menu keyboard
navigation, actual multiple displays/mixed scales, older macOS and Intel runtime
remain unverified. This is one arm64 Mac, macOS 27.0 26A425, one 1920 by 1080 display.
The retained intermittent reopen concern remains for coordinator review before
S-023. Finite successful repetitions do not close it. S-023 remains next and
untouched; all shared actions/defaults/ownership/geometry/plugin invariants remain.

## S-013 Escape ownership review correction, 10 November 2026

Outcome: implemented/review on installed app 1.0.2 build **20261110193126**.
Only the reviewed key-repeat ownership defect was corrected. `RadialInput` checks
recorded key ownership before its ordinary keyDown path, under the existing lock.
The matching keyUp remains the only removal. Cancellation, trigger clearing and
deactivation retain ownership and keep the tap enabled until release. Ordinary
unclaimed keyboard pairs and modifier flags still pass unchanged. Production delta
is one check plus its comment. No rendering/UI source, Swift language mode, action,
geometry, trigger default, hotkey, toolbar gate, keep-hand option or plugin behavior
changed. No nested agents, hosted CI, staging, commit, push, PR or upload. Parent
owns delivery. S-023 is untouched.

### Red-capable loop and cause

Before editing production code, added a parameterized regression at the actual
`InputTap.handle` routing seam. It opens the radial, claims Escape down, sends two
`keyboardEventAutorepeat=1` downs across cancellation/clear/deactivation and modifier
release, then drains Escape up. It verifies returned routing events, retained tap
ownership, modifier identity/flags, and new unclaimed Escape/ordinary modified keys.

Exact command, run twice before the fix and again afterward:

```sh
TINYHAND_DEFAULTS_SUITE=com.austinpresley.tinyhand.unit TH_HANDS_DIR=/tmp/tinyhand-unit-hands swift test --filter claimedEscapeRepeatsDrainThroughInputTap
```

Before: both runs failed with six assertions, two forwarded repeat downs in each
of three cases. After: all three cases pass in 0.002 seconds. Logs are
`escape-routing-red.log`, `escape-routing-red-confirm.log` and
`escape-routing-green.log` in the new evidence folder.

The native helper now sets the actual Core Graphics autorepeat field from an
explicit fixture event. The focused runner checks real fixture key counters, tap
callback counts, retained ownership/enabled state while held, and draining after
clear/deactivation. It sends three Escape repeats, including one after modifier
release, then the matching keyUp. A positive control proves ordinary Option-C
initial down, repeat and up reach the fixture with flags preserved. The unchanged
suite/test-mode/focus/bounds guards remain mandatory.

```sh
TINYHAND_VERIFICATION_DIR="$PWD/dist/verification/s013-review-fix" python3 scripts/radial-smoke.py --escape-ownership
```

Before: installed build 20261110185016 delivered three owned Escape repeat downs
to the fixture, with no initial down or release. `escape-native-red.log` and
`escape-native-red.json`. After: the exact command passes all four checks on the
new signed build. Fixture key counters stay unchanged in all three transitions;
the positive control adds two downs and one release. `escape-native-green.log`
and `escape-ownership.json`. The full runner also reran these checks successfully.

Ranked hypotheses were a missing ownership check in the closed-menu keyDown path,
ownership removal during configuration changes, or early tap disabling. The red
routing/native states retain key 53 and an enabled/needed tap, distinguishing the
first cause. `keys` was previously consulted only for keyUp. The two-line fix
checks `keys.contains(key)` before any ordinary keyDown handling. FIXLOG records
the rule that a claimed key press includes every repeat through matching release.

### Final local checks and retry limit

- `bash scripts/run-tests.sh`: **91 tests / 14 suites**, package-contract test and
  all five grid lints pass. No compiler warnings in the final unit log. This includes
  mouse draining, native/drawing routing, ordinary shortcuts, no-default trigger,
  selection, fixed geometry/pages/edges and validated app-action regressions.
- Full `TINYHAND_VERIFICATION_DIR="$PWD/dist/verification/s013-review-fix" python3 scripts/radial-smoke.py`:
  **32 PASS checks**, the previous 28 plus four owned/ordinary repeat checks.
  Actual fixture counters, native Window Server visibility, native AX actions,
  full pointer catalog, release selection, edge arming, all modifiers, existing
  drags, overlapping/right/other draining, toolbar OFF, Settings, capture and text
  eligibility pass. `native-smoke-final.log` and `radial-smoke.json`.
- The first full attempt passed the new Escape loop and later stopped when the
  radial failed to reopen before a right/other mouse-drain case. Post-failure
  state had valid eligibility and empty key/button ownership. Preserved
  `native-smoke-first.log`, `radial-smoke-first.json` and
  `native-first-failure-state.json`. The exact same suite passed from a fresh
  LaunchServices instance, without further source changes. Cause is not established;
  do not read the successful retry as proof that reopening is never intermittent.
- `python3 dist/verification/s013-review-fix/launch-test.py --deny`, then the same
  native runner with `--denied`: **4 PASS checks**. Denial is injected only in the
  test process. Real TCC grants were never revoked. `denial-final.log`.
- Fresh non-denied LaunchServices instance, then
  `python3 dist/verification/s013-review-fix/run-native-regression.py`: **13 PASS
  checks** from the existing `scripts/live-smoke.py`. The wrapper verifies the
  isolated suite environment, visible/frontmost fixture and unassigned radial
  trigger. `regression-native.log` and `regression-native/live-smoke.json`.

All new evidence is under `dist/verification/s013-review-fix/`. `COMMANDS.md` and
its launch/restore/extraction scripts retain exact commands and guards. The native
runner emitted fixture captures in this folder as part of its existing functional
loop. No new visual/layout acceptance or actual Reduce Motion audit is claimed.
The original S-013 screenshots/layout/Reduce Motion evidence remains historical
and byte-identical. Physical gesture feel, full VoiceOver/Accessibility Inspector,
status-menu end-to-end keyboard navigation, real multi-display/mixed-scale, older
macOS and Intel runtime limits remain open. This is one arm64 Mac, macOS 27.0
26A425, one 1920 by 1080 display. Intel is cross-built only.

### Signed/notarized packages and restoration

`bash scripts/build-review.sh` built and notarized the plugin leaf first, then
built the universal app, verified its embedded version/hash/receipt contract,
signed with the stable timestamped Developer ID, notarized, stapled, extracted
and checked the exact ZIP, and installed via the existing path/LaunchServices.
`python3 dist/verification/s013-review-fix/verify-extracted.py` independently
rechecked both archives, every plugin payload byte, executable mode 0755,
x86_64/arm64 architectures, strict/deep signatures, app staple and Gatekeeper.
The designated requirement matches the prior installed S-013 build.

- App remains `com.austinpresley.pleaselookhere.integration` / TinyHand / team
  G2R8798RLT, version **1.0.2 build 20261110193126**.
- App Accepted: `dd27514f-d0ab-4b27-90ff-1ae7f70e647b`.
- Plugin **1.0.3.1** Accepted: `25dfc485-6807-4af1-b386-3f668ce442f0`.
- Stable app: `Look Here Please-s013-review-fix.zip` in the new evidence folder.
  SHA-256 `5512c113b84c74830221cebe83efdb30a40c8c53b6ad604a9b4f1f906d4f58ec`.
- Stable plugin: `Look Here Please-s013-review-fix-1.0.3.1.streamDeckPlugin` there.
  SHA-256 `8a1b0c8677c69b015c23c210f208a3d51cfc798fcbe00ff1ca98797ae42aa80e`.

`build-review.log`, `extracted-checks.json`, `extracted-verification.log`,
`app-notarization.json`, `plugin-notarization.json`, `plugin-package.json`,
`app-signature.txt`, `app-requirement.txt` and `identity-continuity.txt` retain the
receipts and checks. The installed Stream Deck plugin/profiles/keys were untouched.

`python3 dist/verification/s013-review-fix/restore-normal.py` quits the test app
and fixture, opens the installed app through LaunchServices without test env,
then compares original state/preferences/settings/shortcuts/enabled set/pins/windows
and both grants. Normal state matches, trigger is Unassigned, test capabilities
are absent and both grants remain allowed. Raw protected hashes match, with no
removals. **10,306 protected original files are byte-identical**, including the
original S-013 and every earlier story artifact, real hands/preferences/saved state
and Stream Deck host/plugin/profile/key files. `normal-final.json`,
`normal-restore.json`, `restore-normal.log` and `protected-final-check.json` verify.

This round started from the heavily modified shared branch
`feature/macos-fork-integration`. `starting-source-hashes.json` and `starting/`
capture all 289 original source files. `changed-files.json`, `delta/` and
`s013-review-fix-only.diff` contain exactly seven round-only changed files. All
other source files and HEAD remain unchanged. No git reset/restore/clean/switch,
staging, commit, push, PR, hosted workflow or delivery action occurred.

S-023 handoff: retain validated shared actions, independent pointer/Interact,
complete enabled/available catalog, optional shortcuts, keep-hand and actual
native toolbar hiding gate. Its redesign and the prior hardware/manual limits
remain for the parent. Parent also owns final delivery.

The following original S-013 section predates this correction and remains
historical evidence of build 20261110185016, not a test of the corrected input code.

## S-013 radial quick controls, 10 November 2026

Outcome: implemented/review. The native radial control is implemented and installed;
all available local functional, unit, visual and packaging checks pass. Manual
physical gesture feel, full VoiceOver/Accessibility Inspector, end-to-end status-menu
keyboard navigation and additional hardware/OS coverage remain unverified. Only
S-013 was implemented. No nested agent, hosted CI, staging, commit, push, PR, upload,
Stream Deck installation or profile/key change occurred. Parent owns final delivery.

### Chosen UX and ownership

Recorded S-013 doing, its UX and `architecture-review-s013.md` before code.
Quick controls have fixed compass directions: Pointer north, Color northeast,
Tools east, Interact southeast, History south and More southwest. Moving through
100 points enters a category, then 176 points reaches its outer choices. Move
inside 88 points to go back. No hover timer or repeated click is needed. Pages
contain six entries with fixed Previous/Next directions and require a short inward
movement before another choice. `PointerCatalog.selectableStyles` supplies the
complete enabled, available library in stable order, including unpinned/custom
hands and Laser dot. Catalog/preferences changes dismiss stale sessions.

The trigger is optional bare Option, Control, Shift or Command in Settings >
Shortcuts. It starts Unassigned; Clear removes it without changing other shortcuts;
Reset All leaves it Unassigned. No new factory hotkey is installed. Opening needs
an active pointer, Accessibility, no capture/text/Settings key window/menu, and no
existing mouse press. A modifier already held when eligibility begins requires
release and a fresh press. Existing native and annotation drags keep their original
route. Ordinary keys and extra modifiers cancel and preserve their keyboard events
and flags. Only Escape and menu-owned mouse pairs are consumed. Overlapping presses
stay owned until every release drains, including after clearing/deactivation.

Native comparison selected release-to-select. Both policies highlighted Cursor
glove after the same movement from Lavender toy. Release-to-dismiss preserved
Lavender toy; release-to-select chose Cursor glove. Fixture mouse counters did not
change in either case. Immediate release and center release cancel. A click on a
highlighted leaf selects, other clicks cancel. Selection closes even while the
modifier remains down, without reopening. The choice is settled, not a blocker.

`RadialSession` owns pure geometry, pages and gesture state. `RadialInput` owns the
modifier latch and paired suppression under a lock, inside the existing InputTap
before drawing routing. Ordered main-queue notifications drive `RadialMenu`, which
owns the nonactivating panel, native accessible buttons, result feedback and a
high-contrast selection dot above button artwork. Mouse movement reuses unchanged
buttons. OverlayController only supplies eligibility/composition. It is 588 lines,
with no general refactor or Swift language migration. There is no second tap and
no modifier-to-Interact path.

Actions reenter the app's validated ControlBridge operations, then the same overlay
methods used by toolbar/control clients. Pointer and color selection preserve
activation/Interact. Tools preserve the pointer and activation and explicitly turn
Interact off after capture/permission validation. The new `toggle-current-sound`
uses the toolbar's hand/laser sound action; legacy `toggle-sound` is unchanged.
Only additive native Choose Pointer / Ink Color submenus were added to the existing
status menu. S-023's menu-bar redesign was not attempted.

The 592-point panel clamps to the cursor display's visible frame, without cursor
warping or direction rearrangement. A shifted menu must arm in its center before
selection. A visible frame smaller than 592 by 592 points cannot show this control;
it does not shrink targets. Actual panel animations are disabled, including result
feedback. Large pointer artwork can extend beyond the display, while the control
and selection dot remain the selection reference.

### Local tests and native input evidence

- `bash scripts/run-tests.sh`: 90 tests in 14 suites, package-contract tests and
  five grid lints pass. Twelve radial tests cover defaults/reset, shortcut
  preservation, all trigger flags, denied eligibility, ordinary key pairs,
  Escape/mouse draining, overlapping buttons, held-key activation, tap precedence,
  native AX command navigation, fixed geometry, shifted arming and full pagination.
  `unit-tests-final.log` has no compiler warnings. Pure radial tests also complete
  in milliseconds when run alone.
- The first toolbar tests went red because the new test window was inserted before
  the toolbar. Preserve the old order and append the radial panel. The same three
  tests pass. Native Window Server checks then caught an AppKit fade after
  `orderOut`, with logical visibility false but native alpha 0.2216. Disable inferred
  panel animation. A separate overlapping-button test went red with two assertions;
  retaining ownership until all releases makes the regression green. First light
  captures exposed dark resolved layer colors under light labels; colors now resolve
  under the panel's effective drawing appearance. Red logs/first captures remain in
  this story's folder. FIXLOG.md records the rules.
- `scripts/radial-smoke.py`: 28 named checks pass on final installed build
  20261110185016. It compares real fixture-received mouse/key counters and modifier
  flags, actual Window Server panel presence/alpha, real overlay windows and app
  state. Coverage includes both release policies, all 38 selectable fixture pointers
  across seven pages, custom/disabled changes, pointer/tool independence, History,
  existing native and drawing drags, overlapping left/right pairs, right/other
  release draining after clearing, Escape/outside cancellation, ordinary modified
  key pairs, all four modifiers, held-key activation, explicit Option shortcut,
  native AX category/selection actions, Settings/text entry and capture cancellation.
  `radial-smoke.json`, `native-smoke-final.log`, `radial-*-ax.json`.
- The same runner's `--denied` mode passes four checks with injected Accessibility
  denial on a fresh LaunchServices instance. The actual radial tap remains disabled,
  a modified native click pair still reaches the fixture, tools reject before
  mutation and an invalid trigger rejects its whole settings batch. Real grants
  were not revoked. `denial-final.log`, `denial-smoke.json`.
- Existing `scripts/live-smoke.py` passes all 13 native annotation/shortcut/motion/
  toolbar/capture regression checks, with the radial trigger explicitly unassigned.
  Evidence is `regression-native/` and `regression-native.log`.
- The runner's `--reduce-motion` check passes with the real macOS Reduce motion
  switch on, confirmed by NSWorkspace. Opening, selection and native dismissal have
  fixed geometry and no inferred animation; fixture counters do not change. Restored
  the original OFF switch and original System Settings page, and confirmed the app
  observes false again. `reduce-motion.json`, `system-motion-restored.json`.
- Actual native Settings picker assignment and Clear were exercised through CUA.
  AX exposes Radial menu modifier, its Option/Unassigned value, Clear radial menu
  modifier and its help/disabled state. The separately assigned Option-K sound
  shortcut survived assignment and clearing. `settings-ui-assigned.json`,
  `settings-ui-cleared.json`, `settings-trigger-ax.txt`.

Launch/readiness checks match the exact disposable suite
`com.austinpresley.tinyhand.s013.9c3f8bf8656646caa8c68a4bf01d47d0`, test mode,
new TH_HANDS_DIR, both grants and the frontmost public fixture's visible bounds.
The test helper posts input only over that fixture, except the matching release
of a press that opened an app panel and two narrowly guarded own-window keys,
Command-W for identified Settings and Escape for identified Add Text. Test-only
release-policy/snapshot control requires test mode and the isolated S-013 suite
prefix. Normal capabilities exclude it. No live user defaults/assets were used.

### Actual visual and layout review

Fifteen actual native radial layout reports and two actual focused Settings reports
pass `scripts/check-layout.swift`. Card frames round to the four-point grid; hit
directions remain fixed. `radial-layout.log`, `settings-snapshots.log` and measured
`*-layout.json` files preserve the results.

- `radial-root-large-{light,dark}.png`: root labels, Interact check and summary are
  readable. The large hand remains behind control artwork and the outlined dot
  identifies its real fingertip. No overlapping targets.
- `radial-pointer-{light,dark}.png`, corresponding `-large-` captures and
  `radial-last-page-{light,dark}.png`: thumbnails, current-pointer check, highlighted
  choice, page number and disabled navigation fit. Last page shows the custom hand
  and Laser dot without smaller targets.
- `radial-color-`, `radial-history-`, `radial-more-` light/dark PNGs: names and current
  color check fit. Disabled Redo is distinct; Screenshot, sound, toolbar, Settings
  and Pointer Off remain readable. Full-fixture variants preserve large-hand context.
- `radial-tools-laser-{light,dark}.png`: five tool labels and the selection point are
  clear with Laser dot selected. `radial-reduce-motion-large.png` shows the large
  hand and highlighted pointer under the actual system preference.
- Four `radial-edge-*.png` captures show Enter center, fixed directions and complete
  controls/footer at each corner. Actual cursor readback equals the requested edge
  point at opening. Entering center arms, then selection works normally.
- `settings/settings-shortcuts-{light,dark}.png`: actual key, active native window,
  colored traffic lights, readable trigger/help and optional-shortcut rows. The
  longer Shortcuts page intentionally scrolls. No clipping or unwanted initial
  selection/focus ring. Draft standalone captures are explicitly not final evidence.

### Universal signed/notarized packaging

`bash scripts/build-review.sh` ran the plugin leaf first, then the universal app,
embed validation, hardened timestamped Developer ID signing, Apple notarization,
stapling, exact ZIP extraction and installed-copy checks. No stale/missing plugin
artifact bypass, recursive build or hosted workflow was introduced.

Final app: 1.0.2 build **20261110185016**, bundle
`com.austinpresley.pleaselookhere.integration`, executable TinyHand, team G2R8798RLT.
Plugin remains 1.0.3.1, with no plugin source/schema/behavior changes.

- Plugin Accepted: `300b5b00-548c-4b3d-9142-b638a375bac8`.
- App Accepted: `5e306f40-deb5-4541-89ab-bbc850465874`.
- App archive SHA-256: `50c757fe6aecdaef63e93420bf527e70ca8176a0c1077cb1e7b52fd3f2c9be50`.
- Plugin archive SHA-256: `096a96ad2c01581bda160e173196c66d5563ca7e2d17ff3887a3dfc7e7828df7`.

Stable local archives are `Look Here Please-s013.zip` and
`Look Here Please-s013-1.0.3.1.streamDeckPlugin` under this story's evidence.
`verify-extracted.py` independently extracts both, revalidates the embedded app
version/build/hash contract, compares every plugin payload byte to the signed
package, checks executable mode 0755 and both x86_64/arm64 architectures. App strict/
deep signing, staple validation and Gatekeeper Notarized Developer ID pass; the
extracted plugin executable passes strict signing. Receipts, signature, SHA files,
package contract and logs are retained. No host reinstall or key reassignment.

### Restoration, review limits and S-023 handoff

The normal installed app is running again with the original active/style/tool/
Interact/settings/shortcuts/enabled set/pins/windows and no test capabilities.
The radial trigger is Unassigned. Real preference values and raw protected hashes
match, both grants remain allowed, and all 9,946 protected original files are byte
identical, with no removals. This covers prior story evidence, saved app state,
real hands, Stream Deck support/profile/key/plugin files and the real preferences.
`normal-final.json`, `normal-restore.json`, `protected-final-check.json` and
`restore-normal.log` document the audit. The first restoration readiness probe
received the transient stopped reply; the bounded loop now tolerates it.

This Mac is arm64, macOS 27.0 build 26A425, with one 1920 by 1080 display. Physical
mouse/trackpad gesture feel, actual multiple displays/mixed scales, older macOS and
Intel execution are not tested. Negative-origin geometry is unit-tested and Intel
is cross-built. Full VoiceOver/Accessibility Inspector and end-to-end status-menu
keyboard navigation are not claimed; Control-F8 did not visibly transfer focus in
this environment. Native radial AX names/state/actions and ordinary assigned
keyboard commands are verified. These explicit manual coverage limits keep S-013
in implemented/review for the coordinator.

S-023 should retain the shared validated commands, independent pointer/Interact
state, full selectable catalog and optional shortcut/toolbar preferences. It may
redesign the existing status list; S-013 only added standard Pointer/Ink submenus.
Current left-click pointer toggle and right-click controls remain unchanged.
S-020/S-021 hardware/host-inspector gaps are unchanged. No next story was started.
The exact 23-file story delta, starting copies, hashes and patch live in
`changed-files.json`, `starting/`, `delta/` and `s013-only.diff`.


## S-022 install from Settings, 10 November 2026

Outcome: done and coordinator-reviewed. Scope is S-022 only. Settings → General
has a Stream Deck card with bundled version, host requirements and Install Stream
Deck Plugin…. The signed delivered app contains its matching installer. The actual
Settings button successfully reached Stream Deck's normal confirmation and the
host installed version 1.0.3.1. Prior S-020/S-021 physical and inspector acceptance
is still open. Evidence is `dist/verification/s022/`. No nested agent, hosted CI,
staging, commit, push, PR or upload occurred. Parent owns final queue delivery.

### UX and implementation

Recorded the General-page card, flow, words, failures and accessibility intent in
STORIES.md before coding and marked S-022 doing. The native button and wrapping
status stay inline. Missing Stream Deck offers Download Stream Deck…; missing or
corrupt installer asks to reinstall Look Here Please; failed open asks to open
Stream Deck and retry. Opening and pending messages do not claim installed state.
The actual host owns confirmation. Settings intentionally does not infer success
from NSWorkspace's callback or read private host preferences to claim completion.

The download URL is exactly [Elgato's official US downloads page](https://www.elgato.com/us/en/s/downloads),
verified with the primary page and T3 preview on this date. The page lists Stream
Deck for macOS. Elgato's [distribution documentation](https://docs.elgato.com/streamdeck/sdk/introduction/distribution/)
describes `.streamDeckPlugin` distribution. NSWorkspace's installed SDK header
provides `openURLs:withApplicationAtURL:configuration:completionHandler:` on the
supported macOS versions. The installer resolves `com.elgato.StreamDeck`, validates
its version, validates the app-bound receipt and exact installer SHA-256 off the
main actor, and explicitly hands that resource to that host. No terminal, checkout,
dist lookup, profile mutation, key migration or remote auto-updater exists in this
runtime path. No S-019/S-020/S-021 plugin behavior or source was changed.

### Local checks

- Starting snapshot copied and SHA-256 hashed 278 tracked/untracked source files,
  saved git status, normal app state/preference export, a full installed-app copy,
  saved-state inventory, real hand roots, all 2,871 Stream Deck support files and
  all previous S-015/S-017/S-016/S-018/S-019/S-020/S-021/review-fix evidence. See
  `starting/`, `starting-hashes.json`, `starting-status.txt` and
  `protected-starting-hashes.json`.
- `bash scripts/run-tests.sh` passed 78 tests in 13 suites plus four grid lints.
  Five installer tests cover receipt/app-build mismatch, malformed/missing receipt,
  missing/corrupt archive, missing/old host, exact bundled package/host handoff,
  failed-open retry, pending duplicate suppression and no false success message.
  `python3 scripts/test-streamdeck-package.py` covers missing package, stale source
  inputs, rejected notarization, changed archive and matching embed/version/hash.
  The normal test runner now includes it. `unit-tests.log`, `package-tests.log`.
- Initial fixture URL equality compared directory-URL metadata instead of the
  exact paths; corrected that assertion to compare paths. Initial layout probe
  inherited a 20 pt inset around the 16 pt card padding; fixed only its annotation
  to `Space.lg`. Preserved the first build/receipts in `first-build/`. The final
  five installer tests pass in `installer-final-tests.log`; four final lints pass
  in `grid-lint.log`. No language migration or unrelated refactor.
- `launch-test.py` uses LaunchServices at the installed path, disposable defaults
  `com.austinpresley.tinyhand.s022.fb7fe9102949476dbb0d63f640422b73`, a new temporary
  hand directory and test mode. Bounded readiness checked the exact suite and both
  grants before any test work. `environment.json`, `test-ready.json`.
- `TINYHAND_VERIFICATION_DIR=<s022>/settings TINYHAND_SNAPSHOT_SECTIONS=general
  python3 scripts/snapshot-settings.py` captured the actual active General window
  light/dark. Repeated for `settings-handoff/` after opening the installer. All
  four layout reports pass: 15 probes before and 16 after handoff, each in 7 areas.
  Inspected all four final PNGs: version, two-line requirement and native button
  fit; handoff text wraps beneath it; dark mode remains readable. General grows
  to fit the content. No overlapping, clipping or unwanted focus ring was found.
  Native AX exposes the install button's name, help and identifier and visible
  status. Full VoiceOver and Accessibility Inspector audits are not claimed.

### Local packaging, signing and extracted delivery

Audited `build-review.sh`, `build-app.sh`, `release.sh`, `lib.sh` and
`build-streamdeck.sh`. Wrappers forward to build-review. It calls the leaf plugin
build once, then builds TinyHand, assembles the app and signs. The plugin build
never calls make_bundle or an app wrapper. `make_bundle` fails unless the plugin
record, Accepted notarization receipt, source hashes and exact installer agree.
`streamdeck-package.py` seals plugin UUID/version, required host, installer hash,
notarization ID and input hashes into Resources with matching app version/build.
Final ZIP extraction rechecks the nested installer rather than trusting a dist
path. See the detailed contract in streamdeck.md. Shell syntax checks passed for
all five scripts. All signing/packaging/validation ran locally.

Final `bash scripts/build-review.sh` produced and installed app 1.0.2 build
**20261110181001**, executable TinyHand, unchanged bundle ID
`com.austinpresley.pleaselookhere.integration`, Developer ID team G2R8798RLT.
Both universal arm64/x86_64 binaries have timestamped hardened signatures.

- Plugin 1.0.3.1 notarization Accepted, `d467f7ad-75fc-400a-9c4d-0f5dbd8083d4`.
- App notarization Accepted, `6877c84d-ecb9-4445-85be-5b2e7f01c96d`.
- Bundled installer SHA-256:
  `d6d6a048e96f90683e55f587307b16e79f78bbdddf3354c28fcc12a1ae3a683d`.

See `build-review.log`, both notarization JSONs, `plugin-package.json` and signature
logs. The final stable app ZIP is `Look Here Please-s022.zip`; plugin copy is
`Look Here Please-s022-1.0.3.1.streamDeckPlugin`. `final-extracted/` and
`plugin-extracted/` retain actual extracted payloads. Archive integrity, exact
manifest/version and every plugin payload byte against the signed build, strict
signature/team, arm64/x86_64, executable mode 0755 and Elgato CLI 1.10.0 validation
passed. The final extracted app passed deep/strict signing, staple validation and
Gatekeeper Notarized Developer ID. The app receipt agrees with its own version/
build and exact nested installer hash. `extracted-verification.log` and
`extracted-payload-checks.json` preserve these results. Intel is cross-built,
not run. Notarization of the plugin is separate from the stapled app lane.

### Real Settings-to-host installation and preservation

Clicked the installed app's actual Install Stream Deck Plugin… button via native
computer use. Stream Deck 7.6.0 displayed “Are you sure you want to install
"Look Here Please" plugin?” and an Install/Cancel sheet. Confirmed Install.
The host showed “"Look Here Please" plugin installed. It can be found in your
Actions List.” Its Plugins page showed Look Here Please, By Austin Presley,
**1.0.3.1**. All five actions appeared in the actual host-rendered action list.
Screenshots and AX snapshots: `host-install-confirmation*`, `host-installed*`,
`host-plugin-version*` and `host-actions.png`. This is host installation evidence,
not a synthetic open callback or physical key test.

Host log confirms the exact resource opened from
`~/Applications/Look Here Please.app/Contents/Resources/`, `installLocal:finished
(AllOk)` and `Plugin connected`. The profile-import message says no matching or
required profiles found, as expected because this plugin bundles no profiles.
`host-install-log.txt` contains those relevant host-owned log entries. Installed
path is `~/Library/Application Support/com.elgato.StreamDeck/Plugins/
com.austinpresley.lookhereplease.sdPlugin`. All 21 installed files match the signed
packaged payload, UUID/version match, executable mode is 0755, strict signature
passes and the host-launched process reports plugin 1.0.3.1. See
`installed-plugin.json` and its signature log. The new plugin remains installed.

Before/after support-file hashing shows **no original file removed**. All 39
profile-related files are unchanged. Of 2,871 originals, 2,870 are unchanged and
only host-owned `Data/application_cache.json` changed. The 21 new files belong
exclusively to the installed Look Here Please plugin. No profile or saved key was
created, imported, reassigned or overwritten. Host log append activity is distinct
from user profile/key content. `streamdeck-delta.json`, `restore-checks.json`.

Tried the actual host Profiles page for a disposable verification profile. Only
MCP Deck is available in the canvas/device selector, and its Profiles page has
only More Info with no profile editor. Remembered disconnected devices in host
metadata are not usable hardware. `host-profiles-unavailable*` records this limit.
Did not edit an existing MCP key to force a property inspector. Actual pointer/
tool host inspector keyboard/VoiceOver checks remain open. USB inventory exposes
no usable Stream Deck; physical key readability/press/reconnect and dials for
S-020/S-021 stay open. This story does not relabel inspector/replay evidence as
physical acceptance.

### Restoration and S-013 handoff

`restore-normal.py` quit the isolated process and LaunchServices-launched the
normal app at the same path. Bounded readiness confirmed no test operations,
both actual grants, original active/style/tool/Interact/settings/shortcuts/enabled
set/pins/windows. Real preferences compare equal; real hand and saved-state
inventories and every previous story evidence hash match. `restore.log`,
`restore-checks.json`, `normal-final.json`. No permissions were reset or edited.
The only intentional lasting user-facing change is the new app build and plugin
installation. Parent owns any final delivery.

S-013 can use the app-owned enabled/available pointer order and validated actions
already documented in control-protocol.md. Preserve S-015's no-default-hotkeys rule,
keep toolbar optional, prototype release behavior and guard input ownership while
opening/dismissing the radial menu. This installer adds no control operation or
pointer/tool queue change. S-013/S-023/S-024 remain untouched. This round's exact
files, hashes and baseline-relative patch are in `changed-files.json`,
`s022-only.diff` and `delta/`.


## S-021 fixed-key review correction, 10 November 2026

Outcome: implementation coordinator-reviewed. Physical Stream Deck and
host-inspector acceptance remain pending. Only the reviewed fixed-tool identity
and readiness defect was corrected. No S-022, nested agent, commit, staging, push,
PR, host install, profile/key edit or upload occurred. All checks and packaging
ran locally on Austin's Mac. Hosted CI stayed disabled. Evidence is dedicated to
`dist/verification/s021-review-fix/`; the original `s021/` evidence is byte-identical.
The historical S-021 section below describes plugin 1.0.3.0, including its
superseded fixed-key presentation. Those 71-test/120-replay results do not test
this correction.

### Defect and corrected behavior

Coordinator review found that fixed Pen and Rectangle keys against the same
observed state had identical glyph/name/detail/readiness. Prior tests expected
that wrong identity. `KeyModel` now uses the configured fixed destination for its
stable glyph/name, like Select Pointer. Cycle keys continue to show the actual
acknowledged current tool. A fixed key receives the active border/ready check
only when its target equals the acknowledged actual tool AND the pointer is on,
Interact is off, Accessibility is allowed and capture is not in progress.

On/Off and Interact/Draw remain observed detail. Pending/receipt marks do not
claim requested selection. Fixed names remain visible through checking, stopped,
no-reply, unknown tool, rejection and uncertainty; guidance uses the detail line.
Locks, capture hourglass and stale marks remain distinct. A stale fixed key has
no ready check or active border. The inspector now explains cycle versus fixed
identity. Protocol requests, cycle order, selection/activation/Interact rules,
queue/FIFO, uncertain non-replay, action UUID/settings, pointer toggle and app
production source are unchanged. The signed app was not rebuilt or replaced.

### Fresh commands and results

- Captured 278 starting tracked/untracked files with copies and SHA-256 hashes
  before edits, plus all original S-021 evidence, the installed signed app, old
  plugin payload, real hands and Stream Deck files. `starting-plugin/` preserves
  the previous package. See `starting-hashes.json`, `starting/`,
  `starting-status.txt` and `protected-starting-hashes.json`.
- Before fixing the model, ran `TINYHAND_DEFAULTS_SUITE=com.austinpresley.tinyhand.unit
  TH_HANDS_DIR=/tmp/tinyhand-unit-hands swift test --filter 'DeckKeyTests.fixedTool'`.
  Both new tests failed against the old implementation, with 781 failed assertions.
  `model-before-fix.log` retains this expected failure. The two tests compare all
  five differently configured fixed keys against each same observation over
  actual tool, On/Off, Interact, permission and capture combinations, and exercise
  pending/error/connection/unknown states. The old actual-tool expectation now
  explicitly tests Cycle tools. The corrected 19-test model suite passed in
  `model-after-fix.log`.
- `bash scripts/run-tests.sh > dist/verification/s021-review-fix/unit-tests.log 2>&1`
  passed 73 tests in 12 suites and all three existing grid lints. Swift language
  mode is unchanged. No app UI or layout changed, so no new native app snapshot
  or layout-probe claim is made.
- `bash scripts/build-streamdeck.sh > dist/verification/s021-review-fix/build-streamdeck.log 2>&1`
  built universal arm64/x86_64 plugin **1.0.3.1**, signed with Developer ID Application:
  Austin Robinson, team G2R8798RLT, hardened runtime and secure timestamp. Elgato
  CLI 1.10.0 validation, archive integrity and executable mode passed. Notarization
  Accepted, submission `0ccd6370-b6d6-4892-ac4e-753f39456398`. See
  `plugin-notarization.json` and `plugin-signature.log`. The first build waited
  for the local test SwiftPM process to release its build directory, then succeeded.
- Copied the fresh package to
  `dist/verification/s021-review-fix/Look Here Please-s021-review-fix-1.0.3.1.streamDeckPlugin`
  with a SHA-256 sidecar. `ditto -x -k` extracted it to `plugin-extracted/`.
  `codesign --verify --strict --verbose=2` passed on the extracted binary, and
  `npx --yes @elgato/cli@1.10.0 validate dist/verification/s021-review-fix/plugin-extracted/com.austinpresley.lookhereplease.sdPlugin --force-update-check`
  passed. Every extracted payload byte matches the built plugin, version is
  1.0.3.1 and the executable bit is retained. Evidence is in
  `extracted-payload-checks.json` and `extracted-plugin-verification.log`.
- `python3 dist/verification/s021-review-fix/launch-test.py` LaunchServices-launched
  the existing signed app with `TINYHAND_TEST_MODE=1`, matching disposable defaults,
  APP_SNAPSHOT and TH_HANDS_DIR. Bounded readiness confirmed the suite plus both
  actual grants in `test-ready.json`. Environment is in `environment.json`.
  The suite is `com.austinpresley.tinyhand.s021reviewfix.e39127c8f677499885ec73908afc5912`, hands are `/var/folders/8h/r0gxs7ls4kgc804g7lj475q80000gn/T/s021-review-fix-hands-wy264jsw`. Real preferences/hands were
  never the mutation target. The fixtures use `custom-s019` with a Robot PNG and
  `custom-s019-missing` without one.
- `tool-replay-command.json` records the exact `python3 -u scripts/deck-tool-replay.py`
  argv, with the installed app, fresh signed plugin, disposable suite/hands and
  `--out .../s021-review-fix/tool-replay`. It passed **168/168** checks. Six visible
  keys include five distinct fixed destinations plus cycle, against the same
  actual Pen, external Rectangle, external Arrow Off/Interact, last Pen while a
  Number request is pending, and acknowledged Number. All five identities remain
  distinct; only the matching ready fixed destination checks. The pending fixed
  request forwards once to the real app. `simultaneous-frame-manifest.json` keeps
  the shared state/settings/frame mapping. `fixed-identity-proxy-requests.json`
  records the actual requests. Existing strict validation, rapid completed presses,
  held duplicates, mixed FIFO/settings snapshots, delayed/dropped replies, safe-read
  recovery, no uncertain replay, page/incarnation cancellation, denied permission
  and stopped/restarted checks also passed. Test-only denial does not revoke OS
  permission. No screenshot was taken to test capture rejection.
- `python3 dist/verification/s021-review-fix/run-pointer-regressions.py` checks the
  matching test suite before each reset, then runs the preserved pointer-cycle
  and current-pointer lanes sequentially. **87/87** and **66/66** passed. Exact argv
  is in `cycle-replay-command.json` and `current-pointer-replay-command.json`,
  with fresh logs and all received frames in their corresponding directories.
- `/tmp/s021-art-venv/bin/python dist/verification/s021-review-fix/build-key-sheets.py`
  assembled `fixed-vs-cycle-72.png`, `fixed-vs-cycle-144.png` and fixed-feedback
  sheets. Every simultaneous-sheet cell maps to an exact received frame in
  `sheet-received-sources.json`. Inspected both sizes: destinations are distinct,
  names/detail fit, the selected check moves with acknowledgment, pending Number
  stays unselected, and cycle follows actual state. Reviewed fixed error/uncertainty/
  stale/no-reply sheets at both sizes too. Initial system `python3` lacked Pillow;
  the existing disposable S-021 art venv supplied it. No product change was needed.
- Served the revised real inspector using `python3 -m http.server 8768 --bind
  127.0.0.1 --directory streamdeck/inspectors`. T3 preview opened it, but two snapshot
  calls returned `Preview automation snapshot timed out after 15000ms.` Switched
  to T3 `html_preview` for the same source. Reviewed 240 px dark, 320 px light,
  420 px dark and invalid-choice 240 px snapshots. Text wraps, native select/error
  guidance fits, and the corrected fixed/cycle wording is readable. At 240 px,
  document and viewport both measured 240 px; select measured 216 px. No inspector
  settings or registration logic changed. Real host keyboard/VoiceOver acceptance
  remains pending. `review-visuals.html` was previewed and published in T3.

### Restoration, handoff and limits

`python3 dist/verification/s021-review-fix/restore-normal.py` quit the isolated
process and LaunchServices-launched the normal installed app. Bounded readiness
confirmed both grants, no test-only operations, original active/style/tool/Interact,
settings/shortcuts/enabled set/pins and windows. Parsed real preference exports
match. Hashes match for all 1,695 original S-021 evidence files, all 143 installed
app files, all real hands and all 2,871 Stream Deck files. `restore-checks.json`
contains no differences. Existing app 1.0.2 build **20261110173607** remains unchanged;
fresh deep/strict signature, Gatekeeper Notarized Developer ID and staple validation
passed in `app-signature.log`. Identity is in `app-identity.json`.

`changed-files.json`, `s021-review-fix-only.diff` and `delta/` isolate this round
against its own starting copies. `evidence-manifest.json` records fresh commands,
results, package and screenshot paths. Other prior tracked/untracked work remains
byte-identical. No reset/restore/clean/switch, git add, commit, push or PR was used.
The parent owns final delivery. Stop for coordinator review before S-022. Its
future installer must use corrected plugin 1.0.3.1, not baseline 1.0.3.0.

Fresh inventory still finds Stream Deck host 7.6.0, no installed Look Here Please
plugin and no usable USB Stream Deck. Physical presses/readability, host inspector,
hardware reconnect, dials, actual permission revocation and full accessibility
acceptance remain unverified. Only Keypad is registered. Intel was cross-built,
not run; no older-macOS or multi-display acceptance is claimed.

## S-021 change or cycle drawing tools from Stream Deck, 10 November 2026

Outcome: implemented, ready for coordinator review; physical Stream Deck acceptance
pending. Only S-021 was implemented on the already modified
`feature/macos-fork-integration` checkout. No subagents, other stories, staging,
commit, push, PR, host installation, profile edit or upload were used. All tests,
builds, packaging, signing and notarization ran locally on Austin's Mac. Hosted CI
stayed disabled. The parent owns review and final delivery. Evidence is dedicated
to `dist/verification/s021/`; 276 starting tracked/untracked files have copies and
SHA-256 hashes in `starting/` and `starting-hashes.json`. Earlier evidence remains.

### UX, app authority and queue rules

Recorded the doing story and UX before coding. **Choose Tool**, UUID
`com.austinpresley.lookhereplease.choose-tool`, adds a native labeled **Tool choice**
select. Its values are Cycle tools, Pen, Rectangle, Arrow, Text and Number. Saved
`tool` is `cycle` or one of those lowercase fixed IDs. An absent field defaults to
cycle. Empty, unknown, null and non-string choices remain invalid in both model
and inspector; the key rejects locally with Choose Tool. Opening the inspector
does not save defaults or repair malformed settings. Explicit changes preserve
unrelated fields, and received settings update the field without echoing a write.

```json
{"version":1,"operation":"cycle-tool"}
{"version":1,"operation":"tool","tool":"rectangle"}
```

`cycle-tool` accepts no extra fields. ControlServer's main-queue handler resolves
`Preferences.drawingTool.next` in toolbar order Pen, Rectangle, Arrow, Text, Number,
then Pen. No plugin sample computes the next tool. Fixed selection uses the
existing strict `tool` operation. Both validate capture/Accessibility before the
existing overlay `chooseTool` path. They turn Interact off while preserving pointer
selection and activation. An off pointer stays off. Capture returns `capturing`
with "Wait for the screenshot to finish before changing drawing tools"; otherwise
missing Accessibility returns `accessibility` with "Allow Accessibility to use
drawing tools". Both failures leave tool, activation and Interact unchanged. A
failure to start drawing input returns `unavailable`. The previous fixed command
incorrectly called every overlay failure an Accessibility failure; capture now
has its actual reason.

`Observed` now consumes the already reported `tool` and `capturing`, alongside
`active`, `interact` and `accessibility`. Missing/unknown tool or capture state is
Tool unknown, never a default Pen or ready. Every tool key displays the actual
observed tool, including a fixed key whose destination differs. Tool symbol/name,
pointer On/Off and Interact/Draw detail stay separate. A lavender border/check
requires active pointer, Interact off, Accessibility and no capture. Lock means
permission missing; hourglass means capture. The existing press border, pending
arc, receipt, rejection, uncertainty, stale and connection states remain distinct.
No requested selection becomes observed state before acknowledgment.

The existing `CycleQueue` now carries typed `SelectionCommand` values captured at
press time. Pointer cycles, tool cycles and fixed tools share one FIFO. keyUp
separates deliberate presses; held duplicate keyDown adds nothing. Settings changes
affect future presses only. One selection request is outstanding. Confirmed replies
advance FIFO; uncertain sent intents are removed permanently. Unsent intents pause
until a later successful safe status read. Page departure/replacement cancels that
key's unsent work, stopped app cancels all unsent work, and nothing survives plugin
exit. Key-incarnation guards cover completion and delayed transient expiry. Existing
Pointer On/Off, Interact and fixed Select Pointer suppression/UUID/settings remain.

### Exact local commands and results

- `bash scripts/run-tests.sh > dist/verification/s021/unit-tests-expanded.log 2>&1`
  passed 71 tests in 12 suites and all three existing source grid lints. Five added
  tests cover strict saved choices/requests, actual observed tools and readiness,
  mixed FIFO snapshots/cancellation, stable app order/wrap and atomic malformed/
  permission rejection, plus capture-specific rejection before permission. Capture
  is canceled synchronously before the async task can take an image or touch the
  clipboard/files. The initial existing 66-test run also passed in
  `unit-tests-initial.log`. No Swift language migration was made.
- `bash scripts/build-review.sh > dist/verification/s021/build-review.log 2>&1`
  passed universal arm64/x86_64 compilation, Developer ID signing, installed
  designated-requirement comparison, notarization, staple, strict/deep signature,
  Gatekeeper, ZIP integrity and extracted archive checks. Installed app is 1.0.2
  build `20261110173607`, bundle `com.austinpresley.pleaselookhere.integration`,
  executable TinyHand, team G2R8798RLT. Notarization Accepted,
  `7c240dff-6331-460b-9eee-9828f01d72f3`. The existing SDK x86_64 deprecation warning
  remains. `app-identity.json`, `app-signature.log`, `app-architectures.log` and
  `app-notarization.json` retain identity evidence.
- `bash scripts/build-streamdeck.sh > dist/verification/s021/build-streamdeck.log 2>&1`
  built universal plugin 1.0.3.0, signed with the same Developer ID team, passed
  Elgato CLI 1.10.0 validation, archive integrity and executable-mode checks.
  Notarization Accepted, `44951054-46a8-4fad-b5f3-5f9753fa5172`. `ditto -x -k`
  extraction passed strict signature, Elgato validation, executable mode, inspector
  presence and byte equality of every payload file. See
  `extracted-plugin-verification.log`, `extracted-payload-checks.json`, plugin
  signature/architecture logs and `plugin-notarization.json`. Stable signed packages
  `Look Here Please-s021-review.zip` and `Look Here Please-s021.streamDeckPlugin`
  plus SHA-256 files are copied into this evidence directory.
- `python3 dist/verification/s021/launch-test.py` used LaunchServices `open -n
  --env ...`, bounded readiness, actual Accessibility/Screen Recording grants and
  matching suite confirmation through `test-shortcuts`. `environment.json` records
  suite `com.austinpresley.tinyhand.s021.92b26d0136364d61944a80f18e6fb71d`,
  `TINYHAND_TEST_MODE=1`, APP_SNAPSHOT and disposable TH_HANDS_DIR
  `/var/folders/8h/r0gxs7ls4kgc804g7lj475q80000gn/T/s021-hands-xu3o5sl7`.
  Fixtures have `custom-s019` with a Robot PNG and `custom-s019-missing` without one,
  using the S-019 manifest schema. Each runner validates its running suite before
  mutation. Between regression lanes, only this test suite was reset through
  `test-shortcuts` command reset, with pointer off and Interact on.
- Ran `python3 -u scripts/deck-tool-replay.py --app "$HOME/Applications/Look Here Please.app"
  --plugin "$PWD/dist/streamdeck/com.austinpresley.lookhereplease.sdPlugin/look-here-please-deck"
  --suite <suite-above> --hands <hands-above> --out "$PWD/dist/verification/s021/tool-replay"`.
  Passed **120/120**. Exact argv is `tool-replay-command.json`; results/logs, every
  received key frame and expected specifications/PNGs are retained. Real plugin
  and app processes communicate over a simulated Stream Deck WebSocket and the
  existing same-user socket fault proxy. Covered full cycle/wrap with pointer off
  and on, fixed choices, Interact transitions, observed external selection,
  malformed choices, seven rapid complete presses, held duplicates, mixed pointer/
  tool FIFO, settings changes after queued presses, external current-tool edits
  between queued cycles, delayed/dropped cycle and fixed replies, read recovery,
  no uncertain replay, page/replacement cancellation, stale/no-reply, permission
  rejection for every choice, stopped/restarted cancellation and recovery.
  Test-only `TINYHAND_TEST_DENY_ACCESSIBILITY=1` exercises real app rejection
  without revoking macOS permission. Proxy requests are `tool-replay/proxy-requests.json`.
- The first replay attempt reached replacement-key checks before its runner
  incorrectly requested status after intentionally disabling safe reads. The
  corrected runner supplies the retained state to the stale-frame fixture. This
  was a runner synchronization error, not a product failure; `tool-replay-attempt1/`
  and `tool-replay-attempt1.log` preserve it. The forwarding proxy restored the app
  socket in its finally path. The final lane passed all 120 checks.
- `python3 -u scripts/deck-cycle-replay.py <same app/plugin/suite/hands> --out
  "$PWD/dist/verification/s021/cycle-replay"` preserved **87/87** S-020 checks.
  `python3 -u scripts/deck-replay.py <same arguments> --current-pointer --out
  "$PWD/dist/verification/s021/current-pointer-replay"` preserved **66/66** S-019
  checks, including pending toggle suppression and fixed disabled/missing rejection.
  Each exact argv is in its `*-command.json`, with received frames and results.
- Python syntax checks passed for all three replay scripts, writing caches only
  into S-021 evidence. `git diff --check` passed. The source proxy change only adds
  tool/cycle-tool to its optional fault operations, retaining prior replay behavior.

### Visual, inspector and hardware checks

Inspected `key-states-72.png` and `key-states-144.png`. Actual received frames show
all five ready tools, independent off/draw and on/off/Interact states, pending,
held, receipt, uncertain, rejected, permission, stale, no-reply and stopped states.
Names/detail are legible and glyphs/marks do not overlap. `accepted-source.json`
identifies the exact received receipt frame. The hourglass sample is explicitly
`capturing-fixture.png`, rendered from a fixture; no desktop screenshot was taken
to test a busy rejection. Native app UI/layout did not change. Three existing grid
lints passed; no new native light/dark page capture or layout probe is claimed.

Served the real inspector with `python3 -m http.server 8766 --bind 127.0.0.1
--directory streamdeck/inspectors`. T3 preview DOM checks passed at 240/320/420 px,
with matching document/viewport widths and no horizontal overflow. The native
SELECT has label "Tool choice", `for=tool`, associated help/order/error via
`aria-describedby`, `aria-invalid` for malformed settings and a role=status error.
A callback/WebSocket fixture confirmed registration, zero opening/default/received-
settings writes and one explicit settings write preserving unrelated fields.
See `inspector-registration-layout.json` and `inspector-behavior.json`.

Two T3 preview snapshots returned `Preview automation snapshot timed out after
15000ms.` T3 `html_preview` rendered the same inspector successfully; inspected
`inspector-240-dark.png`, `inspector-320-dark.png`, `inspector-320-light.png`,
`inspector-420-dark.png` and `inspector-invalid-240.png`. Copy wraps cleanly, error
guidance is visible and the native field fits. System light appearance changes
the native select while the inspector retains Stream Deck's dark palette. Tab
focused the field and the native select API changed it, but T3 synthetic
ArrowDown/Space/Enter did not change its value. Host keyboard selection, VoiceOver
and full Accessibility Inspector acceptance remain pending.

Elgato's official [plugin WebSocket reference](https://docs.elgato.com/streamdeck/sdk/references/websocket/plugin/),
[UI callback/settings reference](https://docs.elgato.com/streamdeck/sdk/references/websocket/ui/)
and [manifest reference](https://docs.elgato.com/streamdeck/sdk/references/manifest/)
were consulted. The SDK documents Encoder separately; this story registers only
Keypad. With no usable physical device, dial behavior is not locally verifiable
and no dial support is added or claimed. Key replay does not test a physical dial.

`hardware-inventory.json` records `/Applications/Elgato Stream Deck.app` 7.6.0,
no matching USB device and no Look Here Please plugin installed. An initial
inventory command guessed the shorter app filename; bundle discovery located the
actual host. No host install/profile/key change occurred. Physical deliberate/
rapid presses, key readability, host inspector and hardware reconnect remain
required acceptance gaps. Intel was cross-built, not run. Older macOS, actual
permission revocation, multi-display and full accessibility audits are unverified.

### Restoration, isolated delta and S-022 handoff

`python3 dist/verification/s021/restore-normal.py` quits the isolated process,
waits for exit and LaunchServices-launches the installed app without overrides.
`restore-checks.json` confirms equal parsed real preferences, pointer/tool/Interact/
activation/settings/shortcuts/catalog/pins, all real hand hashes and every Stream
Deck file hash. No test capabilities/windows remain, and both grants are allowed.
Normal before/after preference exports/state and personal hash records are retained.

`changed-files.json` and `s021-only.diff` isolate this story against starting copies,
including previously untracked plugin sources: 15 modified files and two new
files. All 261 other starting files remain byte-identical. `delta/` contains the
17 final files. `evidence-manifest.json` records package/check/screenshot paths.
No git reset/restore/clean/switch, git add, commit, push, PR or upload was used.

S-022 should package the matching notarized 1.0.3.0 installer above with the app
or resolve a verified matching resource, open it through Stream Deck's normal
installation flow from Settings and test the extracted app resource. This story
does not embed an installer or add Settings installation UI. Keep all prior action
UUID/settings, new tool validation/FIFO rules, app identity and permission grants.
The installed host is available for S-022 installation UI checks; no profile/saved
key may be overwritten. Keep S-020/S-021 physical acceptance open until hardware
passes. Do not start S-022 until the coordinator reviews this isolated change.


## S-020 cycle enabled pointers from Stream Deck, 10 November 2026

Outcome: implementation coordinator-reviewed; physical Stream Deck acceptance pending. Only S-020
was implemented. All tests, builds, signing, notarization, packaging and runtime
checks ran locally on Austin's Apple Silicon Mac, macOS 27.0. Hosted CI stayed
disabled. No nested agent, staging, commit, push, PR, host installation, profile
edit or upload was used. The parent owns coordinator review and final delivery.
Evidence is isolated under `dist/verification/s020/`; earlier story evidence is
preserved. Starting copies/hashes cover all 274 existing tracked/untracked files.

### UX, compatibility and app operation

Choose Pointer is a new action, UUID
`com.austinpresley.lookhereplease.choose-pointer`, with a read-only inspector and
no picker or settings writes. It includes every enabled, available choice, even
unpinned/custom hands. The key shows the acknowledged current hand or Laser dot,
with explicit On/Off and the existing independent input/pending/receipt/error/
uncertain/stale marks. Cycling preserves activation and Interact. The inspector
says to use Pointer On/Off to turn an off pointer on.

Select Pointer retains UUID `com.austinpresley.lookhereplease.select-pointer`,
its fixed picker and saved `style`/`activate` settings. No migration or saved-ID
reinterpretation occurs. S-019's Pointer On/Off UUID and exact style-free `toggle`
request remain unchanged, including suppression of extra pending toggle presses.

The new v1 request is `{"version":1,"operation":"cycle-pointer"}` with no other
fields. ControlServer serializes handlers onto the main queue. ControlBridge
reloads custom manifest membership, reads the current overlay selection and
`PointerCatalog.selectableStyles`, chooses/validates the next pointer and returns
acknowledged state without interleaving another UI/control mutation. The stable
order is built-ins, custom manifest entries, then Laser dot. No next-style value
is computed by the plugin. Toolbar pinned next/previous commands keep their own
semantics. One choice selects itself; outside-current selects the first; empty
usable set rejects with `no-enabled-pointer`. Missing/disabled choices are omitted,
and invalid fields reject before mutation. Selection validation can reject an
asset disappearing during the operation without changing activation/selection.
Normal asset-loss fallback remains separate and app-owned.

### Rapid presses and uncertainty

The first keyDown acts once. Another intent needs keyUp first. Duplicate keyDown
or a hold adds nothing. Rapid complete presses join one in-memory FIFO shared by
visible cycle keys; only one app cycle request is outstanding at a time. A
confirmed reply permits the next unsent intent. Each request re-reads the app's
current selection and catalog, including edits made during a prior delayed reply.

An uncertain sent intent is removed permanently and never retried. Unsent intents
pause until a later successful safe status read, serialized after the failed
request, then continue against current app state. Read failures keep them paused.
A stopped app cancels unsent intents, as does disappearance of their key. A sent
request may still finish. Key-incarnation UUIDs prevent its completion from
changing a replacement key's transient feedback. Queues do not persist across
plugin exit. Confirmed rejection remains an error receipt, with later unsent
intents allowed to continue. Other actions keep their existing pending suppression.

### Exact local commands and results

- `bash scripts/run-tests.sh > dist/verification/s020/unit-tests-final.log 2>&1`
  passed 66 tests in 12 suites and three source grid lints. Five new tests cover
  app/catalog cycle semantics, full enabled order independent of pins, current
  outside set, singleton/empty sets, custom PNG/manifest deletion/restoration,
  active/off preservation, atomic invalid fields, observed cycle faces and FIFO
  uncertainty/cancellation. The initial compile failed only because a test used a
  nonexistent `.wood` convenience member. It now takes the actual last built-in
  from `PointerStyle.builtInHands`. That early log is retained.
- `bash scripts/build-review.sh > dist/verification/s020/build-review.log 2>&1`
  passed local universal release build, Developer ID signing, installed designated
  requirement comparison, notarization, staple, deep/strict verification,
  Gatekeeper, ZIP integrity and extracted-archive checks. Installed app is 1.0.2
  build `20261110171759`, bundle `com.austinpresley.pleaselookhere.integration`,
  executable TinyHand, team G2R8798RLT. Notarization Accepted,
  `b60918b3-3ae7-4ebf-bf96-68ec82c90b83`. The existing SDK x86_64 deprecation
  warning remains; no language migration or new Swift warning was introduced.
- `bash scripts/build-streamdeck.sh > dist/verification/s020/build-streamdeck.log 2>&1`
  built plugin 1.0.2.0 universal, signed it with the same team, passed Elgato CLI
  1.10.0 validation and ZIP integrity/executable-bit checks, and returned
  notarization Accepted, `93a50ce3-9883-4049-a385-c237665addee`. A separate `ditto -x -k`
  extraction passed strict signature and Elgato validation. See
  `extracted-plugin-verification.log`, both notarization JSON files, identity and
  architecture logs. Stable app ZIP/plugin copies and SHA-256 files are in S-020's
  evidence directory so the next story's build cannot overwrite them.
- `python3 dist/verification/s020/launch-test.py` used LaunchServices `open -n
  --env ...`, waited for bounded readiness, confirmed both actual grants and the
  matching suite through `test-shortcuts` before mutation. `environment.json`
  records `TINYHAND_TEST_MODE=1`, suite
  `com.austinpresley.tinyhand.s020.ae8f9cff58d14fbc87da883468faba93`,
  `TH_HANDS_DIR=/var/folders/8h/r0gxs7ls4kgc804g7lj475q80000gn/T/s020-hands-pzsrwdso`
  and APP_SNAPSHOT. Disposable fixtures use `custom-s019` with Robot PNG and
  `custom-s019-missing` without a PNG, reusing the S-019 runner fixture schema.
- `python3 -u scripts/deck-cycle-replay.py --app "$HOME/Applications/Look Here Please.app"
  --plugin "$PWD/dist/streamdeck/com.austinpresley.lookhereplease.sdPlugin/look-here-please-deck"
  --suite <suite-above> --hands <hands-above> --out "$PWD/dist/verification/s020/cycle-replay-accepted"`
  passed **87/87**. `cycle-replay-accepted-command.json` records the exact argument
  vector; `cycle-replay-accepted.log` and `cycle-replay-accepted/results.json`
  retain results. Real app and plugin processes communicate through a simulated
  Stream Deck WebSocket and a disposable same-user forwarding socket proxy.
  The complete enabled set wrapped in library order, including custom/unpinned
  choices and excluding disabled/missing choices. Asset/manifest restoration,
  singleton, active/off preservation, external eligibility edits and invalid
  fields passed. Seven rapid complete presses sent seven advances, duplicate held
  keyDown sent one, and two keys serialized three. A 700 ms delayed first reply
  allowed an external disable/current fallback before the second queued request;
  the next request used that new app state. A delayed dropped reply paused two
  unsent intents during failed reads, then resumed exactly those two, never the
  uncertain request. Page cancellation, unchanged-art deduplication and stopped/
  restarted no-replay passed. Requests are in `proxy-requests.json`; expected
  specifications/PNGs and every captured key frame are retained beside results.
- The initial cycle replay passed 78/78. An expanded attempt's pending-art check
  incorrectly expected a just-written external selection before the plugin had
  observed it. The corrected runner waits for the actual observed frame before
  that pending assertion. This changed only test synchronization. Both early
  attempts are retained as `cycle-replay/` and `cycle-replay-final/` with logs.
- `python3 -u scripts/deck-replay.py <same app/plugin/suite/hands> --current-pointer
  --out "$PWD/dist/verification/s020/current-pointer-replay"` passed **66/66**.
  Its exact argument vector is `current-pointer-replay-command.json`. Preserved
  coverage includes built-in/custom/laser toggles, app-owned fallback, same-ID
  artwork refresh, pending toggle double-press suppression, dropped reply without
  replay, missing art/read recovery, disabled/missing fixed action atomic rejection,
  stopped/restart and inspector recovery. Extending the proxy's fault operations
  to include cycle requests leaves its toggle behavior unchanged.

### Visual checks, SDK evidence and hardware limit

Inspected `key-states-72.png` and `key-states-144.png`, made from captured frames at
those actual sizes. Current off, Laser dot, custom hand, pending, held border,
acknowledged, uncertain and recovery remain readable. The On receipt frame is an
exact captured cycle frame, recorded by `cycle-accepted-on-source.json`; the
shared rejection/stale/no-reply frames come from the preserved S-019 replay.
Glyphs, text and independent marks do not overlap. This is bitmap inspection,
not physical-device readability acceptance. The native app UI did not change;
its existing three grid lints passed and no new app UI snapshots are claimed.

Served the actual inspector using `python3 -m http.server 8766 --bind 127.0.0.1
--directory streamdeck/inspectors`. T3 preview live DOM checks passed at
240/320/420 px, with matching document/viewport width, no overflow and zero
editable controls. A WebSocket callback fixture sent exactly one registration,
zero settings writes and zero app commands. Two preview snapshots failed with
`Preview automation snapshot timed out after 15000ms.` The T3 HTML renderer
successfully rendered the same HTML; inspected/saved `inspector-240-dark.png`,
`inspector-320-dark.png`, `inspector-320-light.png`, and `inspector-420-dark.png`.
The inspector intentionally uses the Stream Deck dark palette in both system
appearances. Text wraps without clipping. Evidence is
`inspector-registration-layout.json`. No host-rendered inspector is claimed.

Elgato's official [plugin WebSocket reference](https://docs.elgato.com/streamdeck/sdk/references/websocket/plugin/)
defines keyDown, keyUp and willDisappear event boundaries. The [UI reference](https://docs.elgato.com/streamdeck/sdk/references/websocket/ui/)
defines the inspector callback/registration. Installed Elgato validator 1.10.0
accepted the manifest and extracted payload. Only Keypad is registered. Dial/tool
controls belong to later work.

`hardware-inventory.json` records Stream Deck host 7.6.0 and no installed Look Here
Please plugin. Read-only USB inventory returned no matching device. The host's
existing registrations can list remembered devices, which is not proof of a
connected usable device. No host plugin/profile/key was installed or changed.
A physical deliberate/rapid press, real-device key readability and host inspector
rendering remain explicitly pending. Full VoiceOver and Accessibility Inspector
acceptance, Intel runtime, older macOS and multi-display behavior were not checked.

### Restoration and S-021 handoff

`python3 dist/verification/s020/restore-normal.py` quits the isolated app, waits
for its process to exit and uses normal LaunchServices launch without overrides.
Normal parsed preferences, pointer state, Interact, tool, enabled/disabled sets,
pins, shortcuts, real custom-hand hashes and every Stream Deck file hash match
the starting copies. Both permissions remain allowed and test-only capabilities
are absent. See `restore-checks.json`, normal before/after exports/state and
personal/real-hand hash records. No real test hotkeys or custom assets were used.

`changed-files.json` lists this child's exact changed/new files with hashes;
`s020-only.diff` compares against the starting copies, including previously
untracked sources. It does not attribute the shared branch's prior changes to
this story. All other starting files remain byte-identical. `git diff --check`
and Python syntax checks passed. No delivery was uploaded.

S-021 can proceed only as the next separately authorized child after review.
Keep this app-owned cycle and S-019's style-free toggle/pending suppression.
`CycleQueue` may serve deliberate tool-cycle intents, but tool selection has its
own Interact and Accessibility rules. Use `PresentationAction.tool != nil` for
tool lists; drawOnly includes history. Do not replace pinned navigation, reenable
preset shortcuts, bypass toolbar visibility gating, or infer tool state from a
requested value. Leave this story's physical acceptance open until real hardware
passes. No S-021 implementation was included here.

## S-019 current-pointer Stream Deck toggle, 10 November 2026

Outcome: done and coordinator-reviewed. Only S-019 was implemented. All tests,
builds, signing, packaging and runtime checks ran locally on Austin's Apple Silicon
Mac, macOS 27.0 build 26A425. Hosted CI stayed disabled. No subagents, staging,
commit, push, PR, host installation or delivery upload were used. The parent owns
queue delivery. Evidence is dedicated to `dist/verification/s019/`.

### Behavior and reconciliation

The existing Pointer On/Off request already sent only v1 `toggle`; the app toggles
activation without changing its selected pointer. The gap was generic hand
feedback and thumbnail loading that depended on a Select Pointer key and rarely
refreshed. The chosen UX was recorded under the doing story before implementation.

The toggle now draws the acknowledged selected hand or Laser dot with explicit
On/Off. An unavailable thumbnail shows an amber image/question symbol with the
observed activation value. It never substitutes another hand. Status still polls
every half second; safe catalog reads refresh every two seconds while pointer
keys are visible, with backoff on failure. Changed PNG bytes invalidate pointer
faces, including same-ID custom replacement. Unchanged catalogs do not repeatedly
send key images. App-owned disable/missing-asset fallback reaches the key through
normal observed state. The serial request queue and independent input border,
pending arc, receipt, rejection, uncertainty and stale marks remain intact.
Pending presses queue no extra mutation; uncertain commands are never replayed.

The read-only inspector says Current pointer and explains where the choice comes
from. It registers through the official
[Elgato property inspector callback](https://docs.elgato.com/streamdeck/sdk/references/websocket/ui/)
and sends no settings writes or app requests. No fixed-toggle override or schema
migration was added. Existing toggle keys keep their UUID and ignore any saved
`style`/`activate` fields. Existing Select Pointer remains a separate fixed action
with app-side validation and short Disabled/Missing rejection text.

### Local commands and results

- `TINYHAND_DEFAULTS_SUITE=com.austinpresley.tinyhand.s019.unit TH_HANDS_DIR=/tmp/s019-unit-hands swift test --filter DeckKeyTests`
  failed before the fix in `unit-before.log`, with eight glyph expectations across
  two new tests. The request-preservation test already passed, confirming existing
  command behavior. All 12 model tests passed afterward in `unit-after.log`.
  Three new tests cover saved/stale selection, every link state, actual
  built-in/custom/laser faces and separate input/transient/observed state.
- `bash scripts/run-tests.sh > dist/verification/s019/unit-tests-final.log 2>&1`
  passed all 61 tests in 12 suites and three existing grid lints. The app retains
  its existing Swift language mode. No app production source/resource changed.
- GUI launches used LaunchServices `open -n --env ...`, followed by bounded status
  readiness, both actual grants and the running process's matching isolated suite
  through `test-shortcuts`. Exact overrides are in `environment.json` and accepted
  state in `test-ready.json`. Suite:
  `com.austinpresley.tinyhand.s019.c520215b72df486da8c43733667f1bc1`.
  The disposable `s019-hands-*` directory had `hands.json` entries `custom-s019`
  and `custom-s019-missing`, each with `id`, `name` and numeric `ink`. Only the
  first had a PNG, copied from `docs/assets/hands/robot.png`.
- With the environment values supplied, ran the following. The exact argument
  list, including the actual temporary hand path, is in `replay-command.json`.

  ```sh
  python3 -u scripts/deck-replay.py \
    --app "$HOME/Applications/Look Here Please.app" \
    --plugin "$PWD/dist/streamdeck/com.austinpresley.lookhereplease.sdPlugin/look-here-please-deck" \
    --out "$PWD/dist/verification/s019/replay" \
    --suite "$TINYHAND_DEFAULTS_SUITE" --hands "$TH_HANDS_DIR" --current-pointer
  ```

  `replay.log` and `replay/results.json` show 66/66 passed. A real plugin process
  used a local simulated Stream Deck WebSocket and the real app control socket.
  Only a toggle key was initially visible, carrying stale saved
  `style:gone, activate:false`. Built-in, laser and custom toggles preserved
  selection both ways. External selection, same-ID image replacement, missing
  image recovery and enabled-set fallback updated the key. Received images exactly
  matched the plugin's observed-state fixture renderer. Specifications and expected
  PNGs are retained in `replay/expected/`. The renderer is available as
  `--render-key <fixture.json> --output <png>`.
- A disposable same-user proxy forwarded requests to the real isolated app. It
  delayed one toggle reply 700 ms, dropped the next reply after the app acted,
  failed safe reads temporarily and omitted thumbnails. Pending, accepted,
  uncertain, stale, unavailable-art and recovery bitmaps matched. A pending double
  press sent one toggle; the dropped reply brought the total to two, with no
  additional mutation during recovery. `replay/proxy-requests.json` records the
  requests. The proxy restores the app socket in `finally`. Disabled Robot and a
  known missing custom image rejected the existing fixed action with
  `activate:true`, preserving selection and activation. Restart/stopped and open
  inspector recovery passed without replay. The base replay measured 6 ms to its
  first press frame and 374 ms for an external activation change to reach the key.
- Early runner evidence remains. `replay-attempt1.log` stopped at Python's
  unsupported string name for Darwin `confstr`, before installing a proxy. It now
  uses `getconf DARWIN_USER_TEMP_DIR`. `replay-attempt2.log` passed 64/66; the
  expected uncertain frame omitted the existing stale badge, and a fixed-action
  fixture incorrectly used the observed hand's thumbnail. Corrected expectations
  produced the final 66/66 without product changes.
- `python3 -u dist/verification/s019/native-ui-replay.py` launched the isolated app
  and final packaged plugin, kept one toggle visible and opened Pointers. A native
  Select Robot click changed the gallery to Robot Selected and the key to the
  exact Robot/Off bitmap. Activation stayed off and Interact stayed unchanged.
  See `native-ui.log`, `native-ui-result.json`, `native-before/after.json`,
  `native-settings-selected.png` and `native-key-selected.png`. No system input
  was injected into another app or an unguarded desktop fixture.
- `swift scripts/check-layout.swift dist/verification/s019/native-settings-selected-layout.json`
  passed 104 probes in 35 areas, in `native-layout.log`. Existing app UI was not
  changed. `python3 -m py_compile scripts/deck-replay.py` passed; its generated
  source-directory cache was removed before the preservation check.
- `bash scripts/build-streamdeck.sh > dist/verification/s019/build-streamdeck-final.log 2>&1`
  built universal arm64/x86_64 plugin 1.0.1.0, Developer ID Application: Austin
  Robinson, team G2R8798RLT, hardened runtime and timestamp. Elgato CLI 1.10.0
  validation passed. Notarization Accepted, submission
  `d0d0b728-e288-45f8-bfdc-eeeef7b84fce`. The earlier complete package was also
  Accepted; the final rebuild includes the inspector registration callback.
- Extracted with `ditto -x -k`; `codesign --verify --strict --verbose=4`,
  `codesign -dvvv --requirements -`, `lipo -archs` and
  `npx --yes @elgato/cli@1.10.0 validate <extracted .sdPlugin> --force-update-check`
  passed. Checked executable mode, inspector resources and byte equality of every
  extracted payload file. Evidence: `extracted-checks.json`,
  `extracted-validator.log`, `extracted-signature.log`, `plugin-identity.log` and
  `plugin-architectures.log`. Stable package `Look Here Please-s019.streamDeckPlugin`
  has SHA-256 `4a065eb69c07be703c55aaf8b3b7b7aca0d38c3a279ff508d4fe5d3d49a1b47a`.
- No app rebuild/notarization was required. Installed 1.0.2 build 20261110164405
  retains bundle `com.austinpresley.pleaselookhere.integration`, executable
  TinyHand and team G2R8798RLT. Fresh deep/strict signature, staple and Gatekeeper
  checks passed. See `machine-build.json` and `installed-*.log`.

### Visual review, restoration and limits

Inspected `key-states-72.png` and `key-states-144.png`, rendered from received
frames at those exact sizes. Robot, Lavender, custom Chrome replacement and Laser
are distinguishable, On/Off is readable and independent marks fit. Unavailable
art keeps Off visible with an amber symbol. Checking, idle stopped, stopped
rejection and No reply remain distinct. Added checking/idle-stopped fixtures
matched captured replay frames exactly.

T3 preview navigation and live DOM/layout checks passed. The inspector has a
heading, short paragraphs, no editable controls, no settings writes and no
horizontal overflow at 240/320/420 px. Two snapshot calls returned
`Preview automation snapshot timed out after 15000ms.` T3 `html_preview` rendered
the same served HTML successfully. Inspected/saved `inspector-240-dark.png`,
`inspector-320-dark.png`, `inspector-320-light.png` and `inspector-420-dark.png`.
Text wraps without clipping. A browser WebSocket fixture confirmed one registration
and zero settings writes in `inspector-registration-layout.json`. Native Settings
capture has active traffic lights and Robot Selected; the key shows Robot/Off.
No Stream Deck host inspector rendering is claimed.

The isolated processes were quit and the installed app launched normally without
overrides. The first restore raced process exit and LaunchServices returned
error -600. Final `restore-normal.py` waits for process exit and passed.
`restore-checks.json` confirms equal parsed real preferences, real custom-hand
hashes, every Stream Deck file hash, saved/runtime state, no test operations or
windows, and both permission grants. No real profile, saved key, preference or
asset was reset. No physical hardware, host installation, Intel runtime, older
OS, multiple displays, actual permission revocation, VoiceOver session or full
Accessibility Inspector audit is claimed.

`changed-files.json` and `s019-only.diff` isolate the story against 273 starting
file copies/hashes. Only the documented 14 source/test/doc files changed; all
other starting files were preserved. `git diff --check` and whitespace checks on
the isolated delta passed. No earlier story evidence was overwritten.

For S-020, keep the toggle UUID and style-free request. No toggle schema migration
is needed. The fixed Select Pointer UUID/inspector are unchanged. Cycling still
needs an app-owned atomic operation over `PointerCatalog.selectableStyles` /
`state.enabledPointers`, containing all enabled available choices in library order,
independently of toolbar pins. No cycle, tool key, installer Settings, radial or
branding work was added.

## S-018 enabled pointer choices, 10 November 2026

Outcome: done and coordinator-reviewed. Only S-018 was implemented. All tests,
builds, notarization and native runtime checks ran locally on Austin's Apple
Silicon Mac, macOS 27.0 build 26A425, one 1920 x 1080 display. Hosted CI stayed
disabled. No subagents, staging, commit, push, PR or delivery upload was used.
The normal app and its original saved state were restored.

### Decisions and behavior

The UX was recorded under S-018 with status doing before coding. Settings keeps
the toolbar pin row and adds the complete Pointer library, with native Enabled
checkboxes and separate Select buttons. Built-in hands, custom hands and Laser
dot remain discoverable when disabled. Missing images say "Image unavailable".
A disabled choice keeps its image, custom metadata and saved pin order. Reset
All enables everything without deleting hands or assigning shortcuts. Reset
of the toolbar affects pins only. New choices start enabled; a disabled-ID set
preserves every previously available choice during upgrade.

`PointerCatalog` owns eligibility and validation. Its stable order is the built-in
library, custom manifest order, then Laser dot. Disabling the selected choice
chooses the first remaining enabled available entry, with activation and Interact
unchanged. The final usable choice rejects with "Keep at least one available
pointer enabled." The checkbox stays checked. Feedback appears both near the
library heading and inside the affected card, so a rejection remains visible
when the choice is at the bottom of a long library.

Pins and Enabled are separate. The live toolbar and existing next/previous
pinned commands filter saved pins to enabled available choices. If all saved
pins are unusable, the toolbar temporarily offers the first enabled available
library entry without writing any pin. The Settings pin row still shows disabled
favorites, dimmed with explanatory help. The pin picker filters eligibility.

Custom metadata reloads and file availability refreshes on the main run loop
within one second. Missing or corrupt images cannot be selected, even with an
old render-cache hit. Restoring a PNG restores its eligibility and thumbnail
without stealing selection. Removed manifest entries are unknown IDs; restoring
the same ID recovers its saved disabled state. Invalid saved IDs are replaced
with the fallback so reappearing manifest entries do not unexpectedly become
selected. External loss of the sole usable enabled custom hand enables the
first available built-in, or Laser dot if no hand loads, and selects it.

The v1 JSON protocol adds `enable-pointer`, complete `styles` eligibility metadata
and `state.enabledPointers`, `quickPointers`, `disabledPointers`. Existing fields
and operations remain. UI, JSON and AppleScript selections reject before changing
selection or activation. `configure` rejects the entire batch. Missing images
use `missing-asset`; available disabled choices use `disabled-style`, AppleScript
1006. See [control-protocol.md](control-protocol.md) for complete examples and
in-process API guidance. No Stream Deck actions, inspectors or radial controls
were changed. S-019 and S-020 must use the app-owned eligibility API, not pins.

### Local verification

Evidence is under `dist/verification/s018/`. `environment.json` records the unique
isolated defaults suite and disposable `s018-hands-*` directory. The fixture
manifest has one real custom PNG and one intentionally missing PNG. Every GUI
launch used LaunchServices with explicit overrides, followed by a bounded
readiness check and verification of both grants and the matching suite. The
normal preference domain and real hand directory were never reset or mutated
by tests.

- `bash scripts/run-tests.sh > dist/verification/s018/unit-tests-final.log 2>&1`
  passed 58 tests in 12 suites and the three existing grid lints. Six new catalog
  tests cover fresh/default/reset behavior, persisted storage, pin independence,
  stable current-choice fallback, one-notification updates, last-choice rejection,
  unavailable/disabled batch rejection, stale image caches, corrupt/missing PNGs,
  removal/reappearance and manifest restoration. The final focused six-test run
  is in `catalog-tests-final.log`. `scripts/grid-lint.sh Sources/TinyHand/PointerLibrary.swift`
  passed separately in `library-grid.log`.
- With `environment.json` exported, `python3 scripts/pointer-smoke.py` passed nine
  runtime checks. It confirms its isolated suite before resetting, tests JSON
  and native AppleScript disabled errors, rejects the legacy laser command
  before activation, checks unpinned choices in the full enabled catalog, tests
  custom PNG loss/restoration and sole-custom recovery, and verifies Reset All
  leaves every shortcut unassigned. `pointer-smoke-packaged.log` and
  `pointer-smoke.json` retain the packaged runtime results. Custom-image cache
  invalidation and thumbnail regeneration were also checked at the unit seam.
- Native Settings checkbox actions disabled the selected Lavender toy and
  selected Cursor glove as the ordered fallback. Separate native actions enabled
  the custom Fixture robot and Laser dot, selected the custom hand without
  activating the overlay, and disabled it while keeping its thumbnail. Pins did
  not change. `native-disabled-lavender.json`, `native-custom-selected.json` and
  `native-bottom-state.json` record readback. Native last-choice rejection kept
  the checkbox checked and showed its explanation in place; see last-choice
  captures and `native-last-rejected.json`.
- Clean app quit/relaunches retained the native saved disabled choice, custom
  selection and enabled set. The final fallback-only toolbar also survived a
  clean relaunch. `updated-ready.json`, `final-ready.json` and
  `packaged-ready.json` retain these checks. Both actual permissions remained
  granted. Reset used disposable preferences through the existing test bridge.
- `python3 scripts/toolbar-smoke.py` passed all 19 native opacity checks in
  `toolbar-smoke.log/json`, preserving S-016 behavior through activation, settings,
  hover, modes, timed auto-hide and reveal. It reads WindowServer opacity, not
  just reported visibility. `python3 scripts/live-smoke.py` passed 13 native input,
  annotation, explicit shortcut, motion, toolbar drag and capture checks in
  `live-smoke.log/json`. The public fixture was confirmed frontmost with bounded
  coordinates before input. Neither test installed real shortcut assignments.
- `TINYHAND_SNAPSHOT_SECTIONS=pointers python3 scripts/snapshot-settings.py` and
  the retained `capture-settings-state.py` captured active key Settings windows.
  `swift scripts/check-layout.swift` passed six affected reports, recorded in
  `layout-checks.log`. Top captures have 41 probes in 14 areas; bottom captures
  have 122 in 41; rejection captures have 124 in 41. The initial flexible columns
  failed whole-pixel checks; `snapshot-top.log` and `layout-before/` retain that
  failure. Fixed 172 pt columns pass. A restored custom thumbnail initially
  disappeared because the availability refresh cleared its icon cache. The fix
  regenerates the thumbnail and invalidates eligibility when explicitly forgotten.
- `bash scripts/build-review.sh > dist/verification/s018/build-review-release.log 2>&1`
  passed universal arm64/x86_64 release compilation, Developer ID signing,
  installed designated-requirement comparison, notarization, stapling, deep/strict
  signature checks, Gatekeeper, archive integrity and extracted-archive checks.
  Installed version 1.0.2, build `20261110164405`,
  bundle ID `com.austinpresley.pleaselookhere.integration`, executable TinyHand, team G2R8798RLT.
  Notarization Accepted, submission `4bc7ef84-3c2a-4012-a0ce-112f34dfaf01`. The existing SDK x86_64
  deprecation warning remains. `package-identity.json`, `installed-signature.log`,
  `architectures.log` and `notarization.json` retain identity evidence. The final
  stable package is `Look Here Please-s018-review.zip`, with its SHA-256 file.
  A final wording correction directs a full-toolbar hand import to remove a pin
  and use +, matching the retained pin picker.
- `git diff --check` passed. `changed-files.json` and `s018-only.diff` isolate this
  child's changes from the starting copies and hashes. No earlier authorized
  work was staged, reverted or committed.

### Visual review, restoration and limits

Inspected light and dark `settings-pointers`, `library-bottom`, `last-choice`,
`pin-picker`, `toolbar-enabled`, `toolbar-drawing` and `toolbar-fallback` PNGs.
The gallery has readable labels and controls, retained disabled thumbnails,
separate unavailable-image feedback and no overlapping content. The long library
scrolls normally. Last-choice text wraps inside its card. The pin picker omits
Cursor glove and Robot when disabled. Live toolbar captures show only enabled
favorites, then a single unpinned Bubblegum fallback with saved pins unchanged.
The toolbar is deliberately nonactivating; Settings captures have active traffic
lights. Captures include only app-owned windows and the public fixture.

The fixture and isolated app were quit, and the installed app was launched
normally without overrides. `restore-checks.json`, normal before/after preference
exports, hand hashes and `normal-final-state.json` prove matching real saved
preferences, assets, selection, mode, activation, pins, settings and shortcuts.
No Settings window or test operations remain; both permissions are granted.

Native Accessibility inspection checked checkbox names/IDs, values, disabled
Select state and help. Escape dismissed the pin picker and Command-W closed
Settings. Tab did not advance controls under the current Mac keyboard-navigation
configuration. No full keyboard-only flow, VoiceOver session or Accessibility
Inspector audit is claimed. No physical Stream Deck, older OS, Intel runtime or
multi-display test was performed. External file changes use a one-second refresh;
this is not an asset-folder watcher or a crash-durable database transaction.

## S-016 floating toolbar visibility, 10 November 2026

Outcome: done and coordinator-reviewed. Only S-016 was implemented. All tests,
builds, packaging and native verification ran locally on Austin's Apple Silicon
Mac, macOS 27.0 build 26A425, one 1920 x 1080 display. Hosted CI stayed disabled.
No commit, staging, push, PR or interim delivery upload was made. The normal app
was restored after verification.

### Repro, minimization and diagnosis

The initial status-only check briefly failed immediately after a setting write,
then passed after allowing the normal service tick. With Settings closed, simple
OFF/mode/auto-hide status checks also passed. This did not establish that the
native panel was actually hidden. Further inspection found the exact reported
symptom: Show toolbar OFF and `toolbarVisible=false`, with a real opaque panel
still onscreen after pointer reactivation.

Before changing product code, constructed and ran this deterministic one-second
command against the installed build 20261110153518:

```sh
python3 dist/verification/s016/minimal-repro.py minimal-before-1.json
# Show toolbar=False reported visible=False native panel opacity=1
# AssertionError: FAIL floating toolbar remains visible with Show toolbar OFF after pointer reactivation
```

It seeds a visibly enabled panel, turns the pointer off, disables Show toolbar,
then activates the pointer. WindowProbe reads only the app's WindowServer windows
and asserts the panel's real opacity, rather than trusting its cached flag. Three
consecutive runs failed identically. Evidence: `minimal-before-1/2/3.json` and
`.log`, `native-window-before.json`, and `toolbar-stuck-before.png`. The earlier
status-only iterations and their precise results are retained as
`repro-before-initial.log`, `minimization.json`, `repro-before-settled.log` and
`repro-before-closed.log`.

Ranked falsifiable hypotheses were communicated before testing their boundaries:
stale native panel state after hide/reactivate; an unconditional activation
reveal; hover/deadline recovery; and permission recovery overriding the preference.
The first two form the confirmed chain. `Toolbar.hide()` set `revealed=false`
but retained alpha 1. Activation's unconditional `show()` ordered the panel back
onscreen. `setRevealed(false)` returned early on the already-false flag. Remaining
away past the reveal deadline could not reconcile that mismatch. Both actual
permissions were granted, ruling out permission denial as the primary repro.
Targeted WindowServer alpha/ordering samples and native NSPanel assertions were
the instrumentation. No production debug logs were added.

The regression was written before the fix at the real multi-caller seam:
`OverlayController.activate -> deactivate -> activate`, changing the saved
preference while inactive. It failed at `!panel.isVisible || panel.alphaValue == 0`
in `regression-before.log`; the logical visibility assertion alone had passed.
It passed after the fix in `regression-after.log`.

### Behavior and UX

`Toolbar.setRevealed` now reconciles native ordering, opacity and mouse handling.
`revealed` derives from actual panel visibility and alpha. There is no separate
unconditional `show()` path. One controller method gates startup, preference,
hover and permission-recovery reveals with active pointer + Show toolbar enabled.
Permission recovery retains the existing menu/welcome access and cannot force an
off toolbar onscreen. The controller accepts an Accessibility dependency for a
deterministic denied-access regression; production still uses AXIsProcessTrusted.
No real permission was revoked.

Enabling Show toolbar while the pointer is active reveals it immediately for the
existing three seconds, even after an older reveal deadline expired. Pointer
startup also gives three seconds. Hover near its last position keeps/reveals it;
moving away hides it after any startup grace. Drawing suppresses it. Disabling
hides immediately and stays hidden through pointer, hover, Settings and Interact
changes. Enabling while the pointer is off does not activate either pointer or
panel. Existing preference storage, Interact keep-hand behavior, shortcut defaults,
macOS Dock preferences and app Dock-icon policy were left unchanged.

Appearance uses "Show toolbar" consistently for the row and native switch. Visible
copy explains reveal, hide and the off state; help gives the three-second timing
and menu bar access. The story's UX block and glossary record those choices.

### Exact local commands and results

Evidence is dedicated to `dist/verification/s016/`. `environment.json` records the
isolated suite, temporary hand directory and capture directory. GUI launches used
LaunchServices, then bounded status readiness checks confirming both grants and
the matching isolated suite. No direct shell GUI launch inherited TCC identity.

```sh
open --env TINYHAND_TEST_MODE=1 \
  --env TINYHAND_DEFAULTS_SUITE=com.austinpresley.tinyhand.s016.7c0a68f260cf4d459f0294d1c2b126db \
  --env TH_HANDS_DIR=/var/folders/8h/r0gxs7ls4kgc804g7lj475q80000gn/T/s016-hands-zx6x8d_y \
  --env APP_SNAPSHOT="$PWD/dist/verification/s016" \
  "$HOME/Applications/Look Here Please.app"
# dist/verification/s016/launch-test.py retains the launch/readiness/relaunch helper.
```

- `TINYHAND_DEFAULTS_SUITE=com.austinpresley.tinyhand.s016.unit TH_HANDS_DIR=/tmp/s016-unit-hands swift test --filter ToolbarTests` failed before the fix and passed afterward. Final `bash scripts/run-tests.sh > dist/verification/s016/unit-tests.log 2>&1` passed all 52 tests in 11 suites and all three existing grid lints. Added three regressions covering opaque reactivation, cold disabled activation/denied Interact changes, and immediate native reconciliation through preference and toolbar toggles.
- `bash scripts/build-review.sh > dist/verification/s016/build-review.log 2>&1` passed universal arm64/x86_64 release compilation, Developer ID signing, comparison with the installed designated requirement, notarization, staple validation, deep/strict signature verification, Gatekeeper, archive integrity and extracted-archive checks. Installed version 1.0.2, build `20261110160823`, bundle ID `com.austinpresley.pleaselookhere.integration`, executable TinyHand, Developer ID team G2R8798RLT. Notarization Accepted, submission `6a890076-cbc5-4f1d-bb65-5c47738afc87`. The existing SDK x86_64 deprecation warning remains. See `notarization.json`, `package-identity.json`, `installed-signature.log` and `architectures.log`.
- `python3 dist/verification/s016/minimal-repro.py minimal-after.json` reran the exact original command on the installed update. Output: `Show toolbar=False reported visible=False native panel opacity=0`, then PASS. `python3 dist/verification/s016/visibility-repro.py original-after.json` also passed the earlier complete setting/mode/auto-hide scenario. Logs are `minimal-after.log` and `original-after.log`.
- With the values from `environment.json` exported, `python3 scripts/toolbar-smoke.py --repro-only` passed the reusable native regression. `python3 scripts/toolbar-smoke.py` passed all 19 checks. It compiles `Tests/Fixtures/ToolbarProbe.swift` locally, validates the matching isolated suite, and requires a frontmost visible public fixture and in-window coordinates before every injected move. Checks include OFF hover/modes in Original and Responsive, re-enable after an expired deadline, timed auto-hide, hover persistence/exit, inactive enabling and pointer reactivation. It reads actual WindowServer panel alpha as well as status. See `toolbar-repro.log/json` and `toolbar-smoke.log/json`.
- Native Settings switch clicks saved OFF and ON. Normal Command-Q plus `python3 dist/verification/s016/launch-test.py relaunch-off.json false` and `... relaunch-on.json true` retained each choice. Native Settings agreed after both relaunches. Activating after OFF stayed natively hidden; ON allowed startup reveal. See `native-setting-off/on.json`, `relaunch-off/on.json`, `relaunch-off/on-activated.json` and `settings-close-off.json`.
- With Show toolbar OFF and pointer active, opened the actual status menu with a native right click, then invoked its enabled Settings item through Accessibility. Settings opened with the saved switch still OFF and toolbar hidden. See `menu-open-hidden.json`, `menu-settings-action.log` and `menu-settings-state.json`. The retained `MenuProbe.swift` reads app-owned status-item geometry and dispatches only to that item. The public canvas intentionally sits above the menu bar, so it was quit for this check. Initial clicks while it covered the menu bar did not reach the app's status item.
- `TINYHAND_SNAPSHOT_SECTIONS=appearance python3 scripts/snapshot-settings.py` with the isolated environment captured active, key Appearance windows in light/dark; the same bridge captured OFF states. One OFF capture correctly refused when Settings lacked focus; reopening the section and satisfying its existing focus guard produced both valid captures. `python3 dist/verification/s016/capture-toolbar.py` saved six real toolbar/public-fixture crops. An initial fixture-readiness guard refused input; after confirming its frontmost window the capture run passed. No private desktop was captured.
- `swift scripts/check-layout.swift dist/verification/s016/*-layout.json` passed four affected reports, each with ten probes in five areas. `git diff --check` passed. No `[DEBUG-...]` instrumentation remains. Debug helpers and early iterations are retained only under the dedicated verification folder.

### Visual review and restoration

Inspected `settings-appearance-light.png`, `settings-appearance-dark.png`,
`settings-appearance-off-light.png` and `settings-appearance-off-dark.png`. The
label, explanation, native on/off values and Position row fit without clipping,
overlap or an unintended focus ring. Both captures have active traffic lights.
The explanation wraps to two lines and the Settings window fits its content.

Inspected `toolbar-interact-light.png`, `toolbar-interact-dark.png`,
`toolbar-drawing-light.png` and `toolbar-drawing-dark.png`. Pointer choices,
Interact, actions, tools and color selections are readable and fit their native
panel in both appearances. These panels deliberately cannot become key. The
`toolbar-hidden-light.png` and `toolbar-hidden-dark.png` public-fixture crops show
no toolbar at the same location; part of the independent hand rod crosses the
crop. `toolbar-stuck-before.png` shows the formerly opaque disabled panel.

The fixture and test app were quit, then the installed app was opened normally
without overrides. `normal-final-state.json` has no test operations and retains
both permissions. Parsed real preference exports match exactly before/after;
settings, selection, pins, Interact, shortcuts and inactive pointer state match
the normal starting state. The real custom-hand directory is empty and matches
the prior story's retained baseline. Test hands always used TH_HANDS_DIR. See
`restore-checks.json`, the normal preference exports and `real-hands-final.json`.

The exact ten-file source/documentation manifest and before/after hashes are in
`changed-files.json`. `s016-only.diff` compares against this child's starting
copies, preserving prior modified/untracked work. All 220 starting files
were checked: seven expected edits and 213 unchanged files. Three new files
complete the ten-file manifest. No S-015/S-017
verification artifact was overwritten.

No S-016 acceptance gap remains on this Mac. Intel was cross-built, not run.
Physical mouse/trackpad use, older OS versions, multiple displays and a full
VoiceOver/Accessibility Inspector audit were not performed. Missing-permission
visibility is covered by the injected native-controller regression, not a revoked
TCC grant. The parent owns final queue delivery and coordinator review.

S-018 can proceed after review. This change introduces no new pointer-selection,
pinning or enablement semantics. Preserve the optional unassigned shortcuts and
S-017 keep-hand behavior. Route future toolbar state through the single visibility
method and use native opacity assertions when checking that a panel is hidden.

## S-017 keep-hand option in Interact, 10 November 2026

Outcome: done by fresh verification. The existing S-004 implementation satisfies
this request in the normally installed `~/Applications/Look Here Please.app`,
version 1.0.2, build `20261110153518`. No production source, preference semantics,
UI layout, shortcut assignments or signing identity changed. Only STORIES.md and
this validation record were edited by this child outside ignored verification
artifacts. S-016 stayed outside this task; no Dock or toolbar hiding work was
performed. The coordinator clarified S-016 in the shared docs while this check
was running; those edits were preserved.

### Reconciliation and discoverability

`Preferences.interactKeepsHand` already defaults to true and respects a stored
false value. Reset All removes the stored key, restoring true. General places
one native switch immediately below Interact in the first card, with the label
"Keep the hand visible while interacting" and a visible explanation of the off
behavior. Neither the switch nor its explanation requires scrolling on this Mac.
The Accessibility tree exposes that full label and the current on/off value.

The Settings binding writes the same preference that `OverlayController.updateZones`
reads. SettingsModel observes the shared preference notification. Native switch
clicks changed runtime readback, and a control-protocol change refreshed the
already open native switch. The runtime checks all 32 mouse-button states when
applying the visibility rule. It restores the system cursor while hiding the
hand. The old false-default implementation note under S-004 was stale and has
been corrected; no duplicate setting or new behavior was justified.

### Local commands and results

All checks ran locally on Austin's Mac, Apple Silicon, macOS 27.0 build 26A425,
one 1920 x 1080 display. Hosted CI stayed disabled. Evidence is under
`dist/verification/s017/`; the disposable helper and runner sources are retained
there so the native checks are reproducible without rebuilding the product.

- `bash scripts/run-tests.sh > dist/verification/s017/unit-tests.log 2>&1`
  passed all 49 tests in 10 suites and three source grid lints. Existing
  InteractionTests cover the true fallback, stored false, Reset All and the
  Interact visibility rule. No new implementation-mirroring tests were added.
- Test launches used LaunchServices, never direct GUI execution from the shell:

  ```sh
  open --env TINYHAND_TEST_MODE=1 \
    --env TINYHAND_DEFAULTS_SUITE=com.austinpresley.tinyhand.s017.0c681d9462f04b96a17a88e7b96644da \
    --env TH_HANDS_DIR=/var/folders/8h/r0gxs7ls4kgc804g7lj475q80000gn/T/s017-hands-w16vur7_ \
    --env APP_SNAPSHOT="$PWD/dist/verification/s017" \
    "$HOME/Applications/Look Here Please.app"
  ```

  The exact environment is in `environment.json`. Each launch waited for status
  readiness and confirmed both permission grants and test-only capabilities.
  The runner also checked that the running app reported the same isolated suite.
- Fresh state reported keep-hand true. Native General clicks saved false without
  changing Interact, the selected Lavender hand or pointer activation. Toggling
  Interact off, then the visibility choice, left Interact off and the hand
  selection unchanged. A protocol write back to true updated the existing switch.
  Evidence: `fresh-state.json`, `native-switch-off.json`,
  `native-independent-off.json` and the native computer-use transcript.
- Quit the test instance with native Command-Q, then ran
  `python3 dist/verification/s017/relaunch.py relaunch-keep-off false`.
  Readback and the native switch retained false. A native switch click then
  explicitly saved true, confirmed in `explicit-on-preferences.plist`. After
  another native quit,
  `python3 dist/verification/s017/relaunch.py relaunch-keep-on true` passed.
  Relaunch reports are `relaunch-keep-off.json` and `relaunch-keep-on.json`.
- `bash scripts/build-fixture.sh` compiled and signed the disposable public
  canvas locally. Its output is `build-fixture.log`. Compiled the per-run native
  input helper with
  `swiftc dist/verification/s017/InteractionProbe.swift -o dist/verification/s017/InteractionProbe -framework AppKit -framework ApplicationServices`.
  Then ran:

  ```sh
  open -a "$PWD/dist/verification/TinyHandFixture.app"
  python3 dist/verification/s017/runtime-checks.py > dist/verification/s017/runtime-checks.log 2>&1
  ```

  All eight grouped native checks passed. The helper requires the visible,
  frontmost public fixture, validates each coordinate against its window,
  reads actual button states and fixture counters, and releases held buttons on
  exit. Initial attempts correctly refused all input because T3 was frontmost;
  explicit fixture activation resolved this setup issue. No product bug resulted.
- With the Robot hand selected, native button clicks and canvas drags reached
  the fixture in both Original and Responsive motion, with keep-hand on and
  off. Button/down/up/drag counters advanced, and no annotations appeared in
  Interact. Status was sampled during held presses and drags, not just after
  release. Enabled kept the selected hand visible; disabled hid it and restored
  it on release. Cropped screenshots of guarded public fixture content confirm
  the Robot hand when enabled and the system arrow when disabled.
- Overlapping left and middle buttons with keep-hand off stayed hidden after
  releasing left while middle was still down. The final release restored the
  hand. Changing keep-hand false -> true -> false during a held left press
  immediately changed visibility, preserving Interact and Robot selection.
  Switching Interact off/on during that press retained the visibility choice.
  Drawing with Interact off and keep-hand false kept the hand visible, produced
  one annotation and left the fixture counters unchanged. Changing keep-hand
  while the pointer was off never activated it or changed selection.
  All sampled state, native button state and fixture counters are in
  `runtime-checks.json`; `runtime-checks.log` lists the eight passes.
- Native About -> Reset all settings -> Reset restored the General switch to on.
  Runtime readback agreed, and `reset-preferences.plist` confirmed the stored key
  was removed. Evidence: `native-reset-state.json` and
  `settings-general-after-reset-light.png`.
- With `environment.json` applied and `TINYHAND_SNAPSHOT_SECTIONS=general`, ran
  `python3 scripts/snapshot-settings.py` for enabled light/dark snapshots, then
  used the same `snapshot-settings` bridge for disabled light/dark and the reset
  state. Inspected all five key-window captures. The control and explanation fit
  in both appearances with no clipping or unintended focus ring.
  `swift scripts/check-layout.swift dist/verification/s017/*-layout.json`
  passed all five reports, each with ten probes in five areas. Logs are
  `settings-snapshots.log` and `layout-checks.log`.
- No product rebuild or new notarization submission was needed. Fresh installed
  `codesign --verify --deep --strict --verbose=2`, `codesign -dv -r-`,
  `spctl --assess --type execute -vv` and `xcrun stapler validate` checks all
  passed for the existing build. Its bundle ID, hardened runtime and Developer ID
  team G2R8798RLT remain intact. See `installed-signature.log`,
  `installed-gatekeeper.log`, `installed-staple.log` and `machine-and-build.json`.

### Screenshots and handoff

Settings evidence:
`settings-general-light.png`, `settings-general-dark.png`,
`settings-general-keep-off-light.png`, `settings-general-keep-off-dark.png`,
`settings-general-after-reset-light.png`.

Native press/drag evidence:
`keep-on-original-canvas-down.png`, `keep-on-original-canvas-drag.png`,
`keep-off-original-canvas-down.png`, `keep-off-original-canvas-drag.png`,
`multi-middle-still-down.png`.

The fixture and test-mode app were quit. A normal `open` of the installed app,
with no test overrides, was ready and retained both permissions. Saved settings,
selection, Interact and inactive pointer state matched the normal starting state.
Parsed exports of Austin's real preferences matched before/after, as did every
real custom-hand file hash. Evidence: `normal-final-state.json` and
`restore-checks.json`. No clipboard capture or real hand-library edits occurred.

`git diff --check` passed. Starting-file hashes confirm all production source,
tests, scripts and assets stayed unchanged. The only additional observed file
change was the coordinator's S-016 clarification in FEEDBACK-2026-11-10.md; its
related STORIES.md edits were also preserved. See `starting-files.json`,
`changed-files.json`, `s017-only.diff` and `preservation-check.json`. No commit,
push, PR or upload was made; the coordinator owns final queue delivery.

No S-017 acceptance gaps remain on this Mac. Native system events were injected
over the public fixture; no physical mouse/trackpad, older OS, Intel runtime,
multi-display, full VoiceOver or Accessibility Inspector audit is claimed.
Future checks should use LaunchServices and wait for readiness, explicitly focus
the fixture, and keep `interactKeepsHand` independent of Interact and selection.
The existing `scripts/interaction-smoke.py` only covers a held left press and
writes to the shared verification root; this run used the retained per-story
runner to avoid overwriting earlier evidence. It sends no shortcut events, so it
needs no assigned hotkeys after S-015.

## S-015 user-assigned presentation shortcuts, 10 November 2026

Outcome: done. Only S-015 was implemented. All tests, builds, packaging and runtime
checks ran locally on Austin's Mac. Hosted CI remained disabled. No commit, push,
PR or final delivery was made from this child task.

### Behavior

- Fresh preferences and Reset All leave all 18 presentation/tool commands
  Unassigned. Missing and cleared keys never fall back or register globally.
  Existing saved dictionaries remain user assignments, including an explicitly
  saved combination equal to an old preset. No migration writes implicit defaults.
- Each row records and clears an optional assignment. The command name and current
  value are exposed through Accessibility. Clear disables for Unassigned. Duplicate,
  reserved and unavailable combinations retain the prior assignment and explain the
  rejection beside the recorder. Assignment and registration failures also remain
  available in the existing Settings feedback.
- Annotation Undo/Redo, Open Settings and Turn Pointer Off are configurable.
  Removed the separate global Escape registration and hard-coded global
  Command-Z, Command-Shift-Z and Command-comma registrations. Native Edit commands,
  Command-comma in the application menu, and Escape cancellation in editors/menus
  remain local app behavior.
- Menu equivalents clear when assignments clear. Toolbar help omits empty
  shortcut suffixes and refreshes Undo, Clear, Interact, capture, tools and exit
  help from current assignments. Welcome copy advertises no preset shortcuts;
  the toolbar demo hint no longer advertises Escape.
- Status reports each shortcut as an object or JSON null. Normal `configure`
  remains unchanged and cannot implicitly install shortcuts. The test-only
  `test-shortcuts` operation calls the same assignment path as Settings, requires
  an isolated suite, and is absent in normal app capabilities.

### Exact local verification

- `bash scripts/run-tests.sh`: 49 Swift Testing tests in 10 suites passed, plus
  all three existing Settings grid lints. Added coverage for empty/reset state,
  every command's assign/clear storage, legacy saved assignments, malformed stored
  values, reserved native keys and optional help. The final run is
  `dist/verification/s015/unit-tests.log`.
- `bash scripts/build-review.sh`: universal arm64/x86_64 release build, Developer
  ID signing, installed designated-requirement comparison, notarization, staple
  validation, deep/strict signature checks, Gatekeeper and extracted ZIP checks
  passed. Version 1.0.2, build 20261110153518; notarization
  Accepted, submission `1d1b6445-1de1-4b26-b1ff-3e92676213fd`. Bundle ID remains
  `com.austinpresley.pleaselookhere.integration`, executable TinyHand, team G2R8798RLT.
  The SDK's existing x86_64 deprecation warning remains. Full output and identity
  are in `dist/verification/s015/build-review.log`, `notarization.json` and
  `package-identity.json`.
- Runtime launch used LaunchServices and only disposable data:

  ```sh
  export TINYHAND_DEFAULTS_SUITE=com.austinpresley.tinyhand.s015.68c28af8a27045a6875d3a730e057bae
  export TH_HANDS_DIR=/tmp/s015-hands-8c58a6a59c7e47b7b70c91307aafa62b
  export TINYHAND_TEST_MODE=1
  export TINYHAND_VERIFICATION_DIR="$PWD/dist/verification/s015"
  export APP_SNAPSHOT="$TINYHAND_VERIFICATION_DIR"
  open --env TINYHAND_TEST_MODE=1 \
    --env TINYHAND_DEFAULTS_SUITE="$TINYHAND_DEFAULTS_SUITE" \
    --env TH_HANDS_DIR="$TH_HANDS_DIR" --env APP_SNAPSHOT="$APP_SNAPSHOT" \
    "$HOME/Applications/Look Here Please.app"
  python3 scripts/shortcut-smoke.py
  # Quit the test app, relaunch with the same command and suite, wait for status.
  python3 scripts/shortcut-smoke.py --after-relaunch
  ```

  Both phases passed. All 18 commands assigned/cleared, fresh pointer off/on
  registered zero keys, duplicate/reserved feedback preserved saved values, a
  real competing Carbon process rejected a replacement for the registered toggle
  and restored its old registration, and menu equivalents matched assignments.
  Relaunch retained custom toggle/capture assignments and a cleared Pen; Reset All
  removed the last registration. Evidence: `shortcut-smoke.log/json`,
  `shortcut-relaunch.log/json` and `expected-relaunch.json` under the S-015 folder.
- The first competing-process check exposed the existing use of shared Carbon
  registrations: it incorrectly accepted the occupied combination. The installed
  SDK's CarbonEvents.h documents `kEventHotKeyExclusive`; HotKeyCenter now requests
  it. The same real competing-process check passed afterward. The fixture source
  is `Tests/Fixtures/ShortcutBlocker.swift`, compiled locally by the smoke script.
- `bash scripts/build-fixture.sh` followed by
  `python3 scripts/live-smoke.py` with the environment above: all 13 native-input
  checks passed over the visible public canvas. The script now explicitly assigns
  its tool, history, Interact, toolbar and capture keys. Its output and captures
  use the selected verification directory. Real annotation Undo/Redo, tool keys,
  toolbar/Interact keys and a valid screenshot all passed. Evidence:
  `live-smoke.log/json` and `captures/`.
- Native computer use: recorded Control-Option-K in Settings, rejected Command-Z
  with a visible row error while retaining the assignment, cleared it with Clear,
  canceled recording with Escape, and assigned it again. The real Reset All
  confirmation explicitly described clearing shortcuts; Reset left all values null
  and zero registered keys. Evidence: assigned/error PNGs and
  `native-reset-state.json`.
- Native computer use in the app's Add Text field: typed `field editing sample`,
  then Command-A/C/X/V, Command-Z and Command-Shift-Z. Paste restored the sample,
  Undo emptied it, and Redo restored it. Tool selection and annotation history
  stayed unchanged; all presentation registrations paused while the field had
  focus. Escape canceled the editor. The user's clipboard was saved locally and
  restored after this check. Evidence: `native-editor-state.json`.
- From the frontmost public fixture, native Command-Z, Command-Shift-Z,
  Command-comma and Escape did not mutate presentation state or open Settings.
  Explicit Control-Option-O and Control-Option-E assignments then opened Settings
  and turned the pointer off through real guarded `--input-probe key settings`
  and `--input-probe key exitPointer` events. A focus guard rejected one exit probe
  before posting any input; after explicitly focusing the fixture, the check passed.
  Evidence: `outside-before/after.json`, `assigned-settings-key.json` and
  `assigned-exit-key.json`.

### Visual and layout review

`TINYHAND_SNAPSHOT_SECTIONS=shortcuts python3 scripts/snapshot-settings.py` captured
key, active Settings windows in light and dark. Native scrolling exposed the
bottom tool/history rows. Inspected Unassigned, assigned, rejected and bottom
states in both appearances. Text and Clear controls fit; the error wraps within
its row and retains the recorded value. Shortcuts intentionally scrolls. No blank,
overlapping or clipped controls, unwanted focus rings or inactive-window captures
were accepted.

`swift scripts/check-layout.swift dist/verification/s015/*-layout.json` passed all
eight reports, with four or six probes per report. The existing Card/Row layout
and native buttons align the new controls; the three source grid lints also passed.
Snapshots are under `dist/verification/s015/`:

- `settings-shortcuts-light.png`, `settings-shortcuts-dark.png`
- `settings-shortcuts-assigned-light.png`, `settings-shortcuts-assigned-dark.png`
- `settings-shortcuts-error-light.png`, `settings-shortcuts-error-dark.png`
- `settings-shortcuts-bottom-light.png`, `settings-shortcuts-bottom-dark.png`

### Handoff and limits

No S-015 acceptance gaps remain on this Mac. Intel was cross-built, not run.
Multiple displays, older macOS versions and a full VoiceOver audit were not
exercised. No Stream Deck hardware claim is made. Test fixture and test-mode app
were stopped. A normal LaunchServices launch has no test operations and retains
both existing permission grants. Austin's real preferences and hand library were
not reset or edited. Final normal state is `normal-final-state.json`.

The next agent must treat `Preferences.shortcut`, `toggleShortcut` and
`clearShortcut` as optional. `PresentationAction.drawOnly` now includes annotation
history; use `action.tool != nil` when listing only drawing tools. All global
registration belongs to AppDelegate/HotKeyCenter, including exit. No independent
Escape registration remains. Carbon assignments are exclusive, so a second app
owning the combination is a real rejection. Wait for status readiness after any
LaunchServices launch; an immediate CLI request can race app startup.

The installed interim app is `~/Applications/Look Here Please.app`; the coordinator
owns final queue packaging and Austin Deliveries. Shared-checkout changes remain
unstaged, and pre-existing source edits and assets were preserved. `git diff
--check` passed. Comparing every original file outside the 27-file S-015 manifest
against the pre-task copies passed. The exact changed-file list is
`dist/verification/s015/changed-files.json`.

## S-007 further diffusion and hand-library verification, 11 November 2026

Austin requested a weaker resting shadow that reads as farther from the screen,
plus a lighter and more diffused tapping shadow. Resting projection height is now
28% of hand height instead of 14%, with silhouette density reduced from 0.48 to
0.32. Full-contact density is 0.70 instead of 0.84. The area light is broader in
both states, and a size-scaled Gaussian blur softens contact as well as hover.
The existing press/release response is retained.

The shared renderer projects the actual alpha silhouette from every HandAsset.
Fingertip, width, wrist and rod measurements come from each hand image, including
custom hands. There are no lavender-specific geometry or shadow parameters.

Local evidence is under `dist/shadow-refinement`:

- All 110 Swift tests in 16 suites passed, followed by the packaging unit check
  and all seven grid lints. The shadow test renders all 36 built-in hands and a
  custom hand at rest, partial contact and full contact. It checks nonempty
  output, bounds, fingertip inclusion and increasing density for every hand.
- The first full test run exposed interference from the new custom fixture's
  catalog membership while the GPU was awaited. The fixture is now loaded and
  removed synchronously before yielding, retaining only its measured image for
  rendering. The subsequent complete test run passed.
- Reviewed 29 native window captures from the actual ArmView, HandAsset,
  ContactShadowLayer and Metal renderer. Six distinct shapes, lavender, glove,
  plush, robot, skeleton and glass, were checked at rest and pressed on light and
  dark backgrounds. The fingertip is visibly separated from the diffused resting
  shadow; pressing gathers a lighter, softer contact shadow. Also checked both
  states at 4% size, Original, shadow off and laser.
- Across 901 aim calls including 180 moving poses, main-thread aim time was
  0.088 ms at the 95th percentile and 0.164 ms maximum. A sampled background
  render took 14.151 ms.
- `shadow-comparison.html` compares native lavender, glove and robot screenshots.
  The 728 px resting and 360 px tapping previews showed no console errors, image
  load errors or clipped controls.
- Universal build `20261111133528`, version `1.0.2`, passed local release
  compilation, Developer ID signing, designated-requirement comparison,
  notarization, stapling, Gatekeeper and extracted-ZIP validation. Notarization
  submission `7c37c549-ac02-4a11-a4a9-3e1c539a92bc` was Accepted. The installed app
  is running normally with Contact selected and both existing permissions allowed.
  Packaging used an isolated Python environment for the icon stage's Pillow
  dependency, which was missing from the default interpreter.

## S-007 softer resting shadow and tap transition, 10 November 2026

Austin requested less density and a diffused resting fingertip, with the stronger
contact shape appearing as he taps. The Contact renderer now projects a raised
fingertip at rest, broadens the area light, and reduces the silhouette density.
Pressing lowers the projection to the surface and tightens the penumbra. Full
contact is also lighter than the previous version.

The shadow has a time-based response independent of the existing hand squash.
It approaches contact in about 60 ms, preserves a 75 ms contact interval for
brief taps, remains down while held, and diffuses on release over about 200 ms.
The render cache resolves contact changes in 2.5% steps.

Local evidence is under `dist/shadow-hover-check`:

- All 104 Swift tests in 15 suites passed, along with the Stream Deck packaging
  test and all seven grid lint checks. Seven shadow tests cover persistence,
  configuration, projection, actual GPU output and stale completions, increasing
  density across resting/partial/full contact, short taps, held presses, repeated
  presses and equivalent elapsed time at 30 and 120 updates per second.
- The actual ArmView, shadow controller and Metal renderer were compiled into
  the isolated native canvas. Reviewed light/dark, resting/pressed, 4% and 20%
  size, glove, robot, Original, shadow off and laser screenshots. At rest the
  fingertip shadow is visibly blurred and lighter; pressed contact follows the
  tip. The dark background remains readable, and the other styles render cleanly.
- Across 403 aim calls including 180 moving poses, main-thread aim time was
  0.047 ms at the 95th percentile and 0.109 ms maximum. The final sampled shadow
  render took 15.374 ms in the background.
- Universal review build `20261110214838`, version `1.0.2`, passed local release
  compilation, Developer ID signing, designated-requirement comparison,
  notarization, stapling, Gatekeeper and extracted-archive validation. Submission
  `06d6adc9-e2b8-4369-b08c-efe62e0f2355` was Accepted. The build is installed at
  `~/Applications/Look Here Please.app`. Normal-launch status confirmed Contact
  is still selected and Accessibility and Screen Recording remain allowed.

## S-007 shadow style option, 10 November 2026

Austin approved adding the revised projected shadow as an option in Settings.
All checks and packaging ran locally on his Mac. Hosted CI remained disabled.

- Appearance -> Pointer now contains Shadow style with Original and Contact.
  Original remains the default and Reset All choice. The existing shadow switch
  hides either style without losing the selected style. Size stays in Appearance,
  and the laser retains its separate glow.
- Contact projects the actual hand and nearby rod silhouette using 1,024 area-light
  samples. The contact point stays anchored as the bitmap follows the current pose.
  Mask construction, Metal work and readback run in an actor outside the main
  thread. Each view coalesces pending poses, bounds output to 1,024 pixels per edge,
  and discards results for disabled or replaced hands. Original is the fallback if
  Metal cannot render. Rendering does not repeat while the pose is unchanged.
- `scripts/run-tests.sh`: 45 tests in 10 suites passed, including four new shadow
  tests for preference persistence/reset, strict atomic configuration, contact and
  fixed-light geometry, actual GPU output bounds and stale completion rejection.
  The shadow tests were rerun after strengthening the completion wait.
- The production ArmView, shadow controller and renderer were compiled unchanged
  into an isolated native canvas. Reviewed white/dark, Original/Contact, rest/press,
  4% and 20% size, glove, robot, shadow off and laser captures under
  `dist/shadow-production-check`. During 402 aim calls, main-thread aim time was
  0.111 ms at the 95th percentile and 0.224 ms maximum. The sampled background
  render took 11.063 ms. The canvas included 180 moving poses through rotation.
- In the installed app, selected Contact with the mouse and selected both styles
  using Home/End and Return in the native menu. Accessibility exposes Shadow style
  and its current value. Turning the shadow switch off disables the picker while
  retaining Contact. A normal relaunch retained the choice and exposed no test-only
  control operations.
- Reviewed active Settings snapshots in light and dark appearance, including
  Original, Contact and the disabled picker. All fit without clipping or unwanted
  focus rings. Four layout reports passed, each with 10 probes in five areas;
  all three existing Settings grid lint checks passed. Files are under
  `dist/verification/shadow`.
- Universal review build `20261110073002`, version `1.0.2`, was notarized Accepted
  with submission `65af5268-35d7-4c87-b4b3-f1798bb04c8e`, stapled and installed at
  `~/Applications/Look Here Please.app`. Deep/strict signature checks, the existing
  designated requirement, Gatekeeper and the extracted delivery ZIP passed.
  Accessibility and Screen Recording remained allowed after the normal launch.
- The first packaging attempt stopped with SIGPIPE during signing checks. The
  checks now consume their full input under `pipefail`; the subsequent complete
  packaging run passed. The SDK's existing x86_64 deprecation warning remains.

Runtime evidence covers this Mac. Intel, older macOS versions and multiple
physical displays were not exercised. S-005/S-006 and the later backlog were not
part of this change.

## S-009 and S-010, 10 November 2026

Run locally on Austin's Mac, macOS 27.0, Apple Silicon. Hosted CI was not used.

### Results

| Check | Result |
| --- | --- |
| `scripts/run-tests.sh` | 41 tests in 9 suites passed; grid lint passed |
| Installed review build 20261110031257 | Notarization Accepted (`b0e5d923-b525-4335-a8b6-40888de75a98`), stapled, Gatekeeper accepted, same designated requirement |
| Stream Deck plugin package | Elgato validator passed; Developer ID, hardened runtime, universal; notarization Accepted (`1dc97e07-b6a5-42a7-b8ab-aac4d1e7d546`) |
| Installed dictionary | `sdef` lists the vocabulary; the test-only script operation is absent from the normal app |
| AppleScript from another process | `osascript` against the installed app: on/off, Interact, pointer by name and id, drawing tool, `toggle interact`, a rejected pointer reporting 1003, and reading a change made through the control protocol |
| AppleScript permission failure | Test instance with Accessibility reported missing: `set interact to false`, `toggle interact` and `set drawing tool` each returned error 1001 and left Interact on |
| Stream Deck protocol replay (`scripts/deck-replay.py`) | 21 of 21 with Accessibility, 20 of 20 without, using the real plugin and a real test app over a simulated Stream Deck connection |

The replay covered first-image press feedback in under 10 ms, acknowledged toggles,
external pointer and selection changes reaching keys in about 0.5 seconds, Interact
changes, rejected selections, a stopped app, automatic recovery, an inspector list
filling in after recovery, and no command replay after a restart.

Key art was reviewed as a rendered state sheet in `dist/deck-art/sheet.png`. Replay
frames are in `dist/verification/deck-replay-granted` and `deck-replay-denied`.

### Not verified

- S-009: the dictionary has not been viewed in Script Editor, and AppleScript changes were confirmed through state readback rather than by watching the toolbar and menu.
- S-010: nothing has run on a physical Stream Deck or through the Stream Deck app, so the plugin's install, inspector rendering, key legibility, press feel and hardware reconnect are unconfirmed.
- A status read during the first seconds after app launch can time out while thumbnails preload. Keys recover on the next read.

## S-001 through S-004, 10 November 2026

Austin authorized these four stories and clarified S-003 as one Interact switch.
All checks ran locally on Austin's Mac, macOS 27.0 build 26A425, Apple Silicon,
1920 × 1080. Hosted CI was not created, enabled, dispatched or rerun.

### Implementation and local checks

- Product display name, Finder filename, Settings footer/title, startup wording,
  About, menus and user-facing errors now identify Look Here Please. About credits
  TinyHand explicitly and keeps the original MIT license.
- The bundle identifier remains `com.austinpresley.pleaselookhere.integration`;
  executable `TinyHand`, preference keys and `Application Support/Please Look Here/Hands`
  are retained. No settings or custom-hand migration is needed.
- One Interact switch replaces Point/Draw controls. On forwards native input;
  off captures annotations with the same pointer. Holding a modifier never changes
  it. Legacy stored mode values and protocol v1 clients remain compatible.
- Keep the hand visible while interacting defaults on and respects stored choices.
  With it off, the hand hides during native mouse presses/drags and returns after
  all buttons release. Drawing remains visible.
- 29 Swift Testing tests in seven suites passed, including modifier preservation,
  stale held-key settings, routes across interaction changes, default/reset behavior,
  visibility rules, strict Interact commands and permission errors.
- 13 native public-fixture checks passed, covering tools/history, native shortcuts,
  toolbar movement, screenshot encoding and mode changes during a drag.
- Four focused interaction checks passed, including actual press-time visibility
  with the option on/off and restoring the pointer after release.
- Native Option-click reached the fixture button; text entry and double-click word
  selection worked; right-click opened its native menu; drags reached its canvas.
- Settings and toolbar native clicks synchronized Interact state. The application
  menu showed Quit Look Here Please. Source audit found no Point/Draw UI selector
  or held interaction-key picker.
- All seven Settings pages were captured from a key, focused running window in
  light and dark. Toolbar states and the real welcome window were also inspected
  in both appearances. Grid lint and layout probes passed. Shortcuts intentionally
  scrolls; no new layout clipping was found.

Evidence is in `dist/verification`, including `unit-tests.log`, `live-smoke.json`,
`interaction-smoke.json`, `toolbar-toggle-checks.json`, `settings-toggle-off.json`,
Settings PNG/layout pairs, toolbar PNGs and welcome PNGs.

### Signed and notarized packaging

- Build A `20261110014042` and build B `20261110014637` both passed notarization.
  Submission IDs are `4f69c17b-b782-4ada-b68b-c9170a7a5e7f` and
  `b5a33c9e-fb94-461f-bf5d-7fc869d7a715`.
- Both use Developer ID Application: Austin Robinson, team `G2R8798RLT`, hardened
  runtime and secure timestamps. The designated requirements match exactly.
- The app ticket is stapled and validated. Deep/strict code-signature checks and
  Gatekeeper report Notarized Developer ID for both app and extracted final ZIP.
- An ad hoc signer and a missing explicit signer were both rejected before building.
  Local packaging contains no upstream updater feed or signer defaults.
- The complete bundle installs to `~/Applications/Look Here Please.app` and
  `--open` launches that installed copy. Spaces in the display/bundle name work.

### Permission continuity gate

The first A-to-B test launched the installed executable directly from the agent's
shell. It reported both grants and exercised drawing/capture, but a subsequent
normal LaunchServices launch did not have Screen Recording. That first result is
not accepted as proof of the normal installed app's permission continuity.

Austin completed the macOS authentication step, and System Settings showed
Look Here Please enabled for Screen Recording. The normally launched build B
`20261110014637` reported Accessibility and Screen Recording allowed before it
was replaced with notarized build C `20261110022351` at the same installed path.
Their designated requirements match exactly. Build C's notarization submission
`2fa15624-7c73-4e45-a89f-45fb893a4b13` returned Accepted; the app and extracted ZIP
passed stapling, strict signature and Gatekeeper checks.

Both grants remained allowed after this update without resetting or toggling
permissions. Actual native drawing and a 1920 × 1080 PNG capture passed in the
normal LaunchServices process. A fresh normal launch then passed the same native
drawing/capture check again with both permissions still allowed. No test-mode GUI
process or shell-inherited screen access was used for these accepted checks.
S-002 is complete.

Two initial normal capture probes stalled after the new grant. No product source
change was made for those attempts. A later public-fixture retry and fresh-launch
check both passed; the transient cause is unconfirmed. A separate diagnostic
capture without a confirmed fixture is excluded from acceptance and was removed.

Accepted evidence is in `dist/verification/normal-before-update.json`,
`normal-update-identities.json`, `normal-after-update-capture.json`,
`normal-cold-launch-state.json` and `normal-cold-launch-capture.json`.
The current package checks are in `dist/review-build-c.log` and
`dist/review-notarization.json`. The earlier `permission-continuity.json` describes
the superseded shell-launched check and is not the accepted result.

The regular app's screenshot preferences, sound preference, interaction state and
inactive pointer state were restored after the probes. Keyboard navigation was
restored to its original off state. No password was entered by the agent.

For future isolated test launches, use LaunchServices rather than executing the
binary as a GUI process. The executable remains suitable for `--ctl` clients:

```sh
open --env TINYHAND_TEST_MODE=1 \
  --env TINYHAND_DEFAULTS_SUITE=com.austinpresley.tinyhand.integration.testing \
  --env APP_SNAPSHOT="$PWD/dist/verification" \
  --env TH_HANDS_DIR=/tmp/look-here-please-review-hands \
  "$HOME/Applications/Look Here Please.app"
```

Quit any running instance first. Confirm readiness and both permission values
through the installed binary's status command before native fixture tests.

### Limits

This runtime review covers this Mac and display. Intel was cross-built, not run.
Xcode 27 emits its existing x86_64 deprecation warning during universal aggregation.
Older macOS versions, physical multi-display behavior, full VoiceOver/Accessibility
Inspector audits and actual permission revocation remain outside this review.

## Historical integration review, 9 November 2026

Validated locally on Austin's Mac on 9 November 2026, using macOS 27.0, Apple Silicon and a 1920 × 1080 display. The app remains in the existing Swift 5 language mode. Hosted CI was not created, enabled, dispatched or rerun.

### Results

| Check | Result |
| --- | --- |
| Local unit tests | 24 tests in six suites passed |
| Native input smoke test | 13 checks passed against the disposable public canvas |
| Settings snapshots | Seven pages inspected in Light and Dark, captured from the focused running app |
| Layout probes | All 14 Settings layout files passed |
| Grid lint | SettingsView, SettingsComponents and PresentationSettings passed |
| Review build | Universal arm64 and x86_64 build completed locally |
| Mach-O deployment metadata | Both architectures report macOS minimum 13.0 |
| Bundle signing | Developer ID signature; deep/strict verification passed |
| Pointer discovery | 37 styles discovered; 36 thumbnail files verified |

Xcode 27 emits an x86_64 deprecation warning during universal-build aggregation. The actual binaries' minimum OS is 13.0, checked with `vtool`. There were no Swift source compilation errors. Intel code was cross-built, not run on Intel hardware.

### Selected features and evidence

| Selected rank | Evidence |
| --- | --- |
| 1, normal Point interaction | Real canvas button click, text entry, dragging and native right-click menu observed. Escape dismissed the menu while the pointer remained active. |
| 2, Undo | Unit history tests and native Command-Z / Command-Shift-Z checks, including marker edits. |
| 3, tools | Native pen, rectangle and arrow gestures created annotations. Text editor focused its field; Return added a visible label and Escape canceled without adding an annotation. |
| 5, screenshot | Native capture shortcut and local command produced valid 1920 × 1080 PNGs. Inspected images contained the hand, strokes, rectangle, arrow, marker and text, without the app toolbar. |
| 6, toolbar | Native shortcut hid/revealed it. Global drag moved it and saved its final origin. Position remained consistent through Point/Draw resizing. Reset Position cleared storage and recentered it. |
| 7, markers | Placement, move, click-to-remove, Undo/Redo, and Control-click while Pen remained selected all passed. |
| 8, line controls | Width/opacity captured per annotation in unit tests; native capture showed the configured eight-point, 70% ink. |
| 14, automation | Real private-socket calls exercised status, configuration, style discovery, modes, tools, capture and Settings. Validation and atomic settings batches passed unit tests. |
| 16, keyboard | Native tool, mode, Undo/Redo, capture and toolbar shortcuts passed. UI recorded Pen as P, restored F, and rejected a collision with Control-Option-H. |
| 18, smoothing | Four smoothing cases preserved endpoints; nonzero smoothing reduced jitter in the geometry test. Drawing controls rendered correctly in both appearances. |
| 20, permission recovery | Injected denied access rejected Draw/tool operations while Point remained selectable. Live test instance reported Accessibility and Screen Recording allowed. Actual OS permissions were not revoked for testing. |
| 21, routing | Unit tests covered independent buttons, held modifiers, native controls, stale callbacks and draining captured releases. A real mode change midway through a drag finished with the tap inactive and disabled. |
| 28, motion | Both grip algorithms passed value tests. Native activity reported displayLink for Responsive and timer for Original. UI changed between both selections. Original is the default. |
| 32, appearance/size | Real UI changed Light/Dark; all pages were reviewed in both. Pointer size reached 4% through the native slider decrement action and status acknowledged 0.04. |
| 34, organization/polish | Reviewed General, Shortcuts, Drawing, Pointers, Appearance, Sound and About. Shortcut controls expose their specific labels and assigned values through Accessibility. |

### Snapshot review

Files are under `dist/verification`. General fits its permission, mode and capture controls. Drawing keeps tools, width, opacity and ink settings aligned. Appearance shows the live Original/Responsive selection. Pointers retains the existing gallery and custom-hand entry point. Sound choices and About remain readable. No unexpected focus rings or overlapping content appeared in Settings. Shortcuts intentionally scrolls; its bottom Number and Undo/Redo rows were separately inspected.

The older standalone Settings snapshot entry point produced inactive windows during the first pass. Those images were replaced. The accepted snapshot helper rejects capture unless Settings is visible, key and its application active.

### Reproduce

Run `bash scripts/run-tests.sh` and `bash scripts/build-review.sh` locally.

For UI evidence, start the project bundle's executable with TINYHAND_TEST_MODE=1, APP_SNAPSHOT pointing at `dist/verification`, TINYHAND_DEFAULTS_SUITE set to a test suite, and TH_HANDS_DIR set to a temporary folder. Focus its Settings window and run `python3 scripts/snapshot-settings.py`.

Build the disposable canvas with `bash scripts/build-fixture.sh`. Only run `python3 scripts/live-smoke.py` while that public fixture is visible. The probe uses native system events and guards fixture presence, coordinates and keyboard focus. The normal app does not expose the snapshot operation. Native smoke results are in `dist/verification/live-smoke.json`.

### Review-build limits

This is a signed local review build, without notarization or a release update feed. The verified running instance is the project copy under `dist/TinyHand Integration.app`. A direct command-line launch of the copied `~/Applications` bundle stalled in dyld on this Mac; that path is not claimed as a verified launcher. macOS assessment reports an unnotarized Developer ID build. Public release/notarization is deferred.

Runtime checks covered this Mac and display. Older macOS versions, Intel hardware, multiple physical displays and a forced system-permission revocation remain manual checks. macOS 13 uses the timer fallback for Responsive and a bounded one-frame screenshot stream. The review app has separate preferences and a separate custom-hand folder from upstream TinyHand.

ScreenCaptureKit sizing uses the filter's screen-point content rectangle and pixel scale, following [Apple's contentRect documentation](https://developer.apple.com/documentation/screencapturekit/sccontentfilter/contentrect).


## S-025 Spotlight and telescoping presentation pointer, 10 November 2026

Austin requested both pointers from the proposed shortlist. Implemented as native
Core Animation layers and added to the existing enabled-pointer catalog after
Laser dot. Existing saved toolbar pins stay unchanged. Spotlight has a transparent
center, a feathered edge and 62% dimming around the current display. The Size
setting controls its clear radius. Presentation pointer uses three metallic shaft
sections, collars, a dark grip and a coral cap at the real cursor. Size controls
shaft thickness. Both use the existing hand tap-sound preference; Laser dot keeps
its separate sound preference. No permission or shortcut is added.

Evidence is in `dist/verification/s025-pointers/`.

- `bash scripts/run-tests.sh` passed 110 tests in 16 suites, the Stream Deck
  package test and seven existing grid lints. `scripts/grid-lint.sh
  Sources/TinyHand/PointerLibrary.swift` also passed. New tests render actual
  pixels to check aperture transparency, feathering, uniform dimming at texture
  joins, hide/switch/resize/corner behavior, rod rendering and exact tip geometry.
  The rod thumbnail test checks its angled coral tip and grip. `git diff --check`
  passed. Final log: `tests-delivery.log`.
- Five active app-window captures cover Pointer library top/light, bottom/light
  and bottom/dark, plus Appearance/light and Appearance/dark. The new tiles have
  readable names, enabled controls and recognizable artwork. The Size explanation
  fits in both appearances without overlap. All five layout reports passed;
  `layout.log` records 10 probes per Appearance capture and 122 per pointer capture.
  The final dark Appearance capture was taken again without concurrent UI input.
- `native-check.py` passed four guarded checks over the dedicated public fixture.
  Each pointer passes native click down/up through in Interact. With Interact off,
  a native rectangle drag creates one annotation without fixture down/up/drag
  events. Both retain their selection and visible pointer. `native-checks.json`
  records state and fixture counters. The fixture is closed afterward.
- `check-runtime.py` verified enabled/available metadata, pinning, disabled-choice
  rejection before activation, AppleScript selection, activation and catalog
  cycling. It exported both thumbnails and rendered both through the real Stream
  Deck KeyModel/KeyArt path. Settings selection was also exercised through the
  native UI. The dynamic radial and menu choices use the same catalog/artwork.
- First visual review found a fine seam at Spotlight's aperture join. A single
  dimming layer with an overlapping alpha mask removes it, with pixel regression
  coverage. Native Settings review found that rendering the rod layer as a root
  ignored its transform; the thumbnail now renders it as a child and has a
  dedicated regression test. An initial corner pixel assertion used bitmap rows
  in the opposite direction to AppKit coordinates and was corrected.
- The first packaging attempt stopped before app assembly because system Python
  lacked Pillow. `PATH=/tmp/s021-art-venv/bin:$PATH bash scripts/build-review.sh
  --package-only` completed the documented local lane. Final app is universal
  1.0.2 build 20261110234249. App notarization was Accepted, stapling and Gatekeeper
  passed, and the extracted final archive passed signing, staple, Gatekeeper and
  embedded installer checks. Plugin remains 1.0.3.2 and was not installed or
  reassigned in Stream Deck. Logs: `build-delivery.log`, `install-delivery.log`.
- Final normal LaunchServices launch retained Accessibility and Screen Recording.
  Original normal preferences and runtime settings, selected pointer, On/Off,
  Interact, shortcuts, disabled choices and pins match. Enabled choices gain only
  the two new IDs. All 2,891 protected hand/Stream Deck files except the host's
  runtime `Data/COEvents` store match their initial hashes; that host store changed
  during the session and was left intact. All profiles and key assignments match.
  A transient LaunchServices -600 after quitting was resolved by a fresh launch.
  `normal-final.json` records the final state.
- Final ZIP is retained at `dist/deliveries/Spotlight and Pointer/Look Here
  Please.zip`, delivered with verified state `delivered` to
  [Austin Deliveries](https://drive.google.com/drive/folders/1UCslRnEooaYbCclqBHrZhFvhPPVwgVXP). Delivery ID: `20261111T045148Z--012654c20797`.

Remaining limits: physical multiple-display movement, Intel/older macOS runtime
coverage and a full VoiceOver audit were not performed. The pre-existing radial
reopen issue and physical Stream Deck acceptance gaps remain open. These changes
were kept local in the existing modified checkout; no prior work was staged, no
public release or Git push was made, and hosted CI stayed disabled.

## S-026 through S-035 selected fork upgrades, 14 November 2026

Austin selected shortlist items 1, 2, 3, 4, 7, 9, 10, 12, 13 and 14 and authorized
routine decisions while sleeping. Completed in native Look Here Please 1.1.0,
build **20261114081700**, source **a96036c**, on local branch
`feature/fork-upgrades-20261114`. The earlier local app is preserved in checkpoint
`8451227`, a recovery archive and an installed-app backup under
`/Users/apresley/Library/Caches/look-here-please-fork-upgrades-20261114`.

### Local verification

- `full-tests-certified.log` passed **149 tests in 22 suites** with no compiler
  warnings, plus the Stream Deck packaging unit check and **12 grid lints**.
  These logs are in the recovery/cache directory. New tests cover blocked audio
  startup and configuration recovery; mute, context and permission-mode
  cancellation; system notifications and complete owned input pairs; own-window
  Point release; trail visibility/history; magnifier layout, late-frame
  cancellation and coalescing; custom pose composition/corruption; swing timing;
  and strict control batches. Regression logs retain each failing-before and
  passing-after review correction.
- `scripts/fork-upgrades-smoke.py` passed **11 native runtime groups** on the
  exact certified build. It verifies idle sleep and real movement wakeup, hidden
  toolbar recovery, shutdown signals, native Interact clicks, captured trail
  drags and Undo/Redo, both pose previews, real overlapping gesture hotkeys and
  modifier release, exclusive-key release/re-registration for corrupt/restored
  artwork, live magnification over changing public-fixture content, rapid
  capture cancellation and immediate native dragging with swing enabled.
- `scripts/fork-upgrades-fullscreen.py` passed **four actual full-screen Space
  checks**. A controlled fixture enters/exits temporary full-screen Spaces with
  the pointer off and on. The overlay reports real active-Space membership;
  Window Server confirms the toolbar is on screen when enabled. Its hidden
  preference survives the other transitions. The temporary fixture/Space is
  closed afterward; no user Space or system preference is changed.
- Actual native controls start magnification after closing the popover, and the
  toolbar button stops it. Both controls are captured and reviewed in light and
  dark. The native Hand Gestures menu starts a temporary pose and restores it
  after two seconds. All nine new native sound tiles were pressed and selected;
  their real background AVAudioEngine path ran without a UI crash.

Evidence is under `dist/verification/fork-upgrades-20261114/`: `native-checks.json`,
`fullscreen-checks.json`, `controls-certified-checks.json`, `sound-ui-checks.json`,
`certified-build.json` and `packaged-resources.json`. Native PNGs capture only the
app's own window over public fixture content. The magnifier shows a correctly
oriented 3x grid and colored squares, with one hand and no feedback recursion.
Trail images show visible red ink becoming fully transparent while annotation
history remains; the measured first-run red pixel count drops from 2,126 to zero.

### Active window review

Every Settings page was captured as an active key window in both appearances.
The final General permission label and final controls were captured again from
the certified build. All associated layout reports pass.

| Surface | Visual result |
| --- | --- |
| General | Native switches, permission status and installer controls fit. The permission row now names screenshots and magnification; the final light/dark captures are `settings-general-certified-*.png`. |
| Shortcuts | Gesture hold rows display real assignments or Unassigned, with aligned Clear controls. The long command list scrolls normally; no factory keys are introduced. |
| Drawing | Trail mode, delay and speed fit alongside width/opacity/color. Light and dark labels remain readable, with no overlapping controls. |
| Pointers | Both gesture thumbnails, per-hand import buttons and the existing library remain distinct. Existing pins and enabled choices keep their layout. |
| Appearance | Follow behavior, optional tap swing, zoom and lens size align. Extra bottom captures show the complete toolbar/Reset Position controls through normal scrolling. |
| Sound | All 15 choices plus Off fit in four columns. Typewriter and other labels fit; Off and Chirp selected states are readable in both themes. Laser sound is clearly independent. |
| About | Version 1.1.0, existing project credit and the packaged notice button fit, with no extra blank band or unwanted focus. |
| Hand creator | The three steps explain copy/paste, real PNG transparency and preview/add. A public PNG was chosen through the real native file panel; active light/dark draft captures show its checkerboard transparency, name field and complete Add Hand controls without clipping. |
| Controls and toolbar | The new magnifier button fits without clipping and shows selection. The native popover and floating toolbar remain legible in both appearances. |

### Packaging and preservation

`build-certified.log` passed local universal arm64/x86_64 compilation, stable
Developer ID requirement comparison, secure timestamp/hardened-runtime signing,
Accepted Apple notarization, stapling, Gatekeeper, ZIP integrity and extracted-app
verification. The exact archive is `dist/Look Here Please-review.zip`. The
embedded plugin remains 1.0.3.2; its archive/hash receipt is verified. It was not
installed or reassigned in the Stream Deck host. Packaged WAV/pose bytes and full
donor MIT notices match their source files. No upstream update feed is present.

The normal installed app was relaunched through LaunchServices after the test
instance quit. `normal-final.json` confirms original Pointer Off, selected
Lavender toy, Interact, old settings, enabled choices, pins and assignments, with
Accessibility and Screen Recording both retained. The exported normal preferences
are exactly identical to the initial export. All **2,892 protected files** still
exist; hands and Stream Deck profiles/key settings match their initial hashes.
Only the host's runtime `Data/COEvents` file changed and was left intact. New
shortcuts are null; swing is zero and magnification/poses are off.
The file-panel check changed three app navigation preferences; after the test
instance quit, only those three keys were restored to their captured values.
The final normal export is again exactly identical. Rejected inactive standalone
preview attempts are retained outside the accepted evidence in the recovery
cache; only the real active-window preview captures count as reviewed.

Review findings and resolutions are preserved separately in
`fork-upgrades-code-review-2026-11-14.md`. No material finding remains open. Source
and packaging work stayed local; no Git push, PR, public release, hosted workflow
creation, dispatch or rerun occurred.

### Limits

Lock, screensaver and sleep behavior uses controlled signals and raw router
regressions; the unattended Mac was not actually locked or slept. Audio failure
and permission loss are injected through real interfaces, rather than changing
normal OS grants or starting a live screen-sharing service. Real sound previews
and live screen capture were exercised. Physical multiple-display/mixed-scale,
Intel/older macOS runtime and a full VoiceOver audit remain unperformed. The
preexisting radial reopen and physical Stream Deck acceptance gaps stay open.
# App review implementation started, 15 November 2026

Baseline: installed signed/notarized 1.1.0, build 20261114081700. Active source
branch: `feature/app-review-improvements-20261115`. The S-036 through S-053 queue
is in `app-review-implementation-2026-11-15.md`. All implementation subagents use
Sol 6.1 High. No Max setting or hosted checks are used.

Recovery: the initial all-ref Git bundle verified, and archives preserve the
previous installed app, normal preference export, hands and all 92 untracked
files. A second backup made with `scripts/backup-source.py` passed SHA-256 checks
and a real temporary clone restored exact HEAD `e162b94`. Both copies are on the
internal volume under `~/Library/Application Support/Look Here Please/Backups`.
The source backup does not upload source or remove existing evidence.

Local focused screenshot check: five ScreenshotRecoveryTests pass with isolated
suite `com.austinpresley.tinyhand.review.capture-tests` and temporary hands.
Coverage includes permission versus frame/encoding/file-write recovery, Retina
crop conversion, negative display origins, clipped selection and empty input.
The final incremental compile for these changes has no warnings. New result and
selection surfaces pass their layout lints. Active light/dark UI checks and
integrated regression/package checks are still pending.

Available hardware was read without changing devices: one 1920x1080 display,
Apple silicon, macOS 27.0, and no physical USB Stream Deck. Multiple-display,
physical Deck, Intel and older-OS acceptance cannot be inferred from this host.

GitHub workflow state was read through the repository API. Build 414155231 and
Release 414155234 were both `disabled_manually`. Their local workflow definitions
are now archived outside `.github/workflows` so a later source push cannot
reintroduce automatic build/release triggers. No hosted workflow was dispatched.
# App review completion, 16 November 2026

All 18 authorized recommendations are implemented as S-036 through S-053 on
`feature/app-review-improvements-20261115`. Every implementation and review child
used `gpt-6.1-sol` with reasoning effort **high**, with no Max setting. Worktrees
kept implementation changes isolated, and the coordinator integrated explicit
commits. Hosted CI remained disabled and its definitions are archived outside the
Actions workflow directory. No source push, PR or public release was made.

## Exact installed and delivered build

- App: 1.2.0, build 20261116015628, universal arm64/x86_64, macOS 13 minimum.
- Matching bundled and installed Stream Deck plugin: 1.1.0.0.
- App notarization: Accepted `f5090abe-34dc-4a8e-959a-2fc18ad58775`.
- Developer ID team remains G2R8798RLT with the installed app's designated
  requirement preserved. Hardened-runtime signing, secure timestamps, stapling,
  Gatekeeper, ZIP integrity and the extracted-app installer contract pass.
- Artifact: `dist/Look Here Please-review.zip`. The exact tested dist app was
  copied atomically to `~/Applications/Look Here Please.app`, verified again and
  launched normally through LaunchServices without test capabilities.
- Local build log: `/tmp/lhp-review-distribution-build.log`. Icon generation used
  Pillow 13.0.0 in the dedicated local build-Python cache. Source icon artwork is
  unchanged; the compiled Assets.car was regenerated for this packaging.

## Local tests and source review

`scripts/run-tests.sh` passed **295 tests in 38 suites**, the packaging contract
test and all 12 existing layout lints. Full log:
`/tmp/lhp-review-distribution-tests.log`. There are no compiler warnings in this
run. Five tests against the real Choose Pointer inspector JavaScript also pass.

Five source-review rounds found and closed seven substantive findings: stale
radial closes, key-first chords, malformed-receipt manifest replacement, Undo
completion before preferences, lost rapid-mute teardown, import/removal recovery
ownership and edits accepted during import staging. The final source audit reports
no remaining P1/P2 findings. Each correction has a failing-before regression and
passing isolated evidence in `docs/work/`.

Full-suite integration also corrected test-only native-timer interference and a
canonical `/var` versus `/private/var` path assertion. The native UI pass caught
segmented-control truncation, a 256-point preview control row and an initial
zero-bounds renderer. Final controls measure 22 points high in both appearances;
the pointer is visible in the replacement light/dark captures. The preview resize
regression failed before the correction and its 13-test focused run passes after.

The milestone architecture check found no additional Strong refactor required.
See architecture-review-2026-11-16.md.

## Active-window visual checks

All eight Settings pages were captured as active key windows in light/dark with
process-local Always Show Scroll Bars. Every associated layout report passes.
Images are under `dist/verification/app-review-20261115/settings-certified`;
Appearance's final replacement captures are under `settings-preview-final`.

| Surface | Observed result |
| --- | --- |
| General | Getting-started, permissions, installer and capture controls align in both themes. Startup is reachable through normal scrolling when content exceeds the screen. |
| Shortcuts | Unassigned states, native radial picker and concise practice link fit. Native destinations have visible focus without recording or changing assignments. |
| Drawing | The local curve is visible with readable lifetime text and bounded native controls. Labels no longer truncate; local Undo/Clear reflect document state. |
| Pointers | The gallery precedes selected details. Search, combined filters, selected/pinned cues and native pin menus fit with system scrollbars. |
| Appearance | Preview background choices and tap/motion controls fit in one 22-point row. The local hand renders in both final themes and customized appearance is explained. |
| Sound | Volume, master mute, shared choice and separate Preview fit without an empty bottom band. Mute disables Preview and preserves choices. |
| Presets | Empty and saved states, recovery controls and import-preview scrolling are readable. Conflicts disable Import and explain Undo Remove; stale edits are rejected without replacement. |
| About | Version 1.2.0, credit, license and notices fit in both appearances. |

Native Getting Started checks covered all four lessons, sample pointer, local
clicks, Interact, drawing, Undo/Clear, native radial keyboard buttons and a guarded
continuous mouse path. The native path selected Arrow locally while the desktop
tool remained Pen. Practice pointer and radial captures are retained in the same
verification directory, including light/dark radial captures.

The signed app's Pointer, Pen, Interact and radial links reveal/focus the exact
native control. Unassigned values remain unchanged and recording does not begin.
Named pin moves, sidebar arrow navigation, search/filter reset and independent
Use Default behavior were exercised through native accessibility controls.

## Final native input pass on the exact notarized app

`docs/work/final-native-input-checks.md` and `native-final/checks.json` record
**13 passing behavioral checks**. Real Carbon blockers prove per-command conflict
isolation and rejected-replacement rollback while unrelated keys continue working.
Native early modified clicks, key-first chords, preexisting native key state,
ordinary-key cancellation and owned Escape repeats/releases pass.

Twenty consecutive fresh Option hold/release openings passed with one transition
each, no retries, and matching actual WindowServer window/alpha observations.
Light/dark captures contain only the app's own radial window. The initial harness
focus-prerequisite refusal remains separate and is not counted as a behavioral
pass. All temporary blockers, keys/buttons, fixture and test app were cleaned up.

## Presets, backups and hand recovery through native UI

Preset save/apply/remove/Undo worked. Apply restored size, volume and tool while
preserving Pointer On, Interact Off and every shortcut. A 3.9 MB public-fixture
backup contained one custom hand, both custom gesture slots, one built-in gesture
override and a named preset, with exact SHA-256 artwork matches.

An edit accepted after preview caused native import to reject with "Nothing was
replaced" and retain the edit. A fresh preview/import applied expected settings.
Removing the hand, changing the absent ID's override and previewing the older
backup disabled Import for pending recovery. Cancel retained Undo Remove. Undo
restored exact hand/gesture bytes, pins and original overrides without stealing
the current selection.

Import into a second empty disposable profile restored all artwork, saved preset,
overrides, pins and enabled choices while retaining its local capture folder and
shortcuts. After quitting/restarting that profile, Undo removed only imported
files and presets and restored the exact original settings. Evidence is in
`roundtrip-*.json`, `native-hand-recovery-state.json` and the public fixture manifest.

Native full-display and 300x200 region captures passed, along with Escape region
cancellation preserving the last result. A low-volume native audition ran; master
mute disabled/restored Preview without changing choices. Queue/driver cancellation
is independently proven by injected audio tests, rather than speaker measurement.

## Preservation and installation

All original normal preferences compare exactly with the initial export after
restoring four test-created AppKit navigation keys. No functional preference was
reset. Both Accessibility and Screen Recording remain allowed. Normal app
capabilities contain no test commands. Original custom-hand files and all 92
untracked source/artwork files remain intact.

Plugin 1.1.0.0 was installed through Settings > General and the Stream Deck host's
Install confirmation. All 21 installed plugin files match the verified package.
All **39 profile-related files** among the original 2,892 protected Stream Deck
files are unchanged. Four files changed inside this plugin; the only other change
is the host's runtime `Data/application_cache.json`. No key or profile was edited.

The previous app and plugin remain backed up. Verified off-volume source recovery
includes a real clone restoring the recorded HEAD; a fresh final source bundle
is made after the handoff documentation commit.

## Limits

This host is Apple silicon, macOS 27.0, with one 1920x1080 display and no physical
USB Stream Deck. Physical multiple-display/mixed-scale, USB key/host-inspector,
Intel/older macOS and actual lock/sleep checks remain unperformed. Native CGEvent
tests are distinct from a physical keyboard, mouse or trackpad test. The historical
intermittent reopen cause remains unestablished despite the clean bounded run.

VoiceOver was temporarily enabled through its actual system switch. App roles,
values and ordinary keyboard paths were inspected, but spoken output could not
be reliably captured through the automation interface. It was restored Off and
the verification-only system utilities were closed. This is not a full spoken
VoiceOver or Accessibility Inspector certification.


## C11 identity and GitHub presentation, 17 November 2026

Austin selected C11 Cream using the S1 diagonal composition and authorized it as
our current logo and palette, with a reworked GitHub page. The canonical native
source now uses the original lavender PNG embedded in the selected SVG layer;
the icon document and hand layer match the approved C11 bytes exactly.

Local `make-icons.py`, the updated `make-branding.py` and `review-icons.py`
completed. CAR/ICNS, all six native appearances, repository banner/logo,
outlined wordmarks, favicons, social art, pointer lineup and local plugin
identity PNGs were regenerated. No Swift app logic, preferences, runtime
installation or app release packaging was changed by this task. The plugin
art remains part of its source hash contract and will be repackaged by the
next normal local plugin/app build.

README, page source and shared branding were visually checked locally. The page
loaded all ten images in the T3 browser with no horizontal overflow. The native
snapshot API twice returned `Preview automation snapshot timed out after 15000ms.`
T3 HTML rendering then checked a 1120 px page, a 390 px narrow page and the Dark
CSS treatment. Dark CSS was forced in the preview copy because the renderer's
appearance option alone did not change its system media query. The local README
render was also inspected. PNGs are saved in
`design/brand-refresh/c11-github-2026-11-17/`.

Relative image/link paths, local anchors, SVG parsing, PNG integrity, source
layer identity and text contrast passed. Normal light text/link/button contrast
is at least 5.5:1; checked dark text/link pairs exceed 7:1. The native source
retains the existing reduced-contrast system TintedDark treatment.

Published main commit: `aee296bae19502452fde0cc466f31f0ae2407296`.
Its parent is `7017192888053ec37bcc96fc4b4cdeb92c4213b9`. A clean detached
publication worktree staged only 38 explicit branding/presentation paths.
No Sources, Tests, functional changes or workflow definitions were included.
All 36 written files were checked against the remote Git tree by blob hash,
and obsolete native vector layers were absent. The live GitHub README showed
the new text and both new images loaded successfully. Repository description
now matches the shared product descriptor.

GitHub Actions remains disabled; both inherited workflows remain
`disabled_manually`, with zero hosted runs. GitHub Pages is not configured.
The dirty app checkout stayed on its original feature branch. Publication
manifest and verification are in the C11 handoff directory.

## Usability icons Phase A, 18 November 2026

Implemented on `feature/usability-rethink-icons` over the intentional uncommitted
Quick controls v9 and Settings work. No commit, push, hosted workflow, live-smoke,
or native input posting was performed. Gesture artwork, `assets/gesture_*`, and
`HandGestures.swift` were not edited. Settings page changes are visible wording
only. The approved HTML sections were rendered with the supplied Playwright Core
and Google Chrome at 1100 px in both themes, with no page/console errors.

Local checks use `scripts/run-tests.sh`. The final suite has 409 passing Swift
Tests in 54 suites, plus one passing Python Stream Deck package test. All 30
source layout lints pass. New tests cover Cursor idempotence, each tool entering
Draw, the mode toggle returning to the last tool, hidden-pointer state mapping,
permission-denied UI retention versus unchanged protocol rejection, checked wheel
Cursor/Draw, native toolbar frame stability, sound identities and symbol loading,
local lesson completion, and empty practice canvas mounting/resizing/replay.

Builds use only `scripts/build-review.sh --package-only`. A temporary Python venv
at `/private/tmp/lhp-phaseA-build-venv` supplies Pillow, which the shell's Python
lacked. The review app and bundled Stream Deck plugin pass local universal build,
Developer ID signature checks, notarization, stapling, Gatekeeper assessment,
archive integrity, and installer-contract checks. The installed review app was
not replaced. Build and test logs are in the verification directory below.

Snapshots use `scripts/snapshot-usability.py`, fresh disposable S-023/radial-v9
suites, test-mode view fixtures, Accessibility denial, temporary hand/thumbnail
directories, and `APP_SNAPSHOT`. The script refuses an existing Review endpoint,
terminates only its own processes, and deletes only its generated defaults domains.
Every capture is an app-owned native window, including the real tool popover.
The pointer is never activated for the snapshot fixtures, and no native event is
posted. The wheel captures use its opaque test accommodation for repeatable
contrast. Physical permission grants are not changed.

The snapshot pass is run after unit tests finish. An early concurrent pass lost
wheel focus while unit tests created AppKit windows. Native inspection also found
and fixed premature practice success from the Settings sample canvas, plus dark
custom-symbol tinting. Final snapshots were checked individually in both themes
for selection, disabled history, contrast, clipping and alignment. The practice
canvas starts empty, has no success message, and disables Next until a local
completed action. Toolbar frames stay 632 × 48 pt with a 284-pt context and the
same measured positions for every shared button. All eight popover optical layout
probe files pass `scripts/check-layout.swift`.

Snapshots live under `dist/verification/usability-icons-phaseA/`:

- `popover-cursor-light.png`, `popover-cursor-dark.png`
- `popover-pen-light.png`, `popover-pen-dark.png`
- `popover-hidden-light.png`, `popover-hidden-dark.png`
- `popover-permission-light.png`, `popover-permission-dark.png`
- `toolbar-cursor-light.png`, `toolbar-cursor-dark.png`
- `toolbar-pen-light.png`, `toolbar-pen-dark.png`
- `toolbar-picker-light.png`, `toolbar-picker-dark.png`
- `wheel-cursor-light.png`, `wheel-cursor-dark.png`
- `wheel-draw-light.png`, `wheel-draw-dark.png`
- `welcome-light.png`, `welcome-dark.png`
- `practice-light.png`, `practice-dark.png`

`manifest.json` records acknowledged native state for all 22 captures. Popover and
wheel captures have optical/item layout JSON; toolbar captures record exact shared
button frames. `mock/` contains the supplied HTML's eight section renders in both
themes. `tests.log`, `build.log`, and `snapshots.log` retain the actual check output.

Native decisions and departures from the web mock:

- AppKit popovers, switches, buttons and material retain native metrics and the
  system switch accent. Selected tool/favorite rings and practice accents use
  brand purple/lavender. SF Symbols replace the web's line icon drawings.
- The popover is at least 320 pt wide to fit all nine 28-pt ink targets. The legacy
  280-pt test-width request remains accepted but normalizes to this minimum. A
  short status row stays inside the popover to explain hidden and not-ready states.
- The toolbar is 632 pt wide. Its 284-pt context reserves space for the supported
  eight favorites plus All pointers, so fewer favorites leave intentional space.
  The permission action is in the picker rather than an extra toolbar row.
- Tap sound uses three speaker symbols with explicit help/AX values, distinguishing
  audible, pointer-muted, and app-muted output. The mock's tap-hand glyph did not
  supply these three states.
- The neutral wheel hub shows pointer artwork and esc. Inspected/disabled commands
  retain v9 explanatory hub feedback, list routing, focus and VoiceOver semantics.
  Existing labels such as Clear drawing and the v9 wheel palette stay intact.
- Welcome uses native drawn picture tiles and a held-key glyph with the full key
  name in help/AX text. Practice keeps its desktop-readiness and shortcut links,
  and starts with a blank canvas. The mock's illustrative sample cannot count as
  a completed action. Local steps are Click, Draw, back to Cursor, then Quick
  controls; replay, back, skip, next and cancellation remain available.

Not physically verified: global shortcuts, real click-through or drawing over
another app, pointer tracking, toolbar dragging/right-click reset, real permission
repair, screenshots/magnification, audio playback, capture exclusion during a real
capture, or a full VoiceOver session. The local model/responder tests and guarded
fixtures cover their state and routing, not these physical acceptance checks.
The macOS 13 material path and SF Symbol fallback are retained in source, but this
run did not execute on macOS 13. Known functional issues from Phase A: none found
in the completed local checks; these physical/runtime items remain for lead review.

Final artifact: Look Here Please Review 1.2.0, build `20261118184220`.
Review archive SHA-256:
`c523f19e13d689963af18438c7e45a2d26a3d7ecb8c446753edd3ca57dd6ac79`.
`phaseA-files.json` lists all 34 Phase A source/test/script/doc paths and check
counts. The native picker is captured as its own app-owned window rather than a
composited desktop image. Final snapshot matrix: 22 PNGs, all visible/nonempty,
with identical 632 × 48 pt toolbar frames in light/dark and Cursor/Draw.

Delivered through Austin Deliveries, verified `delivered`:
https://drive.google.com/drive/folders/1w9uhsG7IVoBgoFM38I45dddsIaRsHeYK
The delivery includes the review ZIP, all 22 native PNGs, snapshot state manifest,
and Phase A file/check manifest. Local originals remain in `dist/`.

## Usability icons Phase B1, 18 November 2026

Implemented over the intentional uncommitted Phase A, Settings and Quick controls
v9 work on `feature/usability-rethink-icons`. No commit, stash, revert, push,
hosted CI, live-smoke, native input posting or real-preferences edit was used.
Gesture artwork, `assets/gesture_*`, and `HandGestures.swift` are outside this work.

UX: Pointers is one library plus an inline selection inspector. The star means a
toolbar pin. Library selection explicitly returns to This, even for an entry that
cannot be activated. Defaults edits shared values and previews a lavender Sample.
Empty filters offer Show All; save errors stay inline; missing artwork and hidden
entries keep visible status. Each value has an accessible name and independent
reset help naming its inherited value. Menus expose secondary and recovery actions.
New Hand remains the existing short modal task. General contains app-wide setup,
Getting Started, About and the existing confirmed Reset flow.

### Capability checklist, old control to new location

| Previous control | B1 location and retained behavior | Evidence |
| --- | --- | --- |
| Seven sidebar pages | Pointers, Tools, Shortcuts, Presets, General, each with an SF Symbol | UsabilityB1Tests legacy routes; General/Pointers snapshots |
| Appearance / Pointer defaults / effects route | Pointers, Defaults scope | Route tests for all aliases |
| Sound route | Pointers, Defaults scope, sound row anchor | SettingsRedesignTests and B1 route cases |
| About route and menu | General, About content at the bottom | Canonical direct-enum and parsed-route tests; General snapshots |
| Tools pane routes | Existing Drawing, Magnification, Screenshots bodies | B1 route tests; no body redesign |
| Practice shortcut links | Existing Shortcuts group reveal and native control focus | Existing SettingsRedesignTests and ShortcutNavigationTests |
| Toolbar pin / unpin | Separate 28-point star in grid and inspector, one to eight | B1 stars/capacity/ordering and existing control pin tests |
| Toolbar favorite ordering | Favorite context menu Move Left / Move Right | B1 ordering; SettingsAccessibilityTests |
| Quick controls assignment | Favorite context menu Wheel direction; selected slot and swap outcome named | B1 swap and migration; existing RadialModelTests |
| Disabled / unavailable wheel slots | Fixed map positions N, NE, E, SE, SW, W, Back S, All pointers NW | RadialFavorites tests; map snapshot; raw IDs retained |
| Search and library filters | Top search/count and All / Favorites / Hidden icon segments | B1 derived-filter tests, PointerLibraryFilterTests |
| Enable / disable pointer | Inspector More > Hide from Lists / Show in Lists | PointerCatalogTests and existing enable-pointer protocol tests |
| Current-pointer Customize sheet | This inspector beside the full library | This with overrides snapshots; sheet implementation removed |
| Per-pointer size | Inspector size row with small/large type artwork, percentage and reset | Five-field reset test; non-hand rules |
| Per-pointer shadow on | Hand inspector shadow switch, override dot/reset | Five-field inheritance test; This snapshots |
| Per-pointer shadow style | Hand inspector style picker, independent override/reset; kept while off | Five-field inheritance test; existing PointerConfigurationTests |
| Per-pointer sound on | Hand inspector tap switch and its own reset | Five-field inheritance test; existing AudioTests |
| Per-pointer sound choice / audition | Hand inspector choice, play and reset | Existing SoundOutputTests; This snapshots |
| Non-hand sound / Presentation shadow | More > Sound and effects; sound preview and reset to defaults | Existing configuration/protocol tests; primary hand rows remain hidden |
| Reset Appearance & Sound with Undo | Inspector More; existing confirmation, guarded Undo Reset in place | Existing configuration tests; scope/field-reset tests |
| Global size / shadow / style | Defaults inspector, all shared rows always present | Defaults scope test and snapshots |
| Global tap sound / sound choice | Defaults inspector, including play | Defaults/override isolation tests and snapshots |
| Light / dark / patterned preview | Inspector preview background icons | Native preview snapshots; PointerPreviewTests |
| Preview Tap / Preview Motion | Play button; Preview Motion in its context menu | Local playback tests; no desktop input |
| App sound volume / mute | Every pointer card, separate real mute button and volume slider | Existing SoundOutputTests; inspector snapshots |
| Motion follow | Every pointer card Follow picker | Existing pointer motion tests; inspector snapshots |
| Tap swing / hand stays on click | Every pointer card motion More popover | Existing TapSwingTests and InteractionTests |
| Gesture import / restore / shortcut | Two gesture tiles with edit badges and menus | Existing GestureTests; native tile snapshots; unchanged lookup |
| Custom creation and image validation | + New Hand, existing prompt/import/name sheet | Existing HandRecoveryTests and SettingsRedesignTests |
| Custom rename | Inspector More > Rename, same ID and atomic manifest save | B1 custom rename test |
| Restore pointer artwork | Inspector More > Restore Artwork, file picker, durable prior-byte copy and guarded Undo | B1 artwork recovery conflict, lookup-name and renderer invalidation tests |
| Custom remove / recovery | Inspector More > Remove, existing confirmation and library Undo Remove | Existing HandRecoveryTests and removal-configuration tests |
| Permissions | General, status icons and existing repair links | General snapshots; permission routing tests |
| Login / updates / theme | General, original controls and updater behavior | General snapshots; no startup mutation in verification |
| Getting Started | General practice link | Existing practice routing tests |
| About / attribution / license / notices / build | Bottom of General | General light/dark snapshots |
| Reset All Settings | Bottom of General, destructive text, existing confirmation and Export Backup First | Same resetAll implementation; removed only the old Presets button |
| Practice progress and desktop readiness | Step icons, one-line instruction, info help; keyboard shortcut icon | Existing practice completion/routing tests; light/dark practice snapshots |
| Practice Undo / Clear | Icon buttons with help and accessibility labels | Existing practice history tests; native snapshots |
| Welcome / practice Quick controls icon | Native circle/hub/six-spoke template glyph | B1 glyph test; welcome/practice snapshots |
| Popover / toolbar All pointers icon | Native hand-in-grid template glyph, original action/help | B1 glyph test; native popover/toolbar snapshots |

### Saved data and migration

No saved-data schema or key changes. FavoriteLibraryConfiguration.migrated is a
read-only semantic migration: the star adopts `pinnedStyles`; the wheel continues
using `quickControlFavorites`. The regression seeds different orders, an absent
custom wheel pointer, and a disabled toolbar pointer. Reading migration writes
nothing. Starring, unstarring, moving and enabling do not alter wheel slots.
Explicit direction reassignment alone uses RadialFavorites' existing swap rule.
PointerOverride's five independent optional values and legacy laser-sound migration
are unchanged, including protocol null resets and archive compatibility.

### Local verification

`scripts/run-tests.sh` passes with **422 Swift tests in 55 suites**, including 13
new B1 cases, plus one Python Stream Deck package test and 33 source layout lints.
The changed PointerPreview view also passes its direct layout lint. The final
log is `dist/verification/usability-icons-phaseB1/tests-final.log`.
The B1 regressions cover legacy routing, pins versus wheel migration, capacity
and ordering, independent override resets, Defaults isolation, non-hand policy,
derived filters, artwork recovery conflicts and asset lookup names, renderer
invalidation after same-style artwork restoration, custom rename, glyph identity,
and maximum-size compact preview bounds.

The approved mock was rendered with the supplied Playwright Core and Google
Chrome through `/tmp/lhp-tools/parts.cjs`, at 1100 CSS pixels in both themes.
There were no page/console errors. Section 03 and the General frame in section 06
were inspected against `review-sol-r4.md`. Mock images are in this pass's `mock/`.

Builds use only `scripts/build-review.sh --package-only`, with the existing
`/private/tmp/lhp-phaseA-build-venv` providing Pillow. The installed app is not
replaced. No hosted test/build/packaging workflow was enabled or dispatched.

### Native decisions and limits

- Native controls retain macOS metrics and system accent. The five-page sidebar
  stays 200 points wide. Pointers opens at least 1040 points wide to keep the
  296-point inspector beside the library. Long libraries scroll normally.
- The top row retains a short Pointers heading, a visible derived count, and a
  labeled New Hand button. These make the native destinations and empty results
  clear. The mock compresses them further.
- Compact preview scale is transient and has an inside-sample grip. Desktop and
  practice sizing keep their existing behavior. Preview Motion is in the play
  button's context menu, retaining the previous capability with less visible copy.
- Non-hand This keeps size as its only primary value row. Its existing sound
  overrides and Presentation shadow are available under More > Sound and effects.
  These were absent from the mock and remain for compatibility.
- Wheel direction items name the selected direction and whether assignment swaps
  or replaces the saved occupant. Disabled and unavailable identities remain
  visible. Assignments remain independent from stars and toolbar order.
- Restore Artwork asks for a validated transparent source image. Prior local bytes
  are kept before replacement; Undo refuses to overwrite later changes. Same-style
  preview and live renderer caches are invalidated. No gesture lookup or bundling
  changes are included.
- More, favorite, gesture and motion popup presentation was not opened by the
  existing safe test bridge. Opening those native SwiftUI menus would require a
  further UI-driving fixture or native input, which was excluded from this task.
  Their state and underlying actions have model/unit coverage; no menu screenshot
  or manual menu interaction claim is made.
- Physical global shortcuts, desktop pointer tracking/click-through, real drawing
  over other apps, live audio, permission repair, hardware, full VoiceOver and
  macOS 13 runtime behavior were not verified. Existing tests cover routing and
  state; they do not replace those physical checks.

### Final capture and build record

Final review app: **1.2.0, build 20261118192415**. The universal review app and
bundled Stream Deck plugin pass the local build, Developer ID signature checks,
notarization, stapling, Gatekeeper assessment, ZIP integrity and exact-archive
installer checks. `build-final.log` records the completed checks. After the final
placeholder color adjustment, `scripts/run-tests.sh --filter
'UsabilityB1Tests|PointerPreviewTests'` also passes all 20 focused tests, the Python
package test and all lints. There are no compiler warnings in these final logs.

All **42 native PNGs** are in `dist/verification/usability-icons-phaseB1/` and were
opened and inspected individually for alignment, clipping and contrast. The final
pass fixed native Menu image sizing, segmented scope composition, compact preview
cropping, destructive button styling, and missing-artwork contrast. Missing artwork
uses a clear placeholder, including inside a light sample in the dark app.
The 28 exported GridProbes files pass `scripts/check-layout.swift`; toolbar frame
readback stays 632 × 48 points in Cursor and Pen in both themes.

Each name below has `-light.png` and `-dark.png`:

- `settings-general`, `settings-pointers`
- `pointers-this-overrides`, `pointers-defaults`
- `pointers-laser`, `pointers-spotlight`, `pointers-presentation`
- `pointers-hidden`, `pointers-missing-artwork`, `pointers-favorites8`
- `welcome`, `practice`
- `popover-cursor`, `popover-pen`, `popover-hidden`, `popover-permission`
- `toolbar-cursor`, `toolbar-pen`, `toolbar-picker`
- `wheel-cursor`, `wheel-draw`

Pointers shows the complete library and separate star controls; normal scrolling
continues below the visible final row. This with overrides shows five independent
dots/resets. Defaults has its Sample, two shared shadow rows and no pointer actions
or gestures. Each non-hand state has matching type artwork, correct size label
and no primary hand rows. Hidden includes a disabled hand and a missing-image
custom hand without activating either. Eight favorites retain the direction map
and show "8 is the most". General includes all its setup, attribution and Reset
content with no clipped controls. Practice starts with a blank canvas and disabled
history; its progress wheel and shortcut/info icons are visible. Welcome and both
quick entry points show the new product glyphs. The wheel's original focus and
Cursor/Draw selection remain intact.

`snapshot-pointers-b1.py` produces 20 Settings images and the B1 state manifest.
`snapshot-usability.py` produces 22 own-window entry-point images and native state
readback. Both scripts refuse an existing Review endpoint, use generated isolated
suites and temporary hand/thumbnail folders, terminate only their own process and
delete only their own defaults domain. No user preferences or permission grants
are changed. The final fixtures are stopped.

The source/test/script/doc file list is `phaseB1-files.json` in the verification
directory. Existing generated icon outputs are refreshed only by the mandated
review build script. The protected gesture source/assets were not edited.
Known functional issues in the completed local checks: none found. Native menu
presentation and the physical/runtime checks listed above remain for lead review.

## Usability icons Phase B2/C, 18 November 2026

Implemented on feature/usability-rethink-icons over the intentional uncommitted
Quick controls v9, Settings, Phase A and B1 work. No stash, revert, commit, push,
delegation, hosted CI, live-smoke or native input posting occurred. All UI fixtures
use generated disposable defaults suites and temporary Hands/Thumbnails. Only this
app's windows and attached sheets were captured.

Tools has labeled icon tabs for Ink, Magnifier and Capture, a shared local Ink
practice canvas with Pen/Arrow, Undo, Replay, dark paper and Clear, the current
hand swatch plus all eight inks including white, width chips and the full range,
opacity, Keep/Fade/Trail stroke pictures, mode-specific fade wording, and an
always reachable advanced disclosure. The pen practice uses the production
InkVisibility/InkTrail clock during the drag. Arrow practice uses the real arrow
shape and whole-mark fading. Magnifier and Capture settings remain available.

Shortcuts adds the optional Suggested transaction and exact assignment Undo.
Statuses, Add count, search count and group assigned counts are derived. The
26-command catalog, native recorders, Clear and Escape cancellation remain.
Preset cards have separate selection/Apply, artwork, ink/sound/favorite metadata,
a current-setup Now badge, More actions and Save current. The durable Undo row is
always present. Backup inclusion and local-only boundaries are explicit. Import
review keeps its safety-copy message above the scrolling details. Recovery copies
has a real list and replacement review, then journals current state before restore.
Rename preserves the saved setup. Reset remains in General.

Phase C bundles all 72 approved per-hand canvases directly, retaining base hand
anchors. Lookup is custom, bundled per-hand, then generic composition. Custom and
non-hand behavior is retained. Both inspector tiles and its local renderer show
the actual lavender, pixel and robot OK/Shaka poses. Source design files were not
changed. One-pixel plush/robot rod trims remain as approved. The resource audit
proves lossless pixel-stream and color-metadata preservation. Original PNG bytes
sum to 26,331,005; bundled files sum to 25,851,248, saving 479,757 bytes.

B1 polish removes the duplicate pointer-search count and drawing-step instruction.
Back and Replay Step are icon buttons with help and accessibility labels.

### Local test evidence

scripts/run-tests.sh passed all **439 Swift tests in 57 suites**, the one Python
Stream Deck package test and **36 grid lints**. The final full run took 94.635
seconds. The focused B2/C run passes **17 tests in two suites**, including:

- Empty-only suggestions, app/system/runtime conflicts, enabled symbolic hotkeys,
  supported single-modifier hold, avoidance of VoiceOver modifiers, late failures,
  per-outcome counts and exact Undo including absent/malformed/legacy values.
- Trail practice erasing from its start while drawing, with real delay/speed;
  arrows staying whole while held and then fading; Arrow replay geometry.
- Preset Now matching across values, pointer identity, ordered favorites and
  semantic overrides; backup inclusion/local-only boundary wording; name-only
  rename; restore safety copy, failure-before-write, stale review and exact Undo.
- Direct resource presence and lookup for every one of 72 canvases, retained base
  anchors, custom precedence and cache invalidation, bundled-to-generic fallback,
  custom-hand fallback and non-hand exclusion. Existing archive tests also cover
  export/import of gesture artwork and machine-local preference exclusions.

Logs are in dist/verification/usability-icons-phaseB2C/tests-final.log and
tests-focused-final.log. Compiler warnings: none in the final test logs.
One earlier full run aborted in the existing InputTap teardown path. Two later
full runs passed with no InputTap source change. Its exact diagnostic is retained
in input-tap-teardown.ips and test-teardown-intermittency.txt. No fix or root-cause
claim is made for this intermittent test failure.

### Native visual verification

The required Settings matrix contains **46 B2/C snapshots plus six standard
Settings snapshots** in dist/verification/usability-icons-phaseB2C/. Every name
below has -light.png and -dark.png:

- tools-ink-fade, tools-ink-trail, tools-ink-advanced, tools-magnifier, tools-capture
- shortcuts-default, shortcuts-added, shortcuts-expanded, shortcuts-recording
- presets-cards, presets-included, presets-recovery, presets-import-review,
  presets-restore-review
- pointers-lavender-gestures, pointers-pixel-gestures, pointers-robot-gestures
- gesture-preview-lavender-first/second, gesture-preview-pixel-first/second,
  gesture-preview-robot-first/second
- settings-drawing, settings-shortcuts, settings-presets

settings-manifest.json records actual route, expanded groups, current-preset count,
result line and mounted control state. Added shows "2 added · 1 already set ·
1 skipped". Recorder shows Press keys in the focused Cursor ↔ last tool row.
Tools includes both fade labels, all three advanced controls, the nine swatches,
and visible icon tab labels. Magnifier/Capture preserve their native content.
Preset cards show Now and separate Apply, inclusion names both kinds of custom
artwork, and both review sheets say a recovery copy is saved first. Restore names
Saved presets for the tested journal and states which settings stay on this Mac.
The Pointers search count appears once, and each hand has material-specific pose
thumbnails. Local ArmView previews show both poses, the retained rod and cursor
anchor, without activating the desktop overlay.

### Native decisions and remaining limits

The implementation keeps native macOS controls, system accent, the five-page
sidebar and normal scrolling. Labeled Tool tabs use a shared strip of native
buttons because SwiftUI's segmented Picker omits Label images on macOS. Pen/Arrow
uses labeled native segments. Fade seconds keeps the native picker and supports
existing arbitrary stored durations. Advanced timing is a disclosure rather than
always expanded. Suggested result stays in its card so Undo remains available
throughout the session. Presets uses an adaptive grid. The recovery and import
sheets retain detailed native reviews rather than the abbreviated mock popovers.

Physical global shortcuts, live drawing over other apps, screenshot/magnifier
capture, permissions repair, audio, full VoiceOver navigation, and macOS 13 runtime
behavior were not verified. Native SwiftUI More/gesture menu popups were not opened
by the safe bridge. Their underlying actions and restore lookup have model tests.
The existing InputTap test intermittency above is the only observed functional
verification issue retained for lead review. No other functional issues were found
in the completed B2/C checks. Lead review remains pending.

### Final B2/C build and capture record

Final Review app: **1.2.0, build 20261118195702**. The source-matched universal
arm64/x86_64 build used only `PATH=/private/tmp/lhp-phaseA-build-venv/bin:$PATH
scripts/build-review.sh --package-only`. It passed Developer ID signature checks,
notarization, stapling, Gatekeeper, ZIP integrity and exact-archive Stream Deck
installer verification. The installed app was not replaced. See build-final.log.
The temporary Python environment supplies Pillow to the existing icon build step.
No compiler warnings appear in the final build log.

Summed bundle file bytes increased from **87,552,082 to 114,654,088**, a delta of
**27,102,006 bytes, 25.846 MiB**. The 72 new gesture PNGs account for 25,851,248
bytes. app-size.json and gesture-resource-audit.json retain the measurements.
The stapled local archive is dist/Look Here Please Review-review.zip.

All **74 native PNGs** were opened and inspected individually. The final required
52 Settings snapshots and their layout exports pass scripts/check-layout.swift;
new Presets and Shortcuts root probes are included in this build. The additional
22 snapshots from snapshot-usability.py cover practice, welcome, menu popover,
toolbar/picker and wheel in both themes. Practice has one drawing-step instruction
and icon Back/Replay controls. Popover hand swatches, stable toolbar composition,
and wheel Cursor/Draw remain readable in both themes. The blank practice canvas
and disabled initial history are expected. Existing library and expanded shortcut
content continue through normal scrolling below the visible window edge.

Additional paired names are practice, welcome, popover-cursor, popover-pen,
popover-hidden, popover-permission, toolbar-cursor, toolbar-pen, toolbar-picker,
wheel-cursor and wheel-draw. manifest.json contains their native readback, and
visual-review.json enumerates all 74 inspected PNGs with hashes. Final own-window
fixture processes are stopped. phaseB2C-files.json lists 102 authored source,
test, script, doc and resource paths, distinct from prior uncommitted work and
build-generated icon/plugin outputs. All source changes remain uncommitted for
Claude's lead review.


## Usability icons round 1 fixes, 18 November 2026

All 12 findings in `design/usability-icons-2026-11-18/review-native-r1.md`
and all seven numbered findings in `code-review-r1.md` are addressed on
`feature/usability-rethink-icons`. The InputTap lifetime defect and the dead UI
note are addressed too. The intentional Quick controls v9, Settings and Phase
A/B1/B2C work remains uncommitted. No stash, revert, commit, push, delegation,
hosted CI, live-smoke or native input posting occurred.

### Changes and regression coverage

Suggested shows Hold with the Option keycap and announces the full held-key
action. Welcome, practice and wheel help share the trigger wording. Practice
separates desktop instructions from its local center-hold exercise. Shadow uses
the review's visible-label alternative with a layer symbol. Now uses primary
text with an accent checkmark. Browsing has a neutral outline, current Apply is
disabled, and all preset cards have the same outer height.

Shortcut groups and command rows are compact. Only assigned commands have Clear;
the recorder teaches Esc cancellation while recording. OK and Shaka use the
current hand's real thumbnails, with generic pose artwork for non-hands. The
wheel glyph is shared. Practice has a larger empty canvas, history in its header,
help beside the title, completed checks and a current-step announcement. General
keeps About in a disclosure. Tools prose is shorter. Pointer names use two lines
at 11 points, capacity reads 8 of 8, and the preview exposes a Tap/Motion menu.
The access banner precedes the popover tools; its footer explains the retained Pen.

The picker and palette keep the toolbar revealed after the reveal deadline.
Pointer-off, toolbar-off and capture still dismiss it. Backup export and import
now allow only the canonical built-in replacement PNG names, include their exact
bytes, reject conflicting local bytes, and support recovery. The inclusion list
names restored built-in artwork. Suggested Undo stores only changed keys and
checks their exact after-values before reverting. It preserves later edits and
reports their command names. Current eligibility rechecks live conflicts.
Non-hand sound enabled, sound choice and Presentation shadow reset independently.
Recovery listing runs off-main, retains small metadata entries and unreadable
copies, and loads full journal payloads for review or Undo. Import names the file,
shows changes first and folds inventory into Details. Restore names changed presets.
The permission button's native accessible name follows all three visible titles.
Unused toolbar picker/drag, Sound and gesture view trees and unused drag/swap hooks
were removed; shared artwork, sound and About helpers remain.

`Tests/TinyHandTests/UsabilityFix1Tests.swift` adds 14 regression methods, including
both real picker rows with an expired deadline in allowed/denied states, actual
non-hand edit/reset actions, byte-for-byte replacement artwork round-trip and
conflict/recovery, intervening shortcut edits, retry after conflict clearance,
broken historical recovery, catalogue payload-read counting, all three native
permission button names, practice progress and the two real gesture poses.
The full finding-to-fix-to-evidence map is `findings.json` in the evidence root.

### InputTap lifetime

The pre-fix full-suite abort reported in `code-review-r1.md`, and the earlier
Phase B2/C abort evidence, remain part of this record. A passing focused run did
not supersede those failures. The callback previously received an unretained
InputTap, startup loaded weak self, and deinit invalidated/stopped without waiting.

Native code now retains a separate callback context for the entire callback
lifetime. That context holds a weak owner. Startup captures only the native
connection, never InputTap. The owner's explicit stop disables input, invalidates
the source/port on the event loop and waits for thread exit before releasing the
context. Stop is synchronous and idempotent. The event-thread final-owner path
invalidates inline and releases the context after the callback returns, avoiding
a self-join. OverlayController stops its connection before releasing it and accepts
an injected tap. The parameterized mode/tool test uses injected installation
operations rather than a real system tap.

Each final full run installed, stopped twice and released 24 real native taps.
All 72 final lifecycle cycles passed. Injected restart/stop also passes. No claim
is made that one stack trace alone proved the old abort's precise cause.

### Three consecutive full local runs

Only `scripts/run-tests.sh` was used for tests. Each run used its generated
disposable defaults suite and temporary Hands/Thumbnails folders.

| Run | Swift result | Swift seconds | Python package test | Grid lints | Exit |
| --- | --- | ---: | --- | ---: | ---: |
| 1 | 453 tests in 58 suites passed | 94.360 | 1 passed | 35 passed | 0 |
| 2 | 453 tests in 58 suites passed | 94.599 | 1 passed | 35 passed | 0 |
| 3 | 453 tests in 58 suites passed | 95.053 | 1 passed | 35 passed | 0 |

There are no compiler warnings or InputTap teardown aborts in these three logs.
The final logs are `tests-run1.log`, `tests-run2.log`, `tests-run3.log` and
`test-results.json`. Earlier passing runs and initial test-fixture compile errors
are retained separately. The final two copy/layout adjustments were followed by
these three full runs, then a new source-matched build.

### Final build and native verification

Review **1.2.0 (20261118205305)** was built only with
`PATH=/private/tmp/lhp-phaseA-build-venv/bin:$PATH scripts/build-review.sh --package-only`.
Universal arm64/x86_64 compilation, Developer ID signing, app and bundled plugin
notarization, stapling, Gatekeeper, ZIP integrity and exact-archive installer
verification passed. The installed app was not replaced. `build-final.log` and
`build-result.json` retain the receipts and archive hash. All 200 recorded
source/test/script hashes match `source-manifest.json` after packaging.

All evidence is under `dist/verification/usability-icons-fix1/`.

- `snapshot-pointers-b1.py`: 22 native captures, including This/Defaults, all
  non-hands, hidden/missing artwork, eight favorites and closed/open About.
- `snapshot-usability-b2c.py`: 56 captures covering every Tools pane, shortcut
  default/result/expanded/recording states, preset/inclusion/recovery/import/restore
  views, three hand inspectors and both poses for each hand.
- `snapshot-usability.py`: 32 captures for the menu popover, toolbar/picker,
  wheel, Welcome's permission states, and empty/current/completed practice steps.
- Eight extra Presets captures use process-only `-AppleAccentColor` arguments for
  red, yellow, green and purple, each in light and dark. These use fresh disposable
  suites and `snapshot-settings.py`; no system preference is written.

All 118 captures were inspected. The final recapture has 98 of 110 main images
pixel-identical to the inspected first pass. All 12 changed images were reopened:
build/date text, the clearer practice wording, the fitted recording hint and tiny
native grayscale differences. Gesture inspectors were also reviewed in native-size
crops. All eight accent captures were opened. `visual-review.json` lists every
final image and hash; `snapshot-comparison.json` retains the pixel comparison.
The gallery is `visual-review.html`. All 94 GridProbes reports pass. Toolbar/wheel
frame readbacks use their own schemas and are retained separately from that count.

One recapture check initially included stale toolbar/wheel frame JSON in the
GridProbes input glob. This was a harness schema mismatch, not a failed Settings
probe. The stale readbacks were moved aside and the required capture/check scripts
were rerun successfully. `snapshot-usability-b2c-mixed-schema.log` retains that
attempt; final script logs and `layouts-final.log` show the passing checks.

Dark Now text is sRGB **(223, 225, 227)** over **(45, 57, 70)**,
measured at pixels (858, 302) and (890, 306):
**8.97:1**, above 4.5:1. Light measures **11.93:1**.
The lowest measured ratio in the eight real accent captures is **7.89:1**
for dark yellow. Measurements convert the embedded display profile to sRGB;
`contrast.json` records pixel positions, colors and each measured ratio.

### Remaining scope

No reported finding remains open in the completed checks. Claude's independent
re-review is still pending. Physical global shortcuts, live drawing/capture/audio,
full VoiceOver navigation and macOS 13 runtime behavior were not exercised.
All fixture processes are stopped. Normal preferences and permission grants were
not changed. The build and evidence are a local implementation handoff, not a release.

## Usability icons round 2 fixes, 18 November 2026

Closed R2-01, R2-02 and R2-03 in
`design/usability-icons-2026-11-18/code-review-r2.md`. The Suggested finding in
`review-native-r2.md` is the same R2-02 issue. Existing uncommitted work was
preserved. No commits, delegation, hosted CI, live-smoke or native input posting.

| Finding | Fix | Regression evidence |
| --- | --- | --- |
| R2-01: recovery metadata hides valid journals or selects damaged journals | Sidecars are optional hints with bounded journal-header fallback. Settings resolves the latest readable Undo off-main, reads candidates sequentially and retains only summaries. Actual journal failures are recorded, and an Undo read failure refreshes the candidate. Historical listing remains lightweight. | `UsabilityFix2Tests.settingsRecoversHealthyJournalWithBrokenMetadata` reviews and undoes a valid journal with truncated metadata. `settingsSkipsBrokenJournalDespiteHealthyMetadata` selects an older readable journal, records the damaged newest copy and covers damage after Settings has selected that newest copy. |
| R2-02: Suggested teaches proposed keys for occupied commands | Occupied rows render the saved chord or modifier hold and the visible state Already set. Malformed occupied values remain protected and show Existing assignment kept without proposed keycaps. The existing Preferences observer refreshes the mounted view when another control changes a binding. | `suggestedShowsCurrentBindingsAndUpdatesWithExternalEdits` covers Shift hold, a custom Shift-Command-B chord, Control hold after an external edit, clearing a chord, change notifications and malformed occupied values. Visible and accessible instructions use the tested row presentation. |
| R2-03: favorite buttons retain old names/artwork | Both controls update each existing button when its artwork signature or title changes. Images, tooltips and accessible labels refresh in place; frames and actions are retained. The toolbar also observes custom-hand changes for immediate rename refresh. | `existingFavoritesRefreshArtworkNamesAndArtworkUndoInBothControls` checks the actual toolbar and popover buttons across a custom-hand rename, in-place artwork replacement and production artwork Undo, with unchanged favorite IDs and button identities. |

All four new tests first reproduced the reported failures. The initial targeted
run failed with 21 assertions. The focused run then passed. Both logs are retained
as `tests-regression-red.log` and `tests-regression-green.log`; the full final runs
also cover the later additions for separate rename refresh and damage after Undo
candidate selection. Tests live in `Tests/TinyHandTests/UsabilityFix2Tests.swift`.

### Two full local runs

Only `scripts/run-tests.sh` was used. Each invocation generated its own disposable
defaults suite and temporary Hands/Thumbnails directories.

| Run | Swift result | Swift seconds | Native InputTap lifecycle | Python package test | Grid lints | Exit |
| --- | --- | ---: | --- | --- | ---: | ---: |
| 1 | 457 tests in 59 suites passed | 101.627 | 24/24 installed, stopped twice and released | 1 passed | 35 passed | 0 |
| 2 | 457 tests in 59 suites passed | 101.318 | 24/24 installed, stopped twice and released | 1 passed | 35 passed | 0 |

No compiler warnings, failures or teardown aborts occurred. Evidence is in
`dist/verification/usability-icons-fix2/tests-run1.log`, `tests-run2.log` and
`test-results.json`.

### Review build

Review **1.2.0 (20261118212230)** was built using
`PATH=/private/tmp/lhp-phaseA-build-venv/bin:$PATH scripts/build-review.sh --package-only`.
Universal arm64/x86_64 compilation, Developer ID signing, app and bundled plugin
notarization, stapling, Gatekeeper, ZIP integrity and exact-archive installer
checks passed. The installed app was not replaced. No v1 operation, storage key,
archive schema or deployment target changed.

App notarization ID: `ff8a4858-ee51-4d76-9f81-f049962bda95`.
Archive: `dist/Look Here Please Review-review.zip`.
Archive SHA-256: `0f81a26d10da1dd98797ca9702bc3f3d82ac27d3f249a74f5de4eaa2b78c7aa0`.
`build.log` and `build-result.json` retain the receipts. All 201 source, test and
script hashes in `source-manifest.json` still match after building and capturing.

### Focused native snapshots

All files below are in `dist/verification/usability-icons-fix2/`.
Each stem has `-light.png` and `-dark.png` versions.

| Stems | State and visual inspection |
| --- | --- |
| `settings-shortcuts`, `shortcuts-custom` | Pre-existing Shift-Command-B Pointer binding and Shift Quick controls hold. Suggested visibly shows those saved keys with Already set. Rows fit, keycaps remain readable and the active Settings window has no unwanted focus ring or clipping. Captured through the required `scripts/snapshot-settings.py` and the same focused-window endpoint. |
| `shortcuts-live-change` | The same mounted Shortcuts page changes to Hold Control after configure edits the hold elsewhere. Already set remains visible and the custom Pointer chord remains correct. |
| `popover-before`, `toolbar-before` | Custom favorite uses Lavender artwork and the name Demo pointer. |
| `popover-renamed-artwork`, `toolbar-renamed-artwork` | The same favorite ID now uses visibly different Robot artwork. Native readbacks report Renamed pointer. Buttons stay aligned and legible in both appearances. |
| `popover-artwork-undone`, `toolbar-artwork-undone` | Prior Lavender bytes are restored to the same file. The favorite returns to the original artwork while retaining the new name. Shared toolbar-button frame maps match before/replacement/restoration in both appearances. |

All **18 PNGs were opened and inspected**. All **12 GridProbes reports pass**;
the six toolbar reports use their existing frame/readback schema. Four toolbar
frame comparisons pass. `snapshot-manifest.json` retains the control readbacks;
`visual-review.json` lists every inspected PNG and SHA-256. `snapshots.log` and
`capture-fix2.py` retain the capture procedure.

Snapshots used fresh `settings-ui` and `s023` suites, temporary Hands/Thumbnails
folders and test-denied Accessibility. The favorites capture changes the fixture's
manifest and artwork atomically, then uses the existing local catalog refresh.
Its artwork-restoration capture restores the earlier fixture bytes; the regression
test above separately exercises the production `PointerArtworkRecovery.undo()`.
All fixture processes were terminated and their defaults domains deleted.
Physical shortcuts, live desktop drawing/capture, VoiceOver traversal and macOS 13
runtime behavior were not exercised.

## Usability redesign: code review r3 P3 follow-up (2026-11-18)

Code review round 3 approved with notes (`design/usability-icons-2026-11-18/code-review-r3.md`). Its one P3 is fixed: `Toolbar` now stores its `Preferences.changed` and `CustomHands.changed` observer tokens and removes them in `deinit`, so released toolbars no longer leave registrations behind. A full `scripts/run-tests.sh` run passed: 457 tests in 59 suites. The review build was not rebuilt for this change, so build 1.2.0 (20261118212230) still lacks it.
