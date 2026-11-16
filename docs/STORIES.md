# Look Here Please backlog

## App review improvements, 15 November 2026

Austin authorized all 18 recommendations from the joint app review. The active
milestone is [S-036 through S-053](app-review-implementation-2026-11-15.md).
Use Sol 6.1 High subagents, with no Max setting. Pointer cycling must wrap in
both directions through enabled choices, including Stream Deck. This milestone
supersedes the older queue's limits on the selected later ideas. All validation
and packaging stay local; hosted CI remains disabled.

## Selected fork upgrades, 14 November 2026

Austin authorized shortlist items 1, 2, 3, 4, 7, 9, 10, 12, 13 and 14 for autonomous implementation. The current milestone is [S-026 through S-035](fork-upgrades-2026-11-14.md), with its acceptance criteria, UX decisions and progress. Preserve the existing local review app and its user data. All validation and release packaging run locally; hosted CI stays disabled.

Recorded from Austin's app review on 10 November 2026. This is the current
implementation queue. The source feedback and unchanged areas are in
[the review record](FEEDBACK-2026-11-10.md).

The original intake recorded ten requested changes. Austin has now authorized
the follow-up queue below and asked for one Sol 6.1 agent at a time to implement
it. This includes promoting S-013 from an idea to implementation. Current
evidence is in [VALIDATION.md](VALIDATION.md).

## Working through the queue

Work on one story at a time, in the follow-up order below.
Before a UI story, settle its UX and record the choices under that story. Run
tests, builds, packaging and UI validation locally on Austin's Mac. Keep hosted
CI disabled. Record actual verification in [VALIDATION.md](VALIDATION.md) and
mark a story `done` only when its acceptance checks pass. Do not turn the
`Later` ideas into committed scope without further direction.

Keep the integration acceptance at the bottom as historical context. Existing
features do not become new work merely because they appear there.

## Current follow-up queue, 10 November 2026

This milestone contains Austin's latest requests. Finish it before taking on
older unfinished stories. Story IDs remain stable; the order here is the
execution order. Fix shortcut behavior first, then visibility, shared pointer
choices, Stream Deck, radial controls, menu bar and branding. Preserve existing
work in this already modified checkout. Do not stage or commit earlier edits
as if they belonged to a new story.

| Order | Story | Work |
| --- | --- | --- |
| 1 | S-015 | Make presentation hotkeys entirely user assigned |
| 2 | S-017 | Make the keep-hand option work in Interact |
| 3 | S-016 | Fix floating toolbar visibility |
| 4 | S-018 | Enable or disable hands and other pointer choices |
| 5 | S-019 | Use the selected hand from a Stream Deck toggle |
| 6 | S-020 | Cycle enabled pointers from Stream Deck |
| 7 | S-021 | Change or cycle drawing tools from Stream Deck |
| 8 | S-022 | Install the Stream Deck plugin from Settings |
| 9 | S-013 | Build the modifier-operated radial menu |
| 10 | S-023 | Redesign menu bar controls around the toolbar's approach |
| 11 | S-024 | Update the icon and GitHub branding for Look Here Please |

Each agent owns one story and returns its changes, local checks and remaining
acceptance gaps before another starts. Use `gpt-6.1-sol`, with inherited xhigh
reasoning. The model catalog exposes no `shift` option. Do not silently claim
that an unavailable model option was applied. Do not delegate nested work.

Coordinator progress: all eleven requested areas are implemented. S-015, S-017,
S-016, S-018, S-019, S-022, S-023 and S-024 passed their local acceptance and
coordinator review. S-020/S-021 retain physical Stream Deck and host-inspector
acceptance. S-013 retains its unresolved historical reopen failure and manual
review; 300 focused openings and four full native suites did not reproduce it.

