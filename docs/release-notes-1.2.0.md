# Look Here Please 1.2.0

Local review build 20261116015628. Matching Stream Deck plugin 1.1.0.0.

- Drawings and Undo stay with their display. Turning the pointer off hides them
  without clearing the session's history.
- Fading works consistently for lines, shapes, text and markers. Invisible
  markers no longer intercept new placements.
- Eraser removes one visible annotation. Highlighter adds broad translucent ink.
- Quick controls use a brief modifier hold, preserve ordinary chords and track
  each gesture independently. Shortcut conflicts leave unrelated commands usable.
- Custom hands can be removed and restored with their art, gestures, pins and
  pointer settings. Failed recovery cannot replace a valid hand library.
- Drawing and Appearance have local previews. The library adds search, combined
  filters, visible pin state and keyboard-accessible ordering.
- Pointer Defaults can be overridden independently for each pointer. Use Default
  restores inheritance for one value at a time.
- Next and Previous wrap through enabled pointers everywhere. Stream Deck offers
  forward and backward cycling while preserving existing key identities.
- Sound adds app volume, master mute and separate Preview controls. Preview does
  not select or enable a sound, and rapid mute changes cancel scheduled audio.
- Screenshot results offer Reveal in Finder and Copy. Region capture supports
  dragging and Escape cancellation; recovery actions match the actual error.
- Getting Started Practice teaches Pointer On, Interact, drawing and radial
  selection in a separate local window. Its shortcut links reveal and focus the
  correct control without recording or assigning keys.
- Named presentation presets and portable JSON backups preserve supported
  settings, custom hands and gesture art. Import previews reject conflicts and
  stale edits. Recovery and Undo survive restarting the app.
- Pointer thumbnails are cached. Isolated tests no longer emit thumbnails into
  the source folder. Source recovery copies are verified on a second volume.

Existing shortcuts, login behavior, capture destinations, Stream Deck profiles
and macOS grants are preserved. New shortcuts remain unassigned.

All tests, builds and packaging ran locally. Hosted CI remains disabled. Physical
multiple-display/mixed-scale, USB Stream Deck, Intel/older macOS and actual
sleep/lock checks remain outside this host's completed coverage. VoiceOver was
enabled for an app-tree check and restored Off; spoken output was not reliably
captured. Detailed evidence is in VALIDATION.md.

This is a private local review update, with no public app release or source push.
