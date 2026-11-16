# Input and cycle review implementation

Worktree: `/Users/apresley/.t3/worktrees/Please Look Here/t3-f3ec5cf9`.
Branch: `t3/hotkey-input-cycle-reliability`.
Scope: S-038, S-039, S-043. Swift 5 language mode and macOS 13 remain unchanged.

## S-038

Implemented a 180 ms bare-modifier hold deadline in the existing radial router.
Earlier mouse downs, ordinary keys, extra modifiers, release, scroll, eligibility
loss and closure cancel the pending opening. Mouse movement updates its origin.
Native modifier flags are sampled at the deadline and on configuration/service
refresh, including while closed. A sampled missed release cancels stale UI,
clears the held latch and increments `reconciledReleases` diagnostics. Existing
claimed button/Escape pairs survive closure, deactivation and trigger clearing.

Local evidence: `swift test --filter RadialTests` passed 15 tests. Tests exercise
179/180 ms boundaries, early native mouse/key pairs, closed/open missed-release
reconciliation and retained Escape/button ownership. Existing controls/lock
routing tests now explicitly advance the hold before checking pair ownership.
All commands use `TINYHAND_DEFAULTS_SUITE=com.austinpresley.tinyhand.inputcycle.unit`
and `TH_HANDS_DIR=/tmp/lhp-inputcycle-unit-hands`.

The historical reopen root cause remains a hypothesis. No native physical input,
UI automation, normal app preferences, signing, install or packaging was used.
Parent must verify the real modifier timing, release recovery and panel behavior.

Copy proposal: "Hold the modifier alone briefly to open. Clicks and key chords
before the menu opens keep their usual behavior." No new glossary term needed.

## S-039

`HotKeyBindings` retains native registrations by command and exact assignment.
Only removed/changed commands unregister; failed registrations retry independently.
A fake native driver covers one conflict among valid commands, retry/recovery,
exact replacement restoration and gesture identity changes without taking global
keys. Removed gesture bindings silently end their own pose owner. Assignment
validation still probes the proposed key before saving, restores the exact previous
optional assignment after a failed registration, and ignores unrelated failures.
Clearing an unavailable assignment remains possible.

Conflicts remain in the Settings model while context-scoped commands pause.
Each shortcut field shows its own persistent registration failure. The native
secondary menu has a nonmodal Review Shortcut Conflict item, naming the command
and key in help text and routing directly to Settings > Shortcuts. No alert or
notification permission is introduced. Recorder errors stay inline.

Local evidence: radial/input/controls regression run passed 36 tests. Shortcut
and menu checks passed 18 tests before adding the focused recovery-route check.
Grid lint passed for SettingsComponents, PresentationSettings,
HandGestureSettings, MenuBarControls and MenuBarCommands. Tests inject registration
results; no real shortcut blocker app or UI automation was run. Parent owns the
integrated native conflict/recorder rollback and light/dark checks.

UX flow: secondary menu > Review Shortcut Conflict > Shortcuts > record or clear
that command. Escape cancels recording. The existing native menu and shortcut
field supply keyboard/VoiceOver semantics. This follows the Mac design/layout
skills with visual verification reserved for the parent by task instruction.
Copy/glossary proposal: "Shortcut conflict" means a saved combination macOS or
another app currently prevents this command from registering. "Review Shortcut
Conflict…" opens Shortcuts without altering assignments.
Final S-039 focused run: `swift test --filter 'ShortcutTests|MenuBarTests|GestureTests'`
passed 24 tests, including the new native-menu recovery request check.

## S-043

Native Next Pointer and Previous Pointer now resolve the complete enabled,
available catalog and wrap in either direction. Pins remain toolbar favorites.
Both native commands refresh custom manifest membership first. A current pointer
outside the selectable set uses its first entry going forward or its last entry
going backward. One choice selects itself; an empty set rejects without mutation.

Protocol v1 `cycle-pointer` accepts optional `direction: "forward" | "backward"`.
Omission preserves forward behavior and old clients. Invalid direction values
reject before mutation. The Choose Pointer inspector offers Forward/Backward;
opening or receiving settings never writes them. An explicit direction change
merges all existing saved fields. Existing action UUIDs, fixed pointer settings,
activation and Interact remain unchanged. Each queue intent captures direction
at press time, using the existing FIFO and uncertain-request behavior.

Local evidence: `swift test --filter 'PointerCatalogTests|DeckKeyTests|ControlTests'`
passed 45 tests. Coverage includes both wrap boundaries, every native selectable
current pointer including unpinned choices, disabled/missing custom images,
single/empty catalogs, strict protocol validation, legacy defaults, stable action
UUIDs and immutable mixed-direction queue intents. A test expectation initially
counted one extra forward cycle incorrectly; corrected to the actual next entry,
then the full focused run passed. `node scripts/test-pointer-inspector.cjs` passed
5 tests against the actual inspector JavaScript, with DOM/socket stubs and no UI
or Stream Deck host. All changes compile through the local Swift test build.

The existing thumbnail exporter emitted 39 hex-named PNGs in this initially clean
worktree during `styles` tests because ControlTransport.directory is empty in a
bundle-less unit runner. Only those newly generated files were moved to
`/tmp/lhp-inputcycle-generated-thumbnails`; no pre-existing assets were touched.
This confirms the separately assigned S-044 test-output isolation issue. Further
bundle-less styles tests should use `-Xswiftc -DCONTROL_TEST` or the S-044 fix.

UX/copy proposals: "Cycle direction", "Forward", "Backward". Forward chooses the
next enabled available pointer and wraps to the first; Backward chooses the
previous and wraps to the last. Parent should update the central glossary and
architecture text that still describes pinned native navigation and a read-only
Choose Pointer inspector. Protocol details are updated in docs/control-protocol.md.

Parent acceptance checks still required: physical radial holds/chords and missed
releases; actual external hotkey conflict with unaffected command execution;
recorder rollback under a real conflict; light/dark Settings and native menu;
Stream Deck host inspector/profile preservation and physical forward/backward
keys; integrated UI validation and release packaging. The historical reopen
report is not physically closed by these unit tests. No PR, push, hosted CI,
signing, notarization, installation, package build or delivery was performed.
