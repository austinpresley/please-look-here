# Local development

Run builds, tests and packaging locally on Austin's Mac. Keep hosted CI disabled.

This existing menu bar app uses SwiftPM and `scripts/build-app.sh`, not the new-mac-app template. Its render, Settings, toolbar, welcome and end-to-end entry points are in `Sources/TinyHand/main.swift`. Use isolated preferences for validation. Capture only this app's own windows or a dedicated test fixture.

When changing the selected fork integration, read `docs/INTEGRATION.md` for the rank-to-feature mapping and input-mode decisions. Record actual local verification in `docs/VALIDATION.md`.