The final combined app 1.0.2 build 20261110224547 is installed and running, including
Austin's separately completed softer-shadow changes. Plugin 1.0.3.2 is installed;
original preferences, hands, profiles/keys and both grants are preserved. The app,
plugin, branding ZIP and icon are delivered through [Austin Deliveries](https://drive.google.com/drive/folders/12u7hvtX73uec-qABMkIQN8kuK8eiDmCn).
GitHub branding is live at commit 7017192888053ec37bcc96fc4b4cdeb92c4213b9; functional
source changes remain local. Hosted CI remains disabled. No implementation agent
is active. Exact final checks and limits are in VALIDATION.md.

### S-025 Add Spotlight and a telescoping presentation pointer

As Austin, I choose Spotlight or a telescoping presentation pointer alongside the existing hands and Laser dot.

Acceptance:
- Both pointers are enabled by default and support selection, pinning, disabling, cycling, radial controls, menu bar controls, AppleScript and Stream Deck thumbnails through the existing catalog.
- Spotlight leaves a clear, softly edged circle around the real cursor and dims the surrounding current display. Pointer size changes the circle size. Hiding or turning off the pointer removes all dimming.
- Presentation pointer has a silver segmented shaft, dark grip and coral tip. Its tip stays at the real cursor through motion, taps, size changes and display bounds changes.
- Existing activation, Interact, annotations, pointer choices and saved toolbar pins keep their behavior. No new permissions or default shortcuts.
- Local tests, active light/dark Settings captures, rendered pointer checks and signed/notarized packaging pass.

UX:
- Flow: Settings > Pointers, menu bar Choose Pointer, radial Pointer, or existing automation > select either pointer > keep the current On/Off and Interact state. Choose another pointer or Pointer Off to leave.
- Surface: existing library tiles and choosers. No new window or modal.
- Words: "Spotlight" and "Presentation pointer". Appearance > Pointer > Size controls the aperture or shaft thickness.
- States: enabled, disabled, selected and pinned use the existing catalog rules. Both are drawn natively and do not depend on image files. Hiding for app controls also removes the spotlight shade.
- Access: existing named native menu choices and library controls. A small contrasting center marker shows Spotlight's exact click point. No new animation or modifier assignment.

Verified: 110 local tests in 16 suites, seven existing grid lints plus the pointer library lint, five active light/dark Settings captures with passing layout reports, four guarded native input checks, catalog/AppleScript/Stream Deck thumbnail checks and universal signed/notarized packaging. Build 1.0.2 / 20261110234249 is installed with both grants and normal preferences preserved. Delivered through [Austin Deliveries](https://drive.google.com/drive/folders/1UCslRnEooaYbCclqBHrZhFvhPPVwgVXP).

Status: done

### S-015 Make presentation hotkeys entirely user assigned

As Austin, I choose my shortcuts instead of inheriting preset hotkeys.

Screens: Shortcuts, menu bar commands, toolbar help.

Acceptance:
- [unit] A fresh settings domain and Reset All have no assigned presentation or tool hotkeys. An unassigned command never registers a global hotkey.
- [self] Each configurable command can be assigned and cleared. Clearing survives relaunch and does not restore a fallback shortcut.
- [unit] Existing explicitly saved assignments survive the change. Implicit factory defaults do not become saved user choices.
- [self] Duplicate, reserved and unavailable assignments produce useful feedback and leave the previous assignment intact.
- [snap] Settings displays an understandable unassigned state. Menu equivalents, help and documentation reflect the actual assignment, without advertising removed defaults.
- [manual] Standard editing keys still work inside the app's text fields. Any presentation shortcuts intercepted outside app windows follow the same user-assignment rule, including annotation Undo/Redo if globally registered.

UX:
- Flow: Shortcuts -> record a command or clear its assignment -> changes apply immediately.
- Surface: existing shortcut rows, with an Unassigned state and a clear action. Reset All clears assignments.
- States: every row starts Unassigned; record a combination to assign it, or use Clear to remove it. Failed assignments keep the prior value and show the reason inline.
- Command map: optional annotation Undo/Redo, Settings and Turn Pointer Off join the existing configurable commands. App-window Edit commands and Command-comma remain native and local; no Escape or other presentation key registers by default.
- Access: expose the command name and assigned value. Preserve ordinary editing commands in focused app windows.
- Verified: 49 unit tests, all 18 assign/clear paths, real Carbon conflict rejection, relaunch/reset, native recorder and editing, 13 guarded fixture checks, light/dark assigned/unassigned/error/bottom snapshots, eight layout reports and signed/notarized packaging. Exact commands and limits are in VALIDATION.md.

Status: done

### S-016 Fix floating toolbar visibility

As Austin, I configure the floating toolbar to hide and see it hide as promised.

Screens: Appearance toolbar settings, floating toolbar visible and hidden.

Acceptance:
- [manual] Reproduce the floating toolbar failing to hide under its configured visibility behavior before changing code. Austin explicitly clarified that this report concerns the floating toolbar.
- [self] The setting's enabled and disabled states apply immediately and persist across normal relaunches, with no competing window or activation code undoing the choice.
- [self] With Show toolbar off, startup, pointer activation, hover and mode changes cannot reveal the toolbar. With it on, its intended reveal/hide behavior works without a stuck visible panel.
- [manual] Verify activation, Settings open/close, pointer on/off, hover and Interact transitions. Hiding the toolbar leaves working menu bar access to the app.
- [snap] The setting label and help match the behavior that was actually fixed.

UX:
- Flow: Appearance -> Show toolbar -> apply immediately; the choice survives relaunch. Menu bar controls remain available while hidden.
- Surface: the existing native switch in Appearance. Use one name, "Show toolbar", for its label and Accessibility value.
- On: reveal for three seconds at pointer startup or when enabled, and while the cursor is near its last position. Moving away hides it after any startup grace period. Drawing suppresses the toolbar.
- Off: keep the toolbar hidden through startup, pointer activation, hovering, Settings and Interact changes, including drawing-permission recovery. Permission help remains in the menu bar and existing welcome window.
- Words: explain the automatic reveal/hide behavior and the off state next to the switch; include the timing in hover help. No new preference or shortcut is introduced.
- Access: native switch and menu commands remain keyboard accessible. Inspect affected active light/dark Settings and toolbar captures; record audit limits in VALIDATION.md.
- Verified: native opacity repro failed three times before the fix and passed afterward; 52 unit tests, 19 native visibility checks, native Settings persistence/menu access, light/dark captures, four layout reports and signed/notarized universal packaging passed. Evidence and limits are in VALIDATION.md under S-016.

Status: done

### S-017 Make the keep-hand option work in Interact

As Austin, I choose whether the hand stays visible while I interact with another app.

Depends: S-004

Screens: General, native interaction with the option on and off.

Acceptance:
- [snap] The Interact controls offer an easy-to-find Keep the hand visible while interacting option.
- [unit] The default remains enabled. Stored choices survive relaunch and Reset All returns to enabled.
- [manual] With Interact on and the option enabled, the selected hand stays visible during native clicks and drags, while the underlying app receives normal input.
- [manual] With the option disabled, the existing documented press/drag hide and release restore behavior works. Changing the choice never changes Interact or pointer selection.
- [self] Reconcile this report with S-004's existing implementation. Fix the discovered visibility or discoverability gap instead of adding a duplicate preference. Record fresh runtime evidence if the existing behavior already satisfies the request.

UX:
- Keep one preference in General next to Interact. Show its meaning in plain language and use the same saved value everywhere.
- Flow: General -> Keep the hand visible while interacting -> native switch -> the saved choice applies immediately, including during an existing press.
- States: on by default and after Reset All; off hides during native presses and drags until every button releases. Interact, pointer selection and pointer activation stay independent.
- Access: the native switch exposes its full label and on/off value. The row and its explanation fit without scrolling in light and dark.
- Verified: existing S-004 behavior satisfies this request in installed build 20261110153518. Fresh native switch, relaunch/reset, fixture click/drag, overlapping-button and mid-gesture checks passed. No production change or duplicate setting was needed. Commands, evidence and limits are in VALIDATION.md under S-017.

Status: done

### S-018 Enable or disable hands and other pointer choices

As Austin, I control which hands and pointer choices appear in quick selection.

Screens: Pointers gallery, quick pointer choices, custom pointer entries.

Acceptance:
- [snap] Settings lets me enable or disable built-in hands, custom hands and other selectable pointer choices without deleting their assets.
- [unit] Choices persist across restart; existing installations receive a usable enabled set. Disabling a choice preserves its customization.
- [self] Quick selectors use the same enabled set. Keep the complete library visible in Settings so disabled choices can be re-enabled.
- [unit] Disabling the currently selected choice and attempting to disable the last enabled choice follow explicit, deterministic rules and cannot leave a broken pointer selection.
- [self] Automation reports the enabled set so Stream Deck and radial controls can use it. Unavailable or removed custom assets remain distinguishable from disabled entries.

UX:
- Flow: Settings -> Pointers -> Enabled checkbox in the complete pointer library -> immediate saved change. Toggle again to reverse it. Disabled entries stay visible with their name and thumbnail.
- Surface: inline native checkboxes in the existing gallery page. The complete library includes built-in hands, custom hands and Laser dot. Select is a separate button, enabled only for an enabled, available choice.
- Pins: existing toolbar pins are favorites, independent of Enabled. Disabling keeps the saved pin and its order. The live toolbar, pin picker and next/previous pinned commands filter to enabled, available choices. If no saved pin is usable, the live toolbar offers the first enabled available choice without writing a pin. The Settings pin row retains disabled favorites for removal/reordering. Enabling never pins; pinning never enables. Reset toolbar affects pins only.
- Defaults: all built-in and custom choices start enabled, including newly added hands. Store disabled IDs so upgrades do not silently shrink the library. Reset All enables every choice and preserves custom files.
- Fallback: disabling the selected pointer selects the first remaining enabled available entry in built-in order, custom manifest order, then Laser dot. Pointer activation and Interact stay unchanged. Reject the last available enabled choice with "Keep at least one available pointer enabled." Show this inline, and return the same message to automation.
- Availability: a custom hand whose PNG is missing or unreadable stays in the library as "Image unavailable". Its Enabled checkbox remains editable, but Select is unavailable. Restore the same asset to recover its saved enabled state and pin. Explicit Delete still removes the hand. If external removal leaves no usable enabled choice, automatically enable the first available built-in, or Laser dot if no hand loads, and select it. Do not automatically switch back when an image reappears.
- Validation: UI, AppleScript and JSON reject disabled or unavailable selections before changing selection, activation or a settings batch. Keep v1 operations and fields; add enabled/available/selectable metadata, the ordered enabled catalog and a validated enable-pointer operation. No Stream Deck or radial behavior is added here.
- Access: native labeled checkboxes, named Select buttons, visible status text and inline rejection. Inspect active light/dark gallery and quick selectors, exercise native checkbox and keyboard paths, and record accessibility audit limits.

Evidence:
- 58 local unit tests in 12 suites, six new catalog cases, nine isolated protocol/runtime checks, 19 native toolbar-opacity checks and 13 native-input checks passed. Saved enable choices, selected custom pointer and temporary toolbar fallback survived clean relaunches.
- Native Settings enabled/disabled built-in, custom and laser choices, retained disabled entries and thumbnails, and rejected the last available enabled choice inline. Active light/dark gallery, custom/missing/error states, pin picker and filtered/fallback toolbar captures were inspected; six layout reports and four grid lints passed.
- Signed/notarized universal version 1.0.2 build 20261110164405 installed with stable identity and both grants retained. Normal preferences and real custom-hand hashes match the starting copies. Exact evidence and access/runtime limits are in [VALIDATION.md](VALIDATION.md) under S-018.
- API and future-agent examples are in [control-protocol.md](control-protocol.md). Stream Deck and radial implementation remain later stories.

Status: done

### S-019 Use the selected hand from a Stream Deck toggle

As Austin, I toggle my current hand from Stream Deck without unexpectedly selecting another hand.

Depends: S-018

Screens: Pointer On/Off action settings, key states, app selection.

Acceptance:
- [self] Pointer On/Off uses the app's selected pointer by default and never changes that selection as a side effect of toggling.
- [snap] If a fixed-pointer option is provided, the inspector clearly distinguishes Current pointer from a specific enabled choice. Existing saved keys migrate predictably.
- [self] Any fixed choice validates availability and enabled state before mutation. An invalid choice reports failure without partially changing pointer or activation state.
- [self] Observed key feedback follows app state, including pointer changes made elsewhere, pending commands and failures. Preserve immediate physical press feedback and never replay an uncertain mutation.

UX:
- Flow: add Pointer On/Off -> press -> the app toggles its current pointer once -> the key shows the acknowledged hand or Laser dot with On/Off. Press again to reverse activation.
- Surface: read-only action inspector, headed Current pointer, explains that the choice comes from the app. There is no fixed-pointer override, picker, settings write or migration. Existing Pointer On/Off keys keep their action ID and ignore any saved style/activate fields.
- State: the actual observed thumbnail or laser fills the key; On/Off remains explicit. Missing artwork shows an unavailable-image symbol with observed On/Off. Stopped, no reply and checking remain distinct. The press border, pending arc, accepted receipt, rejection, uncertainty and stale-sample marks retain their existing meanings. No mutation is replayed.
- Refresh: status reads follow selection changes made in the app or automation; safe catalog refreshes update custom artwork while keys stay visible. Enabled-set fallback remains app-owned and independent of toolbar pins.
- Words/access: "Current pointer" and "Turn the pointer selected in Look Here Please on or off. Your selection stays the same." Static inspector text requires no keyboard interaction. Meaning uses words and symbols as well as color. Physical device, VoiceOver and full accessibility acceptance remain separately recorded limits.

Evidence:
- The existing v1 `toggle` already preserved selection. The change replaces generic hand feedback with the actual observed hand/laser, adds read-only Current pointer copy and refreshes custom artwork while keys stay visible. No fixed-toggle option or migration was added.
- All 61 local tests in 12 suites and three existing grid lints passed. Real plugin-to-app replay passed 66/66 checks, including built-in/custom/laser toggles, app-owned fallback, replaced/missing art, pending double-press suppression, dropped replies, no mutation replay, disabled/missing fixed-action rejection and restart recovery.
- Native Pointers -> Select Robot updated the already-visible toggle key to the exact observed Robot/Off bitmap without activation or Interact changes. Inspected 72 px and 144 px state sheets, read-only inspector at 240/320/420 px, and native Settings/key captures. The native layout report passed.
- Plugin 1.0.1.0 built universal, passed the Elgato validator before and after extraction, Developer ID verification and notarization Accepted. App production sources/resources did not change; installed 1.0.2 build 20261110164405 remains signed, stapled and Gatekeeper accepted with both permissions retained.
- Austin's real preferences, custom hands, Stream Deck files and normal runtime state match the starting copies. No host installation, hardware acceptance, commit, push, PR or upload is claimed. Commands, evidence, early runner corrections and limits are in [VALIDATION.md](VALIDATION.md) under S-019.

Status: done

### S-020 Cycle enabled pointers from Stream Deck

As Austin, I press Choose Pointer to move through the hands and choices I enabled.

Depends: S-018, S-019

Screens: pointer-cycle key and inspector, corresponding app state.

Acceptance:
- [self] Each press advances once through enabled, available choices and wraps from last to first in a stable order. Disabled choices never enter the cycle.
- [unit] One enabled choice, a missing current choice, removed custom assets and an enabled-set change while keys are visible have defined behavior.
- [self] The app owns the cycle operation so rapid presses cannot use stale plugin state to select the same next choice repeatedly.
- [snap] The key clearly shows the current acknowledged pointer. No fixed-pointer picker is required for the normal cycle action.
- [self] Existing fixed-selection actions remain understandable or migrate explicitly, with no silent reuse of a saved fixed choice as the cycle list.
- [manual] A physical key press cycles once and updates its artwork after acknowledgment. Record hardware acceptance separately from protocol replay.

UX:
- Flow: add Choose Pointer -> press -> app selects the next enabled, available pointer in library order and wraps. The key shows the acknowledged current pointer with On/Off. Cycling preserves activation and Interact; use Pointer On/Off to activate an off pointer.
- Surface: read-only inspector, no picker or settings writes. New action UUID `com.austinpresley.lookhereplease.choose-pointer`; existing Select Pointer UUID/settings remain fixed with no migration or reinterpretation.
- Input: act on the first keyDown, require keyUp before another intent, queue rapid complete presses FIFO and send one app-owned request at a time. A held/repeated keyDown adds nothing. Pointer On/Off keeps its existing pending suppression.
- Recovery: never retry an uncertain mutation. Pause unsent cycle intents until a later successful status read, then send only those unsent intents. A stopped app or disappearing key cancels its unsent intents. No queue survives plugin exit. Pending/receipt/error/stale feedback remains separate from observation.
- Words/access: "Choose Pointer", "Next enabled pointer", and an explicit explanation that cycling keeps On/Off and Interact unchanged. Static inspector requires no keyboard interaction. Physical key acceptance remains separate from replay.

Evidence:
- 66 local tests in 12 suites and three grid lints passed. New app/catalog tests cover full-library order, unpinned choices, wrap, singleton/outside-current/empty sets, custom asset and manifest restoration, activation preservation and atomic invalid-field rejection. Plugin model tests cover style-free requests, observed feedback and FIFO uncertainty/cancellation.
- Real plugin-to-app cycle replay passed 87/87 checks. Seven rapid complete presses advanced seven times; duplicate keyDown advanced once; multiple keys serialized; changing the enabled set between queued requests used the new app state. A dropped reply paused unsent intents, resumed them only after safe status recovery, and never retried the uncertain mutation. Page departure and stopped/restarted app canceled unsent input. S-019 replay remains 66/66, including pending toggle suppression and disabled/missing fixed-action rejection.
- Inspected actual received key frames at 72/144 px, plus the read-only inspector at 240/320/420 px. Native app UI did not change. App 1.0.2 build 20261110171759 and plugin 1.0.2.0 are universal, Developer ID signed and notarized Accepted. App identity/permissions, extracted payload validation and normal-state/preferences/assets/Stream Deck file restoration passed. Exact evidence, commands and limits are in [VALIDATION.md](VALIDATION.md) under S-020.
- Physical Stream Deck press and host-rendered inspector remain pending. The host is installed but this plugin is not installed there; no profile/key was changed. Replay does not satisfy physical acceptance. The coordinator owns review and final delivery.

Status: implemented/review; physical Stream Deck acceptance pending

### S-021 Change or cycle drawing tools from Stream Deck

As Austin, I select or rotate through drawing tools without reaching for the toolbar.

Screens: drawing-tool key, action inspector, toolbar selected tool.

Acceptance:
- [self] Stream Deck provides a tool action with a cycle choice and explicit Pen, Rectangle, Arrow, Text and Number choices.
- [unit] Cycling advances once in a documented stable order and wraps. App-side validated actions own selection and cycling.
- [self] Selecting a tool follows the toolbar's Interact behavior and permission checks. Rejection leaves state unchanged and explains the problem.
- [self] Key feedback reflects the actual tool and Interact state, including changes made outside Stream Deck, pending operations and reconnects.
- [manual] Verify physical key behavior separately. If dial rotation is supported, document and validate its events rather than treating key cycling as tested dial support.

UX:
- Flow: add Choose Tool -> inspector Tool choice defaults to Cycle tools, or choose Pen, Rectangle, Arrow, Text or Number -> complete presses select once -> cycle key shows the acknowledged current tool; fixed key retains its assigned tool and marks readiness only for a matching observation. Change the choice to reverse configuration; use Interact to return to native input.
- Surface: native labeled select in the Stream Deck inspector. New UUID `com.austinpresley.lookhereplease.choose-tool`, saved `tool` choice. An omitted choice defaults to cycle; unknown, empty, null or non-string saved values show invalid-choice guidance and reject without sending a mutation.
- Order: app-owned `cycle-tool` reads the current tool on the main queue, then advances Pen -> Rectangle -> Arrow -> Text -> Number -> Pen. Fixed selection uses existing validated `tool`. Both preserve pointer activation and selection and turn Interact off like the toolbar. An off pointer stays off. Missing Accessibility or capture in progress rejects before changing tool, activation or Interact, with the actual reason.
- Input: pointer cycles and all tool choices share one FIFO with typed immutable command intents and key-incarnation IDs. First keyDown acts, keyUp separates deliberate presses, held duplicates add nothing. Settings changes affect future presses only. One command is outstanding; sent uncertain mutations never retry. Unsent intents pause until a successful safe status read; disappearing keys and stopped app cancel unsent input. Existing pointer toggle and fixed pointer behavior stay intact.
- State: cycle keys show the observed tool symbol/name; fixed keys retain their assigned tool symbol/name. Explicit pointer On/Off and Interact/Draw detail stays observed. A fixed key shows the ready border/check only when its target matches the acknowledged current tool and the pointer is active, drawing, permitted and not capturing. Lock/capture, input border, pending arc, receipt, rejection, uncertain and stale marks remain distinct. Pending and receipts never fabricate selection. Fixed names remain visible while error/uncertainty/connection guidance uses the detail line.
- Access: Tool choice has a native label, keyboard selection and associated help/error text. Inspect 240/320/420 px widths and actual 72 px key art. Only Keypad is registered. No dial acceptance without usable hardware.

Correction UX:
- Fixed keys retain their configured glyph/name in every state. Cycle keys retain the observed current tool. Only a fixed key matching the acknowledged current tool may show the ready border/check, and only while drawing is ready. On/Off and Interact/Draw remain observed detail. Disconnected, unknown, rejection and uncertainty text use the detail line on fixed keys so the press destination stays visible.

Evidence from the original implementation, before the fixed-key review correction:
- 71 local tests in 12 suites and three existing grid lints passed. New cases cover strict cycle/fixed settings, malformed saved/wire values, observed tool/readiness, immutable mixed FIFO commands, stable app order, permission atomicity and capture-specific rejection without taking a screenshot.
- Real plugin/app tool replay passed 120/120 checks. Preserved pointer-cycle replay passed 87/87 and current-pointer replay 66/66. Coverage includes rapid complete presses, held duplicates, fixed choices, settings changes while queued, mixed pointer/tool keys, external selection, delayed/dropped replies, safe-read recovery, page/replacement cancellation, permission rejection and stopped/restarted no-replay.
- Inspected received 72/144 px tool state sheets and the native-select inspector at 240/320/420 px, plus its invalid-choice state. Native label/help/error associations, settings registration and writes were checked. Host keyboard selection and full VoiceOver/Accessibility Inspector acceptance remain pending. Native app UI did not change.
- App 1.0.2 build 20261110173607 and plugin 1.0.3.0 passed universal local signing/notarization, app staple/Gatekeeper and extracted payload checks. Normal preferences/runtime state, custom hands, Stream Deck file hashes and both grants were restored/verified. Exact commands, isolated delta and S-022 handoff are in [VALIDATION.md](VALIDATION.md) under S-021.
- Host 7.6.0 is installed, with no USB Stream Deck and no Look Here Please plugin installed. Physical press/readability, host inspector and hardware reconnect remain pending; replay does not satisfy them. Only Keypad is registered. No profiles, saved keys, host plugins, commits or deliveries were changed by this story.

Correction evidence, 10 November 2026:
- Coordinator found that fixed Pen and Rectangle keys showed the same observed tool and could both appear ready. The prior model/replay expectations encoded that defect. Fixed glyph/name now identify each configured destination in every state; cycle artwork still follows the actual tool. Only the matching fixed destination can be ready. Observed On/Off/Interact/Draw, permission/capture and transient distinctions remain separate.
- Two new model tests failed against the prior model, then passed after correction. Fresh local results: 73 tests in 12 suites, three grid lints, tool replay 168/168, pointer-cycle replay 87/87 and current-pointer replay 66/66. The tool replay shows all five fixed keys against the same state, external changes and pending Number selection alongside Cycle tools.
- Reviewed received-frame sheets at 72/144 px and updated inspector copy at 240/320/420 px. Plugin 1.0.3.1 is signed/notarized. Existing signed app 1.0.2 build 20261110173607 is unchanged. Correction-only evidence, delta, package and restoration results are under `dist/verification/s021-review-fix/` and in VALIDATION.md. The original `s021/` evidence is unchanged.
- No physical key, Stream Deck host inspector, hardware reconnect or dial acceptance is claimed. No host installation, profile/key edit, upload or S-022 implementation occurred.

Status: implemented/review; coordinator accepted the fixed-key correction; physical Stream Deck and host-inspector acceptance pending

### S-022 Install the Stream Deck plugin from Settings

As Austin, I install this app's Stream Deck plugin directly from Settings.

Depends: S-019, S-020, S-021

Screens: Settings integration row, Stream Deck installer or actionable failure.

Acceptance:
- [snap] Settings has an Install Stream Deck Plugin action with concise requirements and useful status.
- [self] The signed app contains or resolves the plugin package that matches this build. The action opens that package with Stream Deck through the normal install flow; it does not require a terminal build or a development-folder path.
- [self] Missing Stream Deck, missing package and a failed open produce actionable messages. Installation never overwrites user profiles or saved key assignments.
- [self] Local app/plugin packaging and extracted-archive checks verify that the install resource is present and valid in the delivered app.
- [manual] Exercise the real Stream Deck installation UI on this Mac. Keep any unavailable hardware checks open rather than claiming they passed.

UX, settled before coding:
- Flow: Settings → General → Install Stream Deck Plugin… → Stream Deck's normal confirmation → confirm or cancel there → return to Settings. No profile or key assignment changes in the app.
- Surface: a Stream Deck card after Using the pointer on the existing General page. This is a recurring integration action, so inline status and a native button fit; no extra app dialog.
- Words: Install Stream Deck Plugin…; bundled plugin version; Requires Stream Deck 6.5 or later. Opening says Opening Stream Deck…; handoff says Finish installation in Stream Deck. Confirm the plugin there. Opening alone never means installed.
- States: missing host offers Download Stream Deck… using verified https://www.elgato.com/us/en/s/downloads; missing/corrupt package asks the user to reinstall Look Here Please; failed open asks them to open Stream Deck and try again. Keep the installer retryable.
- Access: native keyboard-focusable buttons, visible text status independent of color, wrapping copy, accessibility identifiers and help. Inspect the affected light/dark General page and layout probes.
- Package contract: build the universal signed/notarized plugin first, validate its extracted payload, then embed the installer plus its UUID/version/SHA-256, host requirement and matching app version/build in signed Resources. Verify that contract from the final app ZIP. No checkout paths or runtime downloader.

Evidence:
- 78 tests in 13 suites, five final installer seam tests, package rejection tests and four grid lints passed locally. Affected General and handoff states were inspected light/dark; all four layout reports passed.
- Final signed app 1.0.2 build 20261110181001 contains signed/notarized plugin 1.0.3.1. Both local notarization lanes and final ZIP/nested archive signature, version/hash, payload, executable and Elgato checks passed.
- Clicked the actual installed app's Settings button, confirmed the real Stream Deck 7.6.0 installer, observed its installed notification, and read version 1.0.3.1 by Austin Presley in host Plugins. Installed bytes match the built package; host logged Plugin connected. No terminal build or checkout path was needed for that flow.
- All 2,871 original Stream Deck files remain: 2,870 unchanged, with only expected host application-cache content changed. All 39 profile-related files are unchanged; 21 new files belong only to this plugin. No profiles or key assignments were edited. Normal preferences/state, hands, original evidence and both app grants were restored/verified.
- Only MCP Deck is available in the host canvas. Its Profiles page provides no disposable profile editor, so actual pointer/tool property-inspector verification remains open. No key was reassigned. S-020/S-021 physical key/readability/reconnect and dial limits remain open. Full VoiceOver/Accessibility Inspector audit is not claimed.
- Exact results, receipts, screenshots, hashes and this round's file delta are in `dist/verification/s022/` and VALIDATION.md. No subagents, hosted CI, staging, commit, push, PR or delivery.

Status: done

### S-013 Build the modifier-operated radial menu

As Austin, I hold a configured modifier and change controls at my cursor without navigating a persistent toolbar.

Depends: S-015, S-018

Screens: radial menu, nested pointer/color/tool choices, shortcut settings, optional toolbar.

Acceptance:
- [manual] A user-configured modifier opens the menu at the current cursor position. No factory hotkey or modifier assignment is installed. Keep the toolbar available as an option.
- [manual] Pointer, Color and Shapes/tools support nested movement paths without repeated clicks or timed hover. Include Interact and suitable existing controls.
- [self] Pointer choices use S-018's enabled set. Commands call the same validated app actions as the toolbar and automation.
- [manual] Use generous targets and a clear fingertip/dot selection point. Demonstrate selection, backtracking, center cancellation, Escape, outside click and modifier release at large pointer sizes.
- [self] Opening, selecting or dismissing never draws or clicks through to the underlying app, never revives held-to-Interact behavior and safely handles an existing drag.
- [snap] Fixed directions, readable labels and selected states work in light/dark, near display edges and with Reduce Motion. Record multi-display limits honestly.
- [self] Ordinary menu and keyboard access to the same commands remains available; controls expose names and state to Accessibility.

UX:
- Implementation plan, 10 November: nonactivating native radial panel, fixed eight compass directions. Pointer north, Color northeast, Tools east, Interact southeast, History south, More southwest. Nested choices occupy an outer ring; backtracking inside the inner ring returns to the root. Six catalog entries per page plus fixed Previous/Next directions keep full enabled/available library order without shrinking targets.
- Trigger: optional bare Option, Control, Shift or Command, explicitly assigned/cleared in Shortcuts. No default; Reset clears it. Pointer must be on, Accessibility available, no capture/text/Settings/menu or existing mouse press. Trigger during a drag is ignored until a fresh modifier gesture. Modifier flags and ordinary key pairs pass unchanged; any ordinary key or extra modifier cancels the menu and preserves its shortcut. Escape is consumed as a pair.
- Chosen commit behavior: release-to-select after deliberate movement. Both release policies were compared through real native input on the public fixture. Release-to-dismiss left the pointer unchanged; release-to-select chose the highlighted pointer with no underlying mouse events. Center and immediate release cancel. A click on a highlighted leaf also selects; any other click cancels. Claimed and overlapping presses drain through release after closure; a held modifier cannot reopen the menu.
- Edge: clamp the entire 592 pt panel to the cursor display visible frame, preserve directions and real cursor. If the center shifts, enter the visible center before the menu arms. No animation, including with Reduce Motion. A high-contrast dot marks the real cursor/fingertip above the large hand.
- Access: native named/stateful buttons plus existing ordinary menu commands, pointer/color submenus and keyboard menu navigation. Settings explains hold, move, release, backtrack and cancel. Toolbar OFF remains OFF.
- Preserve the earlier brief: a transient radial menu with shallow nested choices reached by movement and directions that support muscle memory.
- Native release-policy comparison completed. Release-to-select is the chosen behavior; center release cancels, current selection is visible and inward movement returns to the root.
- Keep Settings as the place for pointer fine-tuning. Align quick pointer order with the enabled library.
- Fit the menu near screen edges without rearranging the learned direction order. Use brief, restrained selection feedback.
- Opening modifier and release behavior are implementation choices to settle in this story. A configurable modifier must coexist with S-015's no-default-hotkeys rule.

Austin explicitly requested implementation in the latest follow-up. This replaces
the earlier idea-only authorization limit; the original interaction direction
remains in [the feedback record](FEEDBACK-2026-11-10.md).

Status: implemented/review

Review correction, 10 November: `RadialInput` now consumes every down for a claimed key until its matching keyUp, including Escape autorepeat after cancellation, trigger clearing and deactivation. The actual `InputTap.handle` regression failed twice with six assertions before the fix. The guarded native fixture received three owned repeat downs on the old build. Both exact commands now pass on app 1.0.2 build 20261110193126. `swift test --filter claimedEscapeRepeatsDrainThroughInputTap` uses the isolated unit suite/hands environment; `TINYHAND_VERIFICATION_DIR="$PWD/dist/verification/s013-review-fix" python3 scripts/radial-smoke.py --escape-ownership` verifies actual fixture key counters. Full local verification passes 91 tests in 14 suites, package checks, five grid lints, 32 radial native checks, 4 injected-denial checks and 13 existing native regression checks. The existing plugin-first signed/notarized build and independent extracted checks pass; plugin remains 1.0.3.1. New commands, receipts, baseline copies and round delta are in `dist/verification/s013-review-fix/` and VALIDATION.md.

One full native attempt failed to reopen the radial before a right/other mouse-drain case. The unchanged suite passed from a fresh LaunchServices instance. Its first failure/state are preserved; the cause is not established. No additional production change or new visual/layout acceptance is claimed. The 10,306 protected prior files, including all earlier story evidence, remain byte-identical. Normal state/preferences/grants are restored. S-023 and all earlier manual review limits remain unchanged.

Focused reopen review, 10 November: the retained counters narrow the failure to reopening for the other-button case after the claimed right-button release cleared and reassigned the trigger. Cause remains unresolved. A bounded same-process native review passed 300 focused openings and four full 32-check sequences in PID 64248. Final denial, 13 native regressions, 91 tests/14 suites, package checks and five lints pass; 11,011 protected originals are byte-identical. Evidence is in `dist/verification/s013-reopen-review/`. The runner now captures per-opening callbacks, native flags/buttons/tap state and failure state before cleanup, and offers a strict bounded reopen stress mode. Missing eligibility or tap readiness fails before the opening Option event, without waiting or reposting. No production change, app rebuild, new visual acceptance or S-023 work is claimed. Successful stress runs do not close the retained intermittent risk. See the new VALIDATION section and HANDOFF.md for final counts, restoration and round-only files.

Historical evidence below predates the Escape-repeat correction.

Evidence: installed app 1.0.2 build 20261110185016 and embedded plugin 1.0.3.1 both passed universal signed/notarized packaging and extracted checks. Local verification passed 90 tests in 14 suites, 28 radial native checks, 4 denied-permission checks, 13 existing native regression checks, actual Reduce Motion and native Settings assignment/clear. Fifteen radial and two active Settings layout reports pass. See VALIDATION.md and `dist/verification/s013/` for receipts, fixture counters, Window Server state, captures and the exact source delta.

Review limits: physical mouse/trackpad gesture feel, a full VoiceOver/Accessibility Inspector audit, end-to-end status-menu keyboard navigation, actual multi-display/mixed-scale behavior, older macOS and Intel runtime are not claimed. The code uses standard native menus and exposes real radial AX names, selected values and actions. These limits keep the story in implemented/review for coordinator review. S-023 is not implemented.

### S-023 Redesign menu bar controls around the toolbar's approach

As Austin, I get clear, compact presentation controls from the menu bar, in the same spirit as the toolbar.

Depends: S-015, S-017, S-018, S-013

Screens: menu bar controls in pointer on/off and Interact on/off states, secondary menu.

Acceptance:
- [snap] Replace the current long, flat command list with a considered control layout whose icons, grouping and state treatment agree with the toolbar and radial menu.
- [manual] Pointer activation, Interact, enabled-pointer choice and current drawing tools are easy to reach; drawing history, sound, capture, toolbar, Settings and Quit remain discoverable.
- [self] Controls observe actual application state and use shared validated actions. Permission failures, disabled history actions and capture-in-progress states stay accurate.
- [manual] Opening and dismissing the menu bar surface does not draw, click through or leave input suspended. Keyboard navigation, Escape and Accessibility work.
- [snap] Inspect light/dark, narrow screens and both interaction states. Product wording uses Look Here Please and user-assigned shortcuts only.

UX:
- Flow: left click the status item -> Menu Bar Controls -> change a control in place -> Escape, status-item click or outside press dismisses. Right click or Control-click -> grouped native commands. Settings closes controls before opening its window.
- Surface: compact native control panel anchored below the status item. A few related choices tied to one entry point, with native switches, a full enabled-pointer chooser, tool symbols, history, screenshot and sound. No nested popover.
- Command map: Pointer switch uses toggle; Interact uses explicit interact; Choose Pointer uses style without activate; tools use tool, preserving activation and selection while turning Interact off. History uses undo/redo/clear; sound uses toggle-current-sound; screenshot uses capture; toolbar uses configure.showToolbar; Settings uses settings. Secondary native menus group Pointer, Drawing and Presentation, followed by Settings and Quit. Only saved user shortcuts appear; local Quit retains Command-Q.
- State: switches/checkmarks always reconcile from observed app state after shared ControlBridge validation. Current pointer and tool remain explicit while inactive; readiness text distinguishes Pointer Off, Interact On, missing Accessibility and screenshot pending. Empty history disables its controls. Long pointer names truncate with full help; the native chooser scrolls all selectableStyles, independent of pins.
- Input: controls take an explicit suspension lease before ordering. The existing input tap owns outside-dismiss mouse/Escape pairs until matching releases; nested native menu tracking keeps the lease. Closing releases only the panel lease. Settings focus and capture guards remain independent. Radial cannot open over controls, and requires a fresh gesture afterward.
- Access: native key view order, Space to activate, arrows in chooser/tool group and native menus, Escape closes. Each symbol has an action name/help and selected/disabled state. Native text editing stays in the responder chain. Native material follows appearance and Reduce Transparency; no custom transition animation.
- Review: real light/dark, Pointer/Interact combinations, unpinned custom names, edges, native menus and Settings; fixture counters and tap ownership must prove no annotation or click-through.

Verified:
- Final app 1.0.2 build 20261110220842; 101 tests/15 suites, package contract and seven lints pass. Native checks pass 25 controls, four control-denial, 32 radial, four radial-denial and 13 existing regressions. Nineteen real native layout reports and light/dark panel/menu/Settings captures pass.
- Actual fixture counters prove status/outside/native-menu dismissal pairs and Escape repeats stay owned. Native arrow focus remains separate from observed tool selection; Space applies the focused tool. Automation remains live in right/Control-click tracking menus.
- Original normally installed build 20261110193126, real preferences/state, both grants and Keyboard navigation 0 are restored. Exact source delta, packages, commands and native traces are in dist/verification/s023/HANDOFF.md and VALIDATION.md.
- Coordinator review accepts the story's native controls, state, routing, keyboard and AX-action checks on this Mac, including the combined final build. Physical pointer/trackpad feel and a full VoiceOver/Accessibility Inspector audit were not exercised. Actual narrow/multiple displays, Intel/older macOS runtime, enabled Reduce Motion/Transparency settings and TCC revocation remain coverage limits. Native materials and disabled popover animation remain in use. S-013's historical reopen issue remains unresolved.

Status: done

### S-024 Update the icon and GitHub branding for Look Here Please

As Austin, I see my app's name and direction consistently in its icon and GitHub presentation.

Depends: S-001, S-013, S-023

Screens: Finder/Dock icon, About, README, GitHub repository presentation, project website assets.

Acceptance:
- [snap] Create and inspect a distinctive Look Here Please app icon at real Dock/Finder sizes in supported appearances. Keep menu bar symbols legible and consistent where appropriate.
- [self] Update the icon source and generation/packaging inputs so the branded icon survives rebuilding; verify the installed app uses the resulting asset.
- [snap] Replace stale upstream logo/banner and product copy in the owned repository presentation with Look Here Please identity and its pointer, annotation and quick-control direction. Audit About and linked website assets for conflicting branding.
- [manual] Update owned GitHub description or presentation metadata where appropriate using the verified repository identity. Do not rename/delete the repository or invent product URLs. Preserve license and upstream credits.
- [self] Verify local asset references, page links and packaged icons. All validation/builds remain local; hosted workflows must remain disabled, including before any GitHub push.
- [self] Deliver finished branding files and the final signed app/plugin packages through Austin Deliveries with verified HTTPS links. Record publication and delivery separately from local edits.

UX:
- Flow: Finder/Dock opens the same menu bar utility; About identifies Austin Presley and links to the owned repository; Credits retains TinyHand and Kamran Ahmed. No new interaction.
- Surface: existing icon, About and repository presentation. No new app window or website deployment.
- States: icon must read in default, dark, tinted and clear appearances and at 16/32 pt; template menu bar art uses a hollow/filled attention dot for Off/On.
- Brand direction: original cream pointing glove and attention dot on coral, with a plum cuff. Alternatives considered: a focus ring on blue, or a coral annotation loop on cream. Choose the glove for its recognizable silhouette at 16 pt. No SF Symbols or donor artwork in the identity.
- Owned links: https://github.com/austinpresley/please-look-here only. Clear the upstream homepage; Pages API is 404, no owned website is configured. Preserve MIT and origin links in Credits.
- Words: "Look Here Please", "By Austin Presley", "Point it out.". Published copy must say the expanded app is local review work and functional source is not yet on main.
- Access: native About links and keyboard behavior remain; no new focus or routing.
- Use the app's final control direction to guide the icon and copy. Keep the exact name Look Here Please. The identity should belong to Austin's product while crediting its origin.
- Prefer editing the existing SVG/Icon Composer sources for the app icon; use image generation only if raster artwork is actually needed.

Status: done

Implementation notes:
- Original vector glove/dot identity, generated AppIcon.icns/Assets.car and template menu symbols, plus editable banner and site marks. Icon Composer owns native appearances. Stream Deck identity art bumps plugin to 1.0.3.2; action IDs, key rendering and behavior are unchanged.
- About names Austin Presley, links the verified owned repository and preserves TinyHand/Kamran Ahmed credit and MIT. README and the former upstream site now distinguish local review from published functional source.
- Curated GitHub main commit 7017192888053ec37bcc96fc4b4cdeb92c4213b9 publishes 11 presentation files only. Description updated; upstream homepage cleared. No functional source, binary, release or Pages deployment published. Actions remains disabled; two inherited workflows were automatically indexed by GitHub after the commit and explicitly disabled, with zero runs.
- Final combined source is frozen under dist/verification/s024/combined-source, including accepted S-023 and all four completed S-007 shadow files unchanged from this task's start. Local full suite: 104 tests / 15 suites, package contract and seven lints. Final signed/notarized app 1.0.2 build 20261110224547, embedded plugin 1.0.3.2. Exact receipts, packages, source delta and final native/preservation results are in that folder's HANDOFF.md.
- Coordinator reviewed all icon appearances, installed identity, final package hashes, signature and live GitHub presentation. Final app, plugin, branding ZIP and icon are [delivered](https://drive.google.com/drive/folders/12u7hvtX73uec-qABMkIQN8kuK8eiDmCn), delivery ID 20261111T041104Z--8de0779bf7b7. The final GitHub description is "A playful native Mac pointer utility by Austin Presley. Point it out." Existing S-013 reopen and S-020/S-021 physical/host-inspector gaps remain open.

## Next review build

### S-001 Name the app Look Here Please

As Austin, I see Look Here Please wherever the app identifies itself.

Screens: General, About, Settings window, menu bar menu, application menu,
welcome window and Finder app bundle.

Acceptance:
- [snap] Settings, About, menus, startup wording and any welcome UI use the exact product name `Look Here Please`.
- [self] Bundle display names and the installed app filename use `Look Here Please`; executable lookup still works when the product name contains spaces.
- [manual] Audit About copy and links so upstream TinyHand branding is not presented as this app's own identity. Preserve license notices and upstream attribution; do not invent a website or source URL.
- [self] Renaming preserves settings, custom pointers and the existing app identity unless an explicit migration is required. Inventory identity-dependent paths before changing them.

UX:
- Surface: existing windows, menus and About. Display Look Here Please everywhere the app identifies itself; preserve the existing icon for this pass.
- Identity inventory: keep bundle ID com.austinpresley.pleaselookhere.integration, executable TinyHand, existing defaults domain and Application Support/Please Look Here/Hands. No data migration is required.
- About: describe this app, credit TinyHand explicitly as the original project and retain its MIT license. No invented website or source URL.

Implementation notes: Branding currently appears in `PresentationSettings.swift`,
`SoundSettings.swift`, `AppDelegate.swift`, `SettingsWindow.swift`, `main.swift`
and build scripts. `scripts/release.sh` currently assumes the app name is also
the executable name in some paths; account for that when renaming. Internal
Swift target names and legacy preference keys need not match the display name.

Status: done

Evidence: local implementation, regression/native checks and light/dark review are recorded in [VALIDATION.md](VALIDATION.md).

### S-002 Install signed and notarized test builds with stable permissions

As Austin, I install an updated test build without repeatedly granting the same
permissions because the build's identity changed.

Depends: S-001

Screens: Finder app bundle, General permissions, local build output.

Acceptance:
- [self] The testing build uses Austin's explicit Developer ID identity, hardened runtime and secure timestamp. It fails clearly if that identity is unavailable instead of silently falling back to ad hoc signing.
- [self] Notarization returns Accepted; the app's ticket is stapled and validated. Verify the distributed archive or disk image too, when one is produced.
- [self] Deep/strict signature verification and Gatekeeper assessment pass on the final artifact.
- [self] Consecutive test builds retain the same bundle identifier and compatible designated requirements. Installation replaces the complete bundle at one documented, stable path and launches that installed copy.
- [manual] Grant Accessibility and Screen Recording on build A, replace it with build B, and exercise Draw and screenshot capture without resetting permissions. Record the observed behavior, OS and build identities.
- [self] Local packaging uses this project's identity and update configuration. Do not inherit upstream release credentials, signer defaults or an upstream update feed for the renamed test app.

Implementation notes: `build-review.sh` is currently signed but unnotarized,
allows ad hoc fallback and launches the project copy after installing another
copy. `release.sh` contains upstream defaults and conflates product and executable
names. Adapt the local test-build lane deliberately. Apple notarization is
authorized for future test builds; public publishing is not part of this story.

Permission continuity depends on code identity, not notarization alone. See
[Apple's explanation of designated requirements](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements).
Use Apple's [command-line notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).
The two-build permission check is required evidence; do not promise that
notarization eliminates OS permission prompts.

Status: done

Evidence: build 20261110014637 was replaced by notarized build 20261110022351 at the same installed path with matching designated requirements. Both permissions remained allowed. Normal LaunchServices drawing/capture and a fresh-launch repeat passed without resetting permissions. See [VALIDATION.md](VALIDATION.md).

### S-003 Toggle Interact directly

As Austin, I keep the same pointer and toggle Interact on to use the underlying
app, or off to annotate, without holding a modifier.

Screens: General, toolbar with Interact on and off, menu bar menu.

Acceptance:
- [snap] Settings and toolbar present one Interact switch; the menu presents one checked Interact command. Remove the Point/Draw selector and held interaction-key picker.
- [self] Holding Option, Command or Control never changes Interact. Existing saved interaction-key settings cannot reactivate that behavior.
- [manual] With Interact on, native clicks, double-clicks, right-clicks, drags, typing and modified clicks retain their normal behavior. With Interact off, annotation gestures work with the same pointer.
- [unit] Mode changes during a press or drag preserve matching press/release routing and do not leave buttons captured or stuck.
- [manual] Toolbar, menu and existing configurable mode shortcut all select the same mode. Keep the currently accepted shortcut system.

UX:
- Flow: General switch, toolbar switch, checked Interact menu command or existing Control-Option-D shortcut -> same persistent state -> toggle again to reverse.
- Surface: inline switch because it changes one value. On uses apps normally; off draws on screen. Keep the pointer selection and annotation history when toggling.
- States: missing drawing permission keeps Interact on and offers Allow Drawing. Capture temporarily prevents interaction changes.
- Words: Interact. On: use apps normally. Off: draw on screen. No named Point or Draw modes in the UI.
- Access: native switch value and menu checkmark expose state; keyboard shortcut remains configurable. Keep ordinary modified clicks and command shortcuts.
- Compatibility: preserve stored point/draw values and protocol v1 mode requests. Add interact with an enabled boolean and state readback.

Austin's later clarification in this thread supersedes the original two-mode
wording. Removing the hold mechanism does not remove ordinary modified clicks,
annotation shortcuts or modifier-based command shortcuts.

Status: done

Evidence: local implementation, regression/native checks and light/dark review are recorded in [VALIDATION.md](VALIDATION.md).

### S-004 Keep the hand visible while interacting by default

As Austin, I keep the hand visible when using apps and can turn that preference
off.

Depends: S-003

Screens: General, pointer during native interaction.

Acceptance:
- [snap] Keep an explicit, understandable option for hand visibility while interacting.
- [unit] A fresh settings domain and Reset All both enable the option by default. Explicitly stored user choices remain respected.
- [manual] With the default enabled and Interact on, clicks and drags keep the hand visible while reaching the underlying app.
- [manual] Turning the option off changes visibility without changing Interact, blocking native input or requiring a held modifier.

UX:
- Flow: General -> Keep the hand visible while interacting -> toggle -> next native press uses the selected visibility behavior.
- Surface: inline switch, enabled by default for a fresh domain and Reset All. Respect explicitly stored choices.
- Timing: when disabled, hide during any native mouse press or drag with Interact on; restore when all buttons release. At rest the pointer remains visible. Drawing remains visible with Interact off.
- Access: native switch label and value. The system cursor becomes visible while the hand is hidden.

Implementation: `interactKeepsHand` defaults to true, and General and the runtime
read the same saved value. S-017 freshly verified the installed implementation,
including native presses/drags, last-button release and independent Interact
state. The earlier false-default note described the pre-S-004 code.

Status: done

Evidence: local implementation, regression/native checks and light/dark review are recorded in [VALIDATION.md](VALIDATION.md).

### S-005 Simplify the Drawing page's tool instructions

As Austin, I see concise drawing settings without the large block of tool
explanations.

Screens: Drawing, toolbar tools, contextual help if used.

Acceptance:
- [snap] Remove or shorten the redundant text in the Tools section, including the lengthy marker and text-label instructions.
- [manual] Drawing tools remain discoverable and usable through the toolbar and existing shortcuts. Put any essential instructions in concise contextual help.
- [snap] Keep line-width and opacity controls and their current meaning.

Status: todo

### S-006 Preview drawing settings in one live demo

As Austin, I see the effect of drawing settings as I adjust them.

Depends: S-005

Screens: Drawing with live preview, fade choices.

Acceptance:
- [manual] One shared demo updates while dragging line-width and opacity sliders, without applying or reopening Settings.
- [manual] The same demo reflects ink color, including the pointer-matched color.
- [manual] The demo shows the selected line fade and its timing. Keep until cleared visibly retains the sample; changing to a timed fade restarts a useful demonstration.
- [self] Preview interaction does not add to, clear or change the live annotation history.
- [snap] The preview and existing controls fit and remain readable in light and dark appearance.

Status: todo

### S-007 Give the fingertip a natural contact shadow

As Austin, I see a dark contact point where the finger touches, fading naturally
away from that point.

Screens: Pointer at rest and pressed, Appearance shadow setting.

Acceptance:
- [snap] At rest, the shadow is lighter and diffused even at the fingertip. A tap gathers it into a denser contact area with a soft, natural falloff farther away.
- [self] Brief taps transition into contact, held presses retain contact, and release returns smoothly to the diffused resting state.
- [self] Each built-in and custom hand uses its own outline and measured fingertip with the same resting and tapping behavior.
- [manual] The contact area follows the actual fingertip through rotation, movement, pointer-size changes and press/release.
- [snap] Review against light and dark backgrounds and representative hand styles. Avoid a uniformly blurred shadow that makes the contact point look detached.
- [self] The existing shadow toggle controls the revised shadow. Keep Size and Shadow under Appearance; retain the laser's separate visual behavior.

UX:
- Flow: Settings -> Appearance -> Pointer -> Shadow style -> Original or Contact. Selection applies immediately and persists. The existing shadow switch hides either style without losing the chosen style.
- Surface: inline native picker below the shadow switch. Size and Shadow stay in Appearance. No shadow-strength control.
- Words: Original retains the existing soft shadow. Contact rests soft and diffused, gathers beneath the fingertip during a tap, and softens again on release. The laser keeps its separate glow.
- Access: the picker exposes its label and selected value through Accessibility and supports keyboard selection. It is disabled while the shadow switch is off.
- Compatibility: Original remains the default and Reset All choice. Existing saved shadow visibility is preserved.

Austin approved adding the revised native prototype as a Settings option in this
thread on 10 November. The reference and native comparison are under
`design/s007-contact-shadow/`. Contact projects the actual hand silhouette, with
the sharp contact edge reserved for tapping and increasing penumbra at rest.
Rendering runs outside the main actor;
the displayed texture follows the current fingertip while the latest pose renders.

Status: done

Evidence: the Contact option, native rendering checks, light/dark Settings
snapshots, local tests and installed notarized build are recorded in
[VALIDATION.md](VALIDATION.md).

### S-008 Explain the laser click-sound option

As Austin, I understand what the laser sound switch changes.

Screens: Sound.

Acceptance:
- [snap] Replace or explain `Laser dot taps too` with plain wording, such as `Play click sounds with the laser pointer`.
- [manual] The explanation matches runtime behavior: the selected tap sound plays on laser clicks when enabled; the option defaults off for quiet pointing.
- [manual] Check the explanation against both Settings and toolbar sound controls so it accurately describes when sound is enabled.

Implementation notes: `OverlayController.soundOn` selects `laserSound` for the
laser and `handSound` for other pointers. Click handling calls the selected tap
sound. This is an audio option, not an extra click or a separate drawing mode.
The rest of Sound is accepted for now.

Status: todo

## Automation

### S-009 Control the app through AppleScript

As Austin, I run AppleScript commands to control the app and read its state.

Depends: S-001, S-003

Screens: Script Editor scripting dictionary, app mode and pointer state.

Acceptance:
- [manual] The installed app exposes discoverable AppleScript commands and properties in Script Editor, with working examples for Look Here Please.
- [self] The initial vocabulary covers pointer activation, Interact, pointer selection and drawing-tool selection, with state readback.
- [self] Script commands use the same validated application actions as the UI and existing local control protocol. Invalid selections and permission failures report useful errors.
- [manual] Changes from AppleScript appear in the app's controls; changes from the app can be read back by scripts.

Implementation notes: Austin requested AppleScript support but did not dictate
its complete vocabulary. The commands above are the proposed starting scope;
define the dictionary during this story's UX pass. Existing JSON CLI automation
is useful infrastructure, but is not itself native AppleScript support.

UX:
- Surface: the scripting dictionary, named Look Here Please Suite, with one example. No new windows.
- Vocabulary: read/write `pointer active`, `interact`, `selected pointer` and `drawing tool`; `pointers` elements with `id` and `name`; `toggle pointer` and `toggle interact`. See [AppleScript](applescript.md).
- Behavior: setting `drawing tool` turns Interact off, as the toolbar does. Setting `selected pointer` does not turn the pointer on.
- Errors: app rejections become script errors with the app's message and a number from 1000 to 1005.

Status: review. Austin still needs to open the dictionary in Script Editor and confirm script changes appear in the toolbar and menu.

Evidence: [VALIDATION.md](VALIDATION.md).

### S-010 Control the app from Stream Deck with state feedback

As Austin, I press Stream Deck keys to control the app and see which mode or
pointer is actually selected.

Depends: S-001, S-003

Screens: Stream Deck keys, action settings, corresponding app state.

Acceptance:
- [manual] Review the current SetDeck button experience before designing the plugin's key artwork and state behavior.
- [self] Initial actions cover pointer activation, Point/Draw and pointer selection; define the exact action catalog during the UX pass.
- [manual] A physical key press gives immediate feedback, a pending command has a distinct appearance, and success or failure follows the app's acknowledged result.
- [self] Persistent key feedback shows observed app state, including the current mode and selected pointer. It updates when those values change in the app or another automation client.
- [self] App stopped, unavailable state, permission failure and disconnected/reconnecting states remain distinguishable from Off or successful selection. Do not replay uncertain mutations automatically.
- [manual] Validate on Austin's physical Stream Deck for readable icons, press/release feedback, correct selected state and reconnect behavior. A protocol replay alone does not close hardware acceptance.

Reference project: `/Volumes/Project-Vault/PROJECTS/SetDeck`.
Start with [the approved button experience](../../SetDeck/docs/design/button-experience/README.md).
Its reusable rules are immediate press acknowledgment, a separate pending mark
and persistent state based on observation. This is a new plugin for Look Here
Please; SetDeck is the interaction reference.

Implementation notes: Reuse the existing validated app actions and
[control protocol](control-protocol.md) where suitable. Choose a readback or
subscription mechanism that keeps key state current. Native AppleScript and
Stream Deck are separate clients; neither has to depend on implementing the
other first.

UX:
- SetDeck review: adopted white symbols on black, a lavender border and check for observed state, a press border, a pending arc, an arrow receipt and distinct failure marks. Key art is rendered natively and reviewed as a state sheet.
- Catalog: Pointer On/Off, Interact and Select Pointer. Point/Draw is replaced by Interact, following S-003. Drawing-tool keys are not in this story.
- Readback: the plugin polls `status` every 0.5 seconds while keys are visible, and every 2 seconds while the app is unreachable. An acknowledged command updates the key from its own reply.
- States: see [Stream Deck](streamdeck.md). A key never launches the app or repeats a command.
- Select Pointer: the key inspector lists the app's pointers. Turn pointer on when selected defaults on.

Status: review. Physical Stream Deck checks remain: readable art, press/release feel, correct selected state and reconnect behavior.

Evidence: [VALIDATION.md](VALIDATION.md).

## Later

### S-011 Explore a motion responsiveness slider

As Austin, I may adjust how closely the pointer follows movement with a slider.

Screens: Appearance motion controls, live pointer movement.

Acceptance:
- [manual] Compare a proposed continuous control with the existing Original/Responsive choice before committing to an implementation.
- [manual] If pursued, demonstrate understandable endpoints and smooth changes without unstable motion.

Austin prefers the more responsive behavior. He suggested a slider as a
possibility for later, without requesting an immediate default change or
replacement of the current choices.

Status: todo

### S-012 Explore shared pointer defaults and individual customization

As Austin, I set shared pointer defaults and customize individual pointers when
their sound or appearance should differ.

Screens: Pointers, Appearance, Sound and pointer customization.

Design brief:
- Shared defaults establish baseline sound and appearance settings.
- Individual pointers can override those defaults. A metal hand and a squishy
  hand can use different tap sounds; the laser does not need a special exception
  in the general Sound page.
- Keep fine-tuning in Settings; quick controls can select a configured pointer.
- Define which appearance settings apply to each pointer type before coding.

UX proposal, to review:
- Flow: Settings -> pointer defaults or an individual pointer -> adjust a setting
  -> see or hear a preview -> Use Default restores inheritance for that setting.
- Surface: existing Settings pages with a focused area for pointer customization.
- Inheritance: each setting follows its default independently. Changing a sound
  does not detach size or shadow from their defaults.
- Words: Pointer Defaults, Use Default. Explain which values are customized.
- Sound controls: evaluate a master mute that preserves saved sound choices;
  this was the assistant's proposal, not a settled requirement.
- States and access: show inherited and customized values, support keyboard
  editing and sound preview, and expose each control's effective value.

This is a later design proposal. It does not replace the authorized S-001 through
S-004 work or authorize implementation now. Reconcile S-008's wording-only scope
when deciding whether to pursue the broader settings redesign.

Status: idea

### S-014 Explore pointer-specific click animations

As Austin, I may choose a click animation that fits a particular pointer.

Screens: pointer customization and the live pointer.

Design brief:
- Optional animations could give different hands appropriate click feedback.
- This is a separate exploratory idea, not a dependency of S-012 or S-013.
- Animation examples such as a soft hand compressing were assistant suggestions,
  not finalized artwork or requested behavior.
- If pursued, evaluate pointer alignment, reduced motion and responsive input
  before choosing assets or animation behavior.

Status: idea

## Historical integration acceptance

The sections below describe the previous integration and its original UX.
S-001 through S-010 take precedence for the next changes. The clarified
Interact toggle in S-003 supersedes all historical Point/Draw wording. Historical build and
test evidence remains in [VALIDATION.md](VALIDATION.md).

The selected features and their source IDs are listed in [INTEGRATION.md](INTEGRATION.md).

## Work normally with a visible pointer

Point forwards clicks, double-clicks, right-clicks, modifier clicks and drags. Draw requires permission, and mode changes keep press/release routing consistent.

UX:
- Flow: toolbar or menu chooses Point/Draw; Escape exits the pointer.
- Surface: inline toolbar mode control and matching menu state.
- States: Point remains available when drawing access is denied; permission repair opens the relevant system pane.
- Words: Point, Draw, Allow Drawing.
- Access: keyboard mode command; accessible mode labels and selected values.

## Annotate and correct an explanation

Pen, rectangle, arrow, text and numbers share color, width and opacity settings. Smoothing has four levels. Undo removes the last edit; clear removes the drawing. Number edits participate in history.

UX:
- Flow: choose Draw and a tool, draw or place an annotation, undo if necessary.
- Surface: a secondary toolbar tools row; text uses a small focused panel because its sole task is typing.
- States: Undo is disabled before an edit; Escape cancels text; visible drawing is unchanged on cancellation.
- Words: Pen, Rectangle, Arrow, Text, Number, Undo, Clear Drawing.
- Access: tool keys and Command-Z are scoped to Draw and pause during text entry.

## Capture and customize presentation controls

Screenshot copies and/or saves an image with annotations, without controls. The toolbar can hide or move. Shortcuts, appearance, pointer size and both motion methods are configurable.

UX:
- Flow: camera or shortcut captures, then shows success or an actionable error.
- Surface: toolbar action; capture destination is chosen from Settings.
- States: capture is disabled while pending; denied permission offers the right system settings pane; invalid folders produce a useful error.
- Words: Take Screenshot, Copy to Clipboard, Save Screenshots, Original, Responsive.
- Access: every icon has help; theme follows System unless explicitly overridden; motion is selectable without restarting.

## Drive the running app locally

Local JSON commands use the app's real commands and return acknowledged state. Settings batches validate before writing. State identifies the selected mode, tool and motion. The transport remains private to the same Mac user.

UX:
- Flow: a local client sends a request, the app applies it, the response reports state or an actionable error.
- Surface: existing app executable with `--ctl` and discoverable help.
- States: stopped app, invalid fields, missing permission and unavailable styles have explicit errors; no mutation is replayed automatically.
- Words: operation names and protocol version are documented in `docs/control-protocol.md`.
- Access: CLI and buttons call the same application behavior.
