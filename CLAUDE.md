# Local development

Run builds, tests and packaging locally on Austin's Mac. Keep hosted CI disabled.

This existing menu bar app uses SwiftPM. Build the isolated review app with `scripts/build-review.sh`; run `scripts/run-tests.sh` for local checks. Use `scripts/snapshot-settings.py` against a focused running test instance for UI verification. The older standalone snapshot flags do not establish active-window appearance. Capture only this app's own windows or the dedicated public fixture.

For local automation, use the bundled executable's `--help` and read `docs/control-protocol.md`. Run `scripts/live-smoke.py` only while the disposable `TinyHandFixture` is visible; it posts native input over that fixture.

When changing the selected fork integration, read `docs/INTEGRATION.md` for the rank-to-feature mapping and input-mode decisions. Record actual local verification in `docs/VALIDATION.md`.
