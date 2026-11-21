# Look Here Please usability proposals

18 November 2026. Design proposals, with an interactive browser mockup. No native app source was changed for this work.

Open `look-here-please-before-and-after.html` to compare four flows. It is self-contained and works offline. Select Light or Dark to compare both appearances. `before-and-after-overview.png` collects all four proposals in one image. The other PNGs show individual comparisons at a larger size.

## What I would change first

1. Replace Interact with **Use apps / Draw** wherever the mode appears. Today's switch requires people to turn something off to start drawing. Keep pointer visibility separate. Show the seven tools and ink controls in Draw, with Undo, Redo and Clear disabled when there is no drawing history.
2. Put pointer selection and everyday adjustments in one window. Selecting a hand updates the preview and inspector. Avoid a repeated current-pointer summary and a separate Customize sheet for size, shadow and tap sound. Keep names on the hand tiles so distinct styles are easy to recognize and find.
3. Use one Favorites list. Stars add or remove favorites without changing the selected pointer. Keep up to eight toolbar favorites. Quick controls uses the first six and its existing All pointers destination. Changing the saved-list model requires a migration preview because today's toolbar pins and radial directions are separate preferences.
4. Let people learn in a small local practice window. Each step has one short instruction and a visible result. Ask for desktop permissions when the requested action needs them. Practice already exists in this app; the proposal makes it the first-use experience.

## Keep the text that prevents mistakes

Use icons for screenshot, magnification, sound, favorites, undo, redo, clear and overflow. Use short visible labels for Use apps / Draw, adjustment scope and the settings themselves. Tooltips explain icon actions, and accessibility names use the same terms. A native implementation should use SF Symbols and preserve menu and keyboard access.

The pointer inspector has one scope chooser, This pointer / Pointer defaults. Each overridden value has its own Use default arrow. Changing shared defaults preserves per-pointer overrides. App volume and motion remain app-wide in General. Keep hand gestures and artwork recovery available through disclosures and secondary commands.

## Evidence and limitations

- The controls before image was captured locally from the existing signed Review app in both appearances today, in a disposable preference suite. Both before and after show Draw with Arrow selected.
- The library and Customize before images are the native Settings captures from `dist/verification/settings-implementation/native`, taken today. The library image starts at the top of its scrollable page. The offline comparison lets you scroll the original capture.
- The welcome before is reconstructed from `Sources/TinyHand/WelcomeWindow.swift`, with the current lavender artwork. It includes the existing practice button. It is explicitly labeled as a reconstruction.
- The proposed library contains a sample of nine real hands. It does not demonstrate every built-in or custom pointer, missing-artwork state, backup flow or advanced setting. The full app should retain those capabilities.
- The browser prototype operates only its own state. Desktop capture, native permission prompts, audio playback, import and secondary Settings destinations show explanations rather than performing those actions.
- Local browser verification covers mode changes, shared favorites, search and no-results recovery, independent defaults and overrides, reset behavior, practice drawing and layouts at 360, 728 and 1440 pixels. Light and dark comparison captures were visually reviewed. This is not a user study or a native accessibility audit.

## Native implementation order

Start with the shared mode terminology and contextual tools. Then combine the pointer library and inspector. Design and review the Favorites migration before changing saved settings. Move practice into first use last, keeping a direct Show Pointer action and a way to skip practice.

Keep current shortcut assignments and automation operation names compatible. Rename the visible controls without breaking the control protocol. Preserve the current gesture, screenshot, undo and permission behavior while changing the layout.

## References

The app-specific findings come from the current local source and captures. General control guidance was checked against Apple's [buttons](https://developer.apple.com/design/human-interface-guidelines/buttons), [offering help](https://developer.apple.com/design/human-interface-guidelines/offering-help) and [sheets](https://developer.apple.com/design/human-interface-guidelines/sheets) guidance.

Palette follows `assets/brand.json`: lavender and purple accents over native-style neutral backgrounds, plum text, cream reserved for the identity. Real hand artwork provides the personality. The app UI uses the system typeface, a 4-point spacing grid, monochrome action icons and selected states that include more than color.
