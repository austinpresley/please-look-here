# Look Here Please 1.1.0

Build 20261114081700. All ten selected upgrades are included in the installed,
signed and notarized app.

The reliability changes are automatic: audio work stays off the UI thread and
recovers after device changes, lock/sleep/screensaver events turn the pointer off,
full-screen Spaces recover the overlay and toolbar, and a still pointer stops its
motion timer until input wakes it.

The new presentation effects are optional. Tap swing starts Off, magnification
starts off, and new shortcuts start Unassigned. Existing settings, hands, enabled
choices, pins and Stream Deck profiles are preserved.

## Where to find the additions

- **7. Trail ink:** Settings > Drawing > Fading > Trail. Adjust its delay and speed. Pen strokes erase from their start while Undo and Redo keep the complete drawing.
- **9. Magnification:** use the magnifying-glass button in the toolbar or menu bar controls. Move over the content you want to enlarge. Settings > Appearance controls zoom and lens size. A toggle shortcut can be assigned in Shortcuts.
- **10. Hand gestures:** Settings > Pointers has OK and Shaka starter poses for the selected hand. Import matching transparent artwork into either slot. Assign Hold Gesture 1 / 2 in Shortcuts, or choose a two-second preview from More Commands > Pointer > Hand Gestures. The selected pointer and its place in cycling stay unchanged.
- **12. Tap swing:** Settings > Appearance > Motion > Tap swing. This changes the tap, separately from Original/Responsive following. Drags land immediately and Reduce Motion suppresses the swing.
- **13. Custom hands:** Pointers > Make Your Own. The guide copies the creation prompt before opening ChatGPT and explains pasting, downloading a real transparent PNG, previewing and adding it.
- **14. More sounds:** Settings > Sound now has 15 choices, including the nine additions. Laser dot sound remains independent of hand sound.

## Verification

149 local tests and 12 layout checks passed. Native checks covered drawing and
history, idle wakeup, gesture key/modifier release and unavailable artwork,
magnifier capture and rapid cancellation, and real full-screen Space transitions.
The changed Settings pages and controls were reviewed in light and dark mode.
The exact ZIP passed signing, notarization, Gatekeeper and extracted-app checks.

Lock/sleep paths were tested with controlled signals rather than actually locking
or sleeping the unattended Mac. Physical multiple-display, Intel/older-macOS and
full VoiceOver coverage remain unperformed. The earlier radial reopen and physical
Stream Deck acceptance gaps remain recorded in the project validation notes.

Source is on the local `feature/fork-upgrades-20261114` branch. This is a private
review delivery; it does not publish an update feed or a public release.
