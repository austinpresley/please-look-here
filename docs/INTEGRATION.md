# Selected fork integration

Austin selected these display ranks from the final 42-item audit on 9 November 2026. The rank and the stable research ID differ; this table is authoritative for this branch.

| Rank | Research ID | Acceptance |
| --- | --- | --- |
| 1 | C01 | Point mode forwards ordinary clicks, modifiers and drags. Draw is explicit. |
| 2 | C02 | Command-Z and an Undo action remove the last annotation. |
| 3 | C03 | Pen, rectangle, arrow and text tools work with the same drawing model. |
| 5 | C05 | A screenshot includes the hand and ink, excludes app controls, and supports copy/save. |
| 6 | C06 | Toolbar visibility is persistent; its position can be dragged, remembered and reset. |
| 7 | C07 | Number markers can be placed, moved and removed. |
| 8 | C08 | Stroke width and opacity are independent of hand size. |
| 14 | C13 | The running app exposes the validated local JSON control protocol. |
| 16 | C15 | Presentation actions have keyboard access, help and Settings controls. |
| 18 | C17 | Four line-smoothing choices preserve a responsive stroke endpoint. |
| 20 | C19 | Missing/revoked drawing permission leaves Point usable and offers recovery. |
| 21 | C20 | Each mouse press retains its route until release, including mode/activity changes. |
| 28 | C27 | Settings switches between Original and Responsive motion, with both grip-follow and scheduling behavior retained. |
| 32 | C31 | System, Light and Dark appearance and a smaller minimum pointer size work. |
| 34 | C33 | Settings groups and toolbar help expose the selected features coherently. |

The user confirmed that motion means how the hand follows the pointer, and requested a side-by-side choice over time. Original remains the initial selection. The alternate uses AiHand's larger adaptive grip-follow factors and display-linked aiming. No video, zoom, agent sessions, new artwork, localization or updater removal is selected.

Donor commits and source links are preserved in [the audit](research/tinyhand-fork-evidence.md). The integration adapts the useful behaviors into the existing native app rather than merging entire branded forks. Keep the original MIT notice. Number markers use the system font; no extra font asset is needed.

## Interaction decisions

- Point is the initial mode. The hand stays visible while native input passes through.
- Draw captures primary-button annotations. The existing held interaction modifier still temporarily forwards real input.
- A Number tool and Control-click in Draw place markers. Drag an existing marker to move it; click it to remove it. Control-click in Point remains native.
- Bare tool keys apply only in Draw while no app text editor, Settings window or shortcut recorder owns input. Command-Z is similarly scoped to annotations.
- Capture has a camera action and configurable shortcut. Right-click remains native in Point and is not assigned capture or exit.
- Text opens a small focused editor at the chosen point. Return adds the label; Escape cancels. Drawing input and bare shortcuts pause while it is open.
- Permission repair stays reachable even when the toolbar preference is off. Screen Recording is requested only on capture.
- A review build uses a separate bundle ID and install path, and contains no update feed, so it cannot replace or update the original installation.

## Verification

Run unit tests for annotation geometry/history, smoothing, marker manipulation, motion differences, mouse routing, preferences and control validation. Run local integration checks against the real app with isolated preferences. Inspect every changed Settings page in light and dark, the toolbar in Point and Draw, text entry, permission states and capture feedback. Record actual results in `docs/VALIDATION.md`; do not equate a compiled feature with a checked interaction.
