# TinyHand fork integration

Add Austin's selected macOS ideas to the native menu bar app so it supports normal Mac interaction, clear screen annotations and quick screenshot sharing. Keep the existing hand collection and let Austin refine the result after reviewing the build. Scope is in [INTEGRATION.md](INTEGRATION.md).

## Design plan

- Archetype: menu bar utility, floating presentation toolbar, focused text panel and Settings window.
- Pages: General, Shortcuts, Drawing, Pointers, Appearance, Sound and About.
- Commands: pointer on/off; Point/Draw; tool selection; Undo; clear; screenshot; toolbar visibility; next/previous pinned pointer; automatic ink; sound; Settings; Quit. Each frequent action has a menu entry or native editing equivalent and a shortcut.
- Empty states: an empty drawing is transparent and Undo is disabled; capture failure explains the permission or destination problem; Point continues working without drawing permission.
- Feeling: easy to control while presenting. Controls reveal the current mode and selected tool without covering the explanation.
