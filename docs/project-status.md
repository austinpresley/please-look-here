# Look Here Please project status

Look Here Please is Austin Presley's native Mac pointer utility, based on
TinyHand by Kamran Ahmed. This presentation describes the combined local review
app. The default GitHub main branch still contains the earlier functional source.
The branding update publishes no app code, binary, hosted build or public release.

## Local review direction

The installed app is signed/notarized **1.2.0**, build `20261116015628`.
Matching Stream Deck plugin **1.1.0.0** is installed through the host's normal
confirmation. All 18 recommendations from the 15 November review are implemented
under [S-036 through S-053](app-review-implementation-2026-11-15.md), using Sol 6.1
High subagents with no Max setting. Pointer cycling wraps in both directions in
the app and Stream Deck. Changes are in [the release notes](release-notes-1.2.0.md).

Local validation passed 295 tests in 38 suites, five inspector JavaScript checks,
13 final native input checks and the active-window layout reports. The app and
matching plugin passed local signing, notarization and packaging verification.
All original normal preferences are exactly preserved, both grants remain allowed,
and all 39 Stream Deck profile files remain unchanged. Detailed evidence and
coverage limits are recorded in VALIDATION.md.

- Choose enabled hands or Laser dot. Toolbar pins are separate from enabled choices.
- Choose Spotlight or Presentation pointer through the same pointer catalog.
- Turn Interact on for native clicks and drags, or off for screen annotations.
- Open compact controls from the menu bar. Assign an optional modifier for radial
  controls at the cursor. Presentation and tool shortcuts start Unassigned.
- Use Stream Deck keys for the current pointer, pointer cycling and tool choices.
  Keys follow acknowledged app state. Profiles and existing key IDs are preserved.
- Keep the floating toolbar optional. Contact shadow rests softly and gathers at
  the fingertip during a tap.

## Review still required

The historical intermittent radial reopen cause remains unestablished. Twenty
consecutive fresh native openings passed without retries, alongside the corrected
session/chord regressions; bounded checks do not establish that historical cause.
Physical Stream Deck and host-inspector acceptance
for pointer/tool cycling remain open. Broader physical gesture, accessibility,
multiple-display and older-system coverage is still needed.

No owned website is configured. Use the
[owned repository](https://github.com/austinpresley/please-look-here) for status.
TinyHand's website and downloads belong to the upstream project.

## Local source recovery

The pre-change source bundle and untracked assets have a verified copy on the
Mac's internal volume under `~/Library/Application Support/Look Here Please/Backups/app-review-20261115`.
The previous installed app, normal preference export and custom hands are also
preserved there. This confirms a second-volume backup without publishing source.

Run `python3 scripts/backup-source.py` to make another verified local bundle,
working-tree patch and untracked-file archive. Its default destination is the
internal-volume Backups folder. It rejects a destination on the checkout's own
volume. Build output and user app data are not part of this source backup.

## Credits

Origin: [TinyHand by Kamran Ahmed](https://github.com/nilbuild/tinyhand).
The [original MIT license](../LICENSE) remains intact.
