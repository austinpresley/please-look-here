# Architecture for the selected integration

## Annotation document and renderer [Strong]

The existing overlay coordinates input, presentation, drawing and polling, while SettingsView already exceeds 1,000 lines. Adding several independent fork versions directly would create competing state and gesture rules.

Use one value-based annotation document for shape geometry and history, one layer renderer, a per-button routing module, and a small motion strategy with two real implementations. Keep capture and local control behind their own types. The app controller owns composition and calls the same commands from toolbar, menu, keyboard and JSON.

Proof: pure geometry/history/routing tests, real control round trips, both motion methods exercised locally, and light/dark snapshots for the composed UI. This decomposition is part of Austin's authorized feature integration. It is not a separate behavior-preserving rewrite.

Keep the current asset loader, custom-hand creator, sound engine, updater implementation and pointer rendering. A whole-app migration or an agent-session subsystem is not needed for these selected features.
