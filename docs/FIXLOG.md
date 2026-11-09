# Integration fixes

## Toolbar dragging and event-tap recovery

The native fixture check exposed delayed AppKit move notifications. Saving the cached origin immediately after `performDrag` could save an intermediate point. The toolbar now records final WindowServer geometry and subsequent move notifications. Drag persistence writes do not trigger a toolbar relayout. Resizing the tool row preserves the stored bottom origin, and Reset Position clears the preference and recenters the panel.

The same check exposed repeated event-tap enable calls inside disabled-by-user-input notifications. A local process sample showed `SLEventTapEnable` inside the event callback. Re-enabling is now conditional on the real enabled state; system-input pauses retry from the bounded UI service tick. The regression run completed with 128 input callbacks, including ten disabled notifications, rather than the earlier flood.

Rule: save completed window geometry after the system moves it, and never recursively re-enable a tap from its user-input-disabled notification.

## Shortcut reservations

The new configurable tool shortcuts could otherwise take Command-Shift-Z and collide with annotation Redo. Common editing shortcuts, Settings, Undo and Redo are reserved. Unit tests cover those reservations and the default presentation bindings.

Rule: validate configurable shortcuts against fixed commands as well as other configurable bindings.
