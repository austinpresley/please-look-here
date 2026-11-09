# Native app structure

TinyHand is one SwiftPM executable with AppKit windows, SwiftUI Settings and Core Animation pointer rendering. Its deployment target is macOS 13. This existing app remains in Swift 5 language mode under the installed Swift compiler.

The integration separates annotation geometry/history, its layer rendering, per-button event routing, screenshot capture, pointer motion and the local control transport. UI composition stays in the application and overlay controllers. Settings changes publish one native preferences notification. The input tap runs on its own thread; UI work returns to the main queue.

See [the integration scope](docs/INTEGRATION.md) and [the architecture review](docs/architecture-review-2026-11-09.md). Local verification commands and measured results live in `docs/VALIDATION.md`.
