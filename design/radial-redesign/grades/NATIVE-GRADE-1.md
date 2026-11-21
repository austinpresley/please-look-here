# Native v9 grade 1

16 November 2026. Uncommitted `feature/radial-quick-controls-v9`.

**85/100, B. Do not ship as-is. No demonstrated P0.** Scale: A 90+, B 80-89, C 70-79, D 60-69, F below 60; any P0 blocks.

| Criterion | /10 | Assessment |
| --- | ---: | --- |
| Visual craft | 9 | Composed 328-point disc; measured blocks remain contained. |
| Iconography and typography | 9 | Native symbols, readable type and distinct current checks. |
| Color and contrast | 9 | Correct light/dark selection pairs and opaque/contrast tokens. |
| Interaction model | 9 | Reanchoring, arming, disabled validation and input draining have model coverage. |
| Information architecture and copy | 9 | Stable maps, scoped labels and explicit pending consequences. |
| States and feedback | 7 | Revision-safe Clear and capture hiding; keyboard recovery/error feedback incomplete. |
| Motion | 9 | Stable hover layers; specified timings and Reduce Motion implemented. |
| Accessibility | 7 | Roles, labels, states and ownership exist; scrolling leaves stale AX geometry. |
| Pointer browser | 8 | Search/assignment work; long name clips. |
| Prototype fidelity | 9 | Broad native matrix; diagnostic witnesses clearly labelled. |
| **Overall** | **85** | **B** |

## Ranked defects and exact fixes

Paths use `Sources/TinyHand/`.

1. **P1:** `RadialMenu.swift:178` closes before reporting bridge rejection, retaining only diagnostics and an AX announcement. Show a persistent visible error with its reason and recovery action.
2. **P1:** `AppDelegate.swift:288`, `ClearRecovery.swift:18`: generic Undo/Redo selectors lack annotation responders; recovery cannot become key. Implement scoped annotation responders and keyboard access to recovery; restore prior focus. Preserve search-field text undo and external-app shortcuts.
3. **P1:** `RadialMenu.swift:79`, `RadialAccessibility.swift:43`: scrolling changes model offset without refreshing AX frames. Recompute semantic frames from actual table geometry after scrolling, including keyboard autoscroll; expose correct viewport visibility.
4. **P2:** `PointerBrowser.swift:106` truncates "Presentation pointer" in `browser-wide-light.png` and short/editor captures. Wrap overlong words by measured characters and provide enough label height without shrinking type.

## Evidence

Reviewed source/tests and supplied 351-test passing log; no reruns or native-input reproduction. 190 manifest images exist; 7,712 recorded radial corners pass sector/clearance checks. Inspected representative 1× pixels. No native 2× capture available.

## Unscored physical gates

VoiceOver speech; Full Keyboard Access/Voice Control; gestures/input routing and external-focus restoration; multiple displays/mixed scales; busy-background contrast; real capture files, exclusion and errors.

Only this report written. No app launch/input/commits.
