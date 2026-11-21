# Look Here Please

All 18 app-review recommendations are implemented in local review version 1.2.0,
build 20261116015628, with matching Stream Deck plugin 1.1.0.0. Current behavior,
coverage and release notes are in project-status.md, VALIDATION.md and
release-notes-1.2.0.md. The earlier design plans below remain historical context.

The next product iteration is named **Look Here Please**. Follow the
[current backlog](STORIES.md) and [Austin's 10 November feedback](FEEDBACK-2026-11-10.md)
for new work. This brief describes the preceding integration.

Add Austin's selected macOS ideas to the native menu bar app so it supports normal Mac interaction, clear screen annotations and quick screenshot sharing. Keep the existing hand collection and let Austin refine the result after reviewing the build. Scope is in [INTEGRATION.md](INTEGRATION.md).


## Native Settings redesign, 18 November 2026

The approved icon-first Phase B1 is implemented in native Settings. The sidebar has
Pointers, Tools, Shortcuts, Presets and General.
Old section routes remain valid. Tools has Drawing, Magnification and Screenshots.
Every Shortcuts group is collapsible and starts closed; search and explicit
practice/conflict links reveal their destinations. Pointer customization and defaults share a library and inspector. Creation uses
a sheet, and independent overrides and recovery remain intact. About and Reset
All Settings are at the bottom of General.
Local verification and the isolated review build are recorded in VALIDATION.md.
The design plans below remain historical context.

## Design plan

- Archetype: menu bar utility, floating presentation toolbar, focused text panel and Settings window.
- Pages: Pointers, Tools, Shortcuts, Presets and General. Legacy Appearance and Sound routes open the Pointers Defaults inspector; About opens General.
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

Look Here Please is Austin Presley's playful native Mac pointer utility. Austin
selected C11 Cream with the S1 diagonal composition on 17 November 2026. The logo
uses the actual lavender hand, with cream, lavender and plum as the shared brand
palette. Canonical sources are `assets/AppIcon.icon` and `assets/brand.json`;
usage is documented in `design/s024/BRAND.md`. The README and project-page source
use the same identity and real pointer artwork. Published main receives curated
branding and presentation files only. TinyHand by Kamran Ahmed remains credited
as the MIT-licensed origin. No standalone website or public app release is claimed.
