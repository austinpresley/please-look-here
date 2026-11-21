# Native v9 grade 2

17 November 2026. `feature/radial-quick-controls-v9`, uncommitted. Review 1.2.0 (20261117000204).

**90/100, A. Ship the native design as-is. No demonstrated P0.** Scale: A 90+, B 80–89, C 70–79, D 60–69, F below 60; any P0 blocks.

| Criterion | /10 | Assessment |
| --- | ---: | --- |
| Visual craft | 9 | Composed 328-point disc. |
| Iconography and typography | 9 | Readable native symbols/type. |
| Color and contrast | 9 | Independent selection/current/focus signals. |
| Interaction model | 9 | Guarded entry; pair drainage. |
| Information architecture and copy | 9 | Stable maps; explicit consequences. |
| States and feedback | 9 | Persistent errors; revision-safe recovery. |
| Motion | 9 | Stable layers; specified timings. |
| Accessibility | 9 | Identity/frame/responder repairs verified. |
| Pointer browser | 9 | Names fit; editor reachable. |
| Prototype fidelity | 9 | V9 composition/behavior retained. |
| **Overall** | **90** | **A** |

## Prior findings

N1 = NATIVE-GRADE-1; C1 = CODE-REVIEW-1. `Sources/TinyHand/` paths.

| Finding | Disposition and verification |
| --- | --- |
| N1 P1 invisible errors | **Fixed.** `RadialMenu.swift:181`, `QuickCommandError.swift:95`: persistent reason/action; real bridge-rejection image and feedback regressions. |
| N1/C1 P1 keyboard recovery/annotation Undo | **Fixed.** `AnnotationResponder.swift:20`, `ClearRecovery.swift:158`: scoped equivalents, explicit recovery focus/return; responder tests and wheel/list focus images. |
| N1 P1 stale AX frames | **Fixed.** `RadialMenu.swift:81`, `QuickControlsList.swift:49`: actual clipped geometry/visibility; scroll regression and bottom-row images. |
| N1 P2 clipped names | **Fixed.** `PointerBrowser.swift:8`: measured hyphenation; wide/narrow/short images and name regressions. |
| C1 P0 click-through | **Fixed.** `InputTap.swift:34`: install/enable precedes opening; fresh unassigned-trigger and outside-pair regressions pass. |
| C1 P1 stale AX actions | **Fixed.** `RadialAccessibility.swift:41`: generation/level/ID validation; retained-element/reset regressions pass. |
| C1 P1 Screenshot restoration | **Fixed.** `OverlayController.swift:745`: closes controls/browser; capture-drain tests and exclusion witnesses agree. |

## Fresh sweep

No new P0/P1/P2 demonstrated; no fixes required. HUD styling/focus rings pass.

Fresh local run: **365 tests/50 suites**, Python contract and **20 grid checks** pass without warnings. Representative **206-state** images inspected; **7,712 corners** independently pass. **176 source hashes** and archive hash match.

## Unscored physical gates

- Real VoiceOver speech; Full Keyboard Access; Voice Control.
- Physical gestures and external-focus restoration.
- Multiple displays/mixed scales and actual 2× rendering.
- Real capture files/exclusion/errors and busy-background contrast.

No native input, normal-app/preferences/grant access or commits.
