# Look Here Please

All 18 app-review recommendations are implemented in local review version 1.2.0,
build 20261116015628, with matching Stream Deck plugin 1.1.0.0. Current behavior,
coverage and release notes are in project-status.md, VALIDATION.md and
release-notes-1.2.0.md. The earlier design plans below remain historical context.

The next product iteration is named **Look Here Please**. Follow the
[current backlog](STORIES.md) and [Austin's 10 November feedback](FEEDBACK-2026-11-10.md)
for new work. This brief describes the preceding integration.

Add Austin's selected macOS ideas to the native menu bar app so it supports normal Mac interaction, clear screen annotations and quick screenshot sharing. Keep the existing hand collection and let Austin refine the result after reviewing the build. Scope is in [INTEGRATION.md](INTEGRATION.md).

## Design plan

- Archetype: menu bar utility, floating presentation toolbar, focused text panel and Settings window.
- Pages: General, Shortcuts, Drawing, Pointers, Appearance, Sound and About.
- Commands: pointer on/off; Point/Draw; tool selection; Undo; clear; screenshot; toolbar visibility; next/previous pinned pointer; automatic ink; sound; Settings; Quit. Each frequent action has a menu entry or native editing equivalent. Presentation and tool shortcuts are optional user assignments with no factory presets.
- Empty states: an empty drawing is transparent and Undo is disabled; capture failure explains the permission or destination problem; Point continues working without drawing permission.
- Feeling: easy to control while presenting. Controls reveal the current mode and selected tool without covering the explanation.

## S-023 menu bar control plan

Left click opens Menu Bar Controls. Right click or Control-click opens grouped
native commands. Pointer activation and Interact have separate native switches;
Choose Pointer lists every enabled available pointer. Drawing tools, history,
screenshot and current-pointer sound use the toolbar/radial symbols. Secondary
commands contain Pointer, Drawing and Presentation groups, Settings and Quit.
The compact panel stays open for repeated changes and closes for Settings or
capture. Its input lease spans native chooser/menu tracking and owned releases.
Empty history stays visible and disabled. All commands use ControlBridge and
all state comes back from the app. The intended feeling is quick and explicit.

## S-024 identity

Look Here Please is Austin Presley's playful native Mac pointer utility. Its
original pointing glove and attention dot use coral, cream and plum. Repository
presentation names enabled hands and Laser dot, annotations, radial and menu bar
controls, and Stream Deck automation as the local review direction. Published
main receives curated presentation files only. TinyHand by Kamran Ahmed remains
credited as the MIT-licensed origin. No owned website or public app release is
claimed.
