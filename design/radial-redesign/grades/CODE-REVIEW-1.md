# Code review 1

Reviewed the uncommitted diff and new source/tests against IMPLEMENTATION.md, ROUND2.md and prototype-v9.html. Excluded the specified artwork, research and prior research-state change.

1. **P0 — outside dismissal clicks can reach another app.** `Sources/TinyHand/OverlayController.swift:456`: launch in Point mode with Hold unassigned, then invoke the saved Open shortcut before opening status controls. `configureRadial` installs the tap only for a nonnil trigger, so this path opens a persistent panel without a tap. Outside clicks reach the underlying app and do not dismiss the panel. Fix: install and enable the shared tap as part of persistent opening, reject installation failure, and test this fresh-process path through InputTap rather than calling RadialInput directly.

2. **P1 — cached AX elements can execute a different command.** `Sources/TinyHand/RadialAccessibility.swift:23`: element actions capture only an array index. An AX client retaining root Undo across navigation into More can press index 6 and execute Pointer off. Retained elements also remain callable after cancellation and reopening. Fix: capture session generation, level and item ID; reject actions/focus from obsolete generations or levels, resolve the current ID, and clear the view's AX children on reset. Add a stale-element regression.

3. **P1 — annotation Command-Z/Shift-Command-Z routing is absent.** `Sources/TinyHand/RadialMenu.swift:12`: with persistent controls key, these chords fall through to AppKit; no responder implements annotation undo/redo. ClearRecovery also cannot become key at `ClearRecovery.swift:18`. The existing Edit menu cannot reach Ink's independent history. Fix: add scoped undo/redo responder actions for control/recovery focus and a keyboard focus path for recovery; preserve text-field undo and other applications' shortcuts. Test responder routing, not just AnnotationDocument.

4. **P1 — Screenshot resurrects controls and focus.** `Sources/TinyHand/OverlayController.swift:730`: capture requested while the browser/persistent panel is open merely hides it, then restores it, including key focus. A subsequent Return can select a pointer after capture. The contract requires closing controls and restoring only valid recovery. Fix: close radial/browser, drain owned pairs, retain exclusion IDs, and restore only revision-valid recovery. Update tests that currently require browser restoration.

Checked without additional findings: lock ordering/main-queue delivery, held cancellation and sampled-release guards, owned-pair drainage, VoiceOver chords, favorites/reset/archive migration and validation, display-change cancellation, observer cleanup, menu-bar activation policy and local-only workflows.

Local validation: 351 Swift tests in 47 suites, one Python test, 19 grid checks, swift build and git diff --check passed. No native input, live smoke, installed-app access, edits outside this report or commits.
