# Code review 5

Merge verdict: **request changes**. One P1; two non-blocking P2s; no P0.

## Standards

- **P1**, `Sources/TinyHand/RadialInput.swift:216`, `Sources/TinyHand/OverlayController.swift:493`: Persistent controls retain keyboard capture after Command-Tab. Highlight Clear, switch apps, then Return can execute Clear. No resign-key/deactivation cleanup exists. Fix: cancel unexpected focus loss without restoring focus, retain owned-pair drainage, preserve explicit handoffs, and reject queued activations after ownership loss. Add a focus-loss regression.
- **P2**, `Sources/TinyHand/RadialAccessibility.swift:53`: Import accepted favorites `["all","lavender","coral","plush","robot","laser"]`. AX pressing disabled missing `all`, slot 4, activates browser slot 3 through `firstIndex`. Fix: include the frozen slot in semantic identity and validate slot plus ID before press/focus; test reserved-ID collisions.

## Spec

- **P2**, `Sources/TinyHand/OverlayController.swift:552`: Clear then Pointer Off removes recovery without dismissal/edit, violating `IMPLEMENTATION.md:53` and breaking `scripts/snapshot-radial.py:251`. Fix: retain explicit termination dismissal, remove ordinary deactivation dismissal, and test recovery Undo after Off.

Both round-4 fixes work. Verified retained red source/logs: three regressions, five cases, 30 failed expectations; current assertions preserve those checks. Browser transfer/cancellation and active/inactive quit consume the original token once. All 178 manifest files match.

Clean: tap installation/drainage, stale AX generations/levels, repeated recovery transfers, scoped Undo, capture closure/exclusion, favorites persistence and legacy/archive validation.

Local validation passed: 375 tests/51 suites, Python contract, 20 grid checks, `swift build`, `git diff --check`. Input/AX findings confirmed with in-memory source probes; external focus is source-traced. Only this report written; no live-smoke, native posting, installed-app access or commits.
