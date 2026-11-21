# App terms

| Term | Meaning |
| --- | --- |
| Pointer | The visible hand, Laser dot, Spotlight or Presentation pointer that follows the cursor. |
| Magnification | An optional circular live view that enlarges the desktop beneath the cursor. Its marker shows the actual click location. |
| Whole line | Fade a completed annotation as a whole after the saved delay. |
| Trail | Erase a pen stroke from its start at a chosen speed, while keeping its complete geometry in annotation history. |
| Tap swing | Optional wind-up and strike of a hand during a tap, independent of pointer-follow behavior. |
| Hand gesture | Temporary artwork for the selected hand. Two slots start with OK and Shaka and can be customized per hand. |
| Hold Gesture 1 / Hold Gesture 2 | Optional shortcuts that show a pose while held and restore the normal hand on release or context cancellation. |
| Spotlight | A clear, softly edged circle around the cursor with the rest of the current display dimmed. Pointer size sets its radius. |
| Presentation pointer | A silver telescoping rod with a dark grip and coral tip at the cursor. Pointer size sets its thickness. |
| Shadow style | The hand shadow choice in Pointer defaults, independent of its visibility switch. |
| Contact | The shadow style anchored to the fingertip, with softer falloff as the hand and rod lift away. |
| Original shadow | The existing soft drop shadow, retained as the initial shadow style. |
| Pointer Defaults | Shared sound and appearance values inherited independently by pointers. |
| Use Default | Restore one pointer setting to its shared default without changing other overrides. |
| Customized | The pointer has an explicit override for this particular setting. |
| App Sound | App output volume and master mute, applied to pointer taps and sound previews. |
| Mute all sounds | Silence app output while preserving pointer sound choices and enabled flags. |
| Sound Preview | Hear a sound at the app volume without selecting it or enabling tap sound. |
| Display document | One running-session annotation document and Undo/Redo history for a stable display identity. |
| Annotation lifetime | Visibility timing kept separately from full annotation geometry and history. |
| Eraser | Remove one visible annotation per completed gesture. Undo restores it. |
| Highlighter | A broad translucent freehand annotation using the current drawing controls. |
| Remove Hand | Recoverable removal of a custom hand, its artwork, gesture slots and saved settings. |
| Undo Remove | Restore a removed hand and its saved settings from its retained recovery package. |
| Practice drawing | A disposable local canvas with independent ink and history. |
| Pointer preview | A local sample of the selected pointer using its effective appearance values. |
| Getting Started Practice | A replayable local window teaching pointer visibility, Cursor, drawing and quick controls. |
| Replay Step | Reset the current practice exercise without changing the desktop. |
| Presentation preset | A named pointer, ink and sound setup that leaves activation, Cursor or drawing mode and protected settings unchanged. |
| Portable backup | A bounded versioned JSON export of supported settings, presets, hands and gesture artwork. |
| Undo Last Change | Recover the latest unresolved preset or backup transaction, refusing conflicting later edits. |
| Cycle direction | Forward chooses the next enabled available pointer; Backward chooses the previous. Both wrap. |
| Toolbar pin actions | A native menu with Move Left, Move Right and Unpin from Toolbar for one favorite. |
| Radial menu / Quick controls | Eight fixed root directions at the cursor. Hold an assigned bare modifier and release to choose, or use Open Quick controls for a persistent keyboard/click session. Small displays use the same commands in a scrolling list. |
| Look Here Please | Austin Presley's native Mac pointer utility. Exact product name. |
| Attention dot | The dot the original pointing glove reaches toward in the app identity. Filled in the active menu bar symbol, hollow when off. |
| Cursor | The first tool. Sends clicks and drags to apps. Selecting it again keeps Cursor selected. Pointer visibility is separate. |
| Cursor ↔ last tool | The existing mode shortcut toggles Cursor and the last drawing tool. Its command ID remains `mode`; protocol `interact` and AppleScript terms stay compatible. |
| Keep the hand visible while interacting | When on, the hand remains visible during native clicks and drags. When off, hide until all mouse buttons release. |
| Pen | A freehand stroke. |
| Rectangle | An outlined rectangular annotation. |
| Arrow | A straight directional annotation. |
| Text | A typed annotation placed on screen. |
| Number | A movable numbered marker. |
| Screenshot | A still capture of the current display with pointer and annotations. |
| Screenshot result | A temporary panel with Reveal in Finder, Copy and Close actions for the most recent completed capture. |
| Capture Region | Select a rectangular part of the current display by dragging. Escape cancels without taking a screenshot. |
| Original | The existing grip-follow motion and adaptive timer. |
| Responsive | Faster adaptive grip follow with display-linked aiming. |
| Unassigned | A command with no saved shortcut and no global key registration. |
| Clear shortcut | Remove a command's shortcut assignment without restoring a preset. |
| Undo Annotation / Redo Annotation | Optional presentation commands for drawing history, separate from native text editing. |
| Show toolbar | Allow the floating toolbar to reveal briefly at pointer startup or when enabled, and while the cursor is nearby. Off keeps it hidden. |
| Enabled pointer | A pointer allowed in quick selection. Enabling preserves separate toolbar pins. |
| Available pointer | A library choice whose image loads, or a native Laser dot, Spotlight or Presentation pointer. Availability is separate from Enabled. |
| Pointer library | All built-in hands, custom manifest entries and native pointers, including disabled or unavailable choices. |
| Toolbar pin | A saved toolbar favorite and its order. A disabled or unavailable favorite keeps its pin but is omitted from the live toolbar. |
| Image unavailable | A hand image is missing or unreadable. Restore the image or choose another pointer. |
| Current pointer | The pointer selected in Look Here Please, read from acknowledged app state. Pointer On/Off uses this selection without replacing it. |
| Pointer On/Off | The Stream Deck action that toggles activation of the current pointer. Its key shows the observed hand or laser with On/Off. |
| Choose Pointer | The Stream Deck action that cycles every enabled, available pointer in app library order and wraps, preserving activation and Cursor or drawing mode. |
| Select Pointer | The separate Stream Deck action that selects one saved fixed pointer, optionally activating it. Existing keys retain their UUID and settings. |
| Next enabled pointer | The next available choice in the enabled library order, including unpinned and custom choices. |
| Choose Tool | Stream Deck action whose per-key Tool choice cycles tools or selects a fixed tool. Cycle keys show the acknowledged current tool; fixed keys show their assigned tool and a ready check only for a matching observation. |
| Cycle tools | Advance Pen, Rectangle, Arrow, Text, Number, Eraser, Highlighter, then wrap to Pen. The app owns the current position. |
| Tool choice | Per-key saved cycle or fixed drawing-tool destination in the Stream Deck inspector. |
| Ready tool | The observed tool is usable with the pointer on, Interact off, Accessibility allowed and no capture in progress. |
| Install Stream Deck Plugin… | Open this app's bundled matching installer in Stream Deck for host confirmation. Opening does not establish installation. |
| Bundled plugin | The signed/notarized Stream Deck installer included in this signed app, identified by version and SHA-256. |
| Radial menu modifier | Optional bare Option, Control, Shift or Command assigned in Shortcuts. Unassigned by default and after Reset. It never changes Interact by itself. |
| Selection dot | High-contrast marker at the real cursor/fingertip. It stays above radial button artwork. |
| Center arming | When clamping moves the center more than 8 pt, visit its 52 pt neutral region before choosing. The dashed cue ends at the hub rim. The real cursor never moves automatically. |
| Back | A child sector pointing toward its parent. Returning through Back requires visiting the parent center before choosing again. A sufficiently separate parent center can also be entered directly. |
| Re-anchoring | Held navigation through a group at 112 pt places its child center at that real pointer position, clamped to the invocation display. |
| Quick controls favourites | Six saved pointer identities, in North, Northeast, East, Southeast, Southwest, West order. Disabled or missing identities keep their positions. Assigning an existing favourite swaps the two slots. Toolbar pins are separate. |
| Pointer browser | A separate searchable native window opened by All pointers. Quick controls scope follows saved slot order. In editing mode, grid activation sets a candidate and Use assigns it without changing the live pointer. |
| Clear recovery | Persistent Drawing cleared snackbar. Appearance keeps prior focus. Command-Shift-U focuses it from Quick controls or the Edit menu. Undo restores the exact Clear checkpoint until the next document edit, undo, redo or dismissal. Scoped Command-Z/Shift-Command-Z work while controls own focus and in Draw; external Interact apps keep their own undo. |
| Quick controls error | Persistent nonactivating failure panel with the rejected command's reason, a recovery action and Dismiss. Each distinct visible failure is announced once. |
| Menu bar controls | Compact native popover opened by clicking the status item. Pointer On/Off and Interact are independent switches; Choose Pointer includes all enabled available pointers. |
| More Commands | Grouped native Pointer, Drawing and Presentation commands, followed by Settings and Quit. Also opens on right-click or Control-click of the status item. |

| Pointer defaults | The Defaults scope in the Pointers inspector. Shared size, shadow and tap values. Its preview is a Sample. |
| Favorite | A toolbar pin, represented by a star. One to eight, in toolbar order. Changing stars or order never changes Quick controls directions. |
| This | Inspector scope for the selected library pointer. Each override inherits independently and has its own reset. |
| Every pointer | App volume, mute and motion below the Pointers inspector. These apply in both editing scopes. |
| Tools settings | Drawing, Magnification and Screenshots panes within Settings. Local practice does not change the desktop tool. |
| Shortcut section | A native disclosure group that starts closed on each normal visit. Search and explicit links may open it. |
