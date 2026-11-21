# Look Here Please, easier: icon-first before and after

18 November 2026. These are design proposals only; no app source changed. Open `index.html` (it uses the `before/` and `hands/` folders) or the offline single file `look-here-please-easier-before-after.html`. Switch between Light and Dark at the top. Most mocks respond to clicks, and you can draw in the Tools preview.

Every "before" is a real capture of the current app. The toolbar captures are from Nov 9 and Nov 14, and the welcome capture is from Nov 10. Each caption gives its date.

## The idea

One tool row replaces the Interact switch. Cursor is the first tool and means "use apps". Picking any other tool means "draw". A separate hand switch shows or hides the pointer.

## Eight changes

1. **Menu bar:** a hand switch for pointer visibility, then favorite hands instead of a dropdown, the tool row, colors (Match pointer shows the hand), and icon-only actions. Undo, Redo and Clear stay visible with the cursor selected. When Accessibility access is missing, the menu shows an Allow banner, and the chosen tool is remembered with a dashed outline.
2. **Floating toolbar:** one row with Cursor and a current-tool picker. The middle shows hands when the cursor is selected and colors when a drawing tool is selected. That middle has a fixed width, so the other buttons never move.
3. **Pointers:** Pointers, Customize and Pointer defaults merge into one page with an inspector. A This/Defaults switch picks what you're editing, and each customized value has its own reset. A star adds a hand to favorites (up to 8, in toolbar order). The wheel keeps its own six directions, and starring never rearranges them. Open menus are shown as examples under the window.
4. **Tools:** labeled icon tabs and a practice box you can draw in (pen or arrow). Keep, Fade and Trail are chosen by stroke pictures. Width uses chips plus a 2–20 pt slider.
5. **Shortcuts:** a Suggested group fills only empty keys, skips conflicts, and shows the result with Undo. Below it is the full searchable list (26 commands), with keycaps.
6. **Presets & backup:** picture cards, a persistent Undo row, and open examples of backup contents, import review and recovery copies. Reset All Settings moves to General.
7. **First run:** a welcome with three pictures (Click, Draw, Set key for the wheel), plus practice by doing, with step icons.
8. **Quick controls:** a small change. The wheel center shows your hand, and a Cursor slice with a checkmark replaces "Interact ON".

## Review

Sol (Codex, xhigh) graded each round harshly. The scores were 58, 74, 83 and **89 (approve-with-notes)**. The reviews are in `review-sol-r1.md` through `review-sol-r4.md`, and earlier versions are kept in `r1/`, `r2/` and `r3/`.

## Notes for implementation (from round 4)

- **Pointer type artwork:** Laser, Spotlight and Presentation need their own artwork in the This tab and on the size row.
- **Practice preview:** the preview only illustrates behavior, so its timing doesn't reflect the smoothing and tail-speed settings yet.
- **Wheel direction:** the submenu still needs a design that shows the selected slot, what happens on a swap, and a pointer that is no longer available.
- **Toolbar help:** toolbar icons need hover help, and the toolbar should show whether the pointer's sound is muted or all app sound is muted.
- **Restore:** restoring a recovery copy needs a review step that says what gets replaced.
- **Not mocked:** some states weren't drawn but must be kept: the closed shortcut groups, Magnifier and Capture settings, capture in progress, a rejected tool selection, and extra first-run lessons.
- **Cursor rule:** Cursor always means "use apps", and picking it twice changes nothing. The Cursor ↔ last tool shortcut stays a separate toggle.
- **Compatibility:** keep the control-protocol operation names and the existing shortcut assignments.
