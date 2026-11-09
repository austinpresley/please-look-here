# Integration acceptance

The selected features and their source IDs are listed in [INTEGRATION.md](INTEGRATION.md).

## Work normally with a visible pointer

Point forwards clicks, double-clicks, right-clicks, modifier clicks and drags. Draw requires permission, and mode changes keep press/release routing consistent.

UX:
- Flow: toolbar or menu chooses Point/Draw; Escape exits the pointer.
- Surface: inline toolbar mode control and matching menu state.
- States: Point remains available when drawing access is denied; permission repair opens the relevant system pane.
- Words: Point, Draw, Allow Drawing.
- Access: keyboard mode command; accessible mode labels and selected values.

## Annotate and correct an explanation

Pen, rectangle, arrow, text and numbers share color, width and opacity settings. Smoothing has four levels. Undo removes the last edit; clear removes the drawing. Number edits participate in history.

UX:
- Flow: choose Draw and a tool, draw or place an annotation, undo if necessary.
- Surface: a secondary toolbar tools row; text uses a small focused panel because its sole task is typing.
- States: Undo is disabled before an edit; Escape cancels text; visible drawing is unchanged on cancellation.
- Words: Pen, Rectangle, Arrow, Text, Number, Undo, Clear Drawing.
- Access: tool keys and Command-Z are scoped to Draw and pause during text entry.

## Capture and customize presentation controls

Screenshot copies and/or saves an image with annotations, without controls. The toolbar can hide or move. Shortcuts, appearance, pointer size and both motion methods are configurable.

UX:
- Flow: camera or shortcut captures, then shows success or an actionable error.
- Surface: toolbar action; capture destination is chosen from Settings.
- States: capture is disabled while pending; denied permission offers the right system settings pane; invalid folders produce a useful error.
- Words: Take Screenshot, Copy to Clipboard, Save Screenshots, Original, Responsive.
- Access: every icon has help; theme follows System unless explicitly overridden; motion is selectable without restarting.

## Drive the running app locally

Local JSON commands use the app's real commands and return acknowledged state. Settings batches validate before writing. State identifies the selected mode, tool and motion. The transport remains private to the same Mac user.

UX:
- Flow: a local client sends a request, the app applies it, the response reports state or an actionable error.
- Surface: existing app executable with `--ctl` and discoverable help.
- States: stopped app, invalid fields, missing permission and unavailable styles have explicit errors; no mutation is replayed automatically.
- Words: operation names and protocol version are documented in `docs/control-protocol.md`.
- Access: CLI and buttons call the same application behavior.
