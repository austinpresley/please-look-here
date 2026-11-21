# Radial Quick controls precedents

Research date: 2026-11-16. For the Look Here Please design reviewer. Primary-source desk research only. No app was launched or exercised. “Documented” means the developer, manual, source code, or original researchers describe the behavior. “Transfer” is a design inference for Quick controls, not a measured result.

## Findings to carry into review

- Preserve the direction of familiar commands. The original marking-menu research explicitly warns that dynamically changing item locations prevents users from progressing to remembered marks. Disabled commands can keep their slots. That last sentence is a transfer inference. [Kurtenbach and Buxton, 1994](https://billbuxton.com/MMUserLearn.html)
- Offer a visible, persistent click path alongside hold, move, and release. Blender, Procreate, and Mac utilities document both forms. Gesture skill should remain optional. See the individual sources below.
- Separate opening a branch, highlighting a leaf, and committing its action. A highlighted command should be identifiable before release. For Look Here Please, any live preview also needs a defined cancel result. This is a transfer inference from Kando and Loop, not a claim that either implements Quick controls' state model.
- Start review with roughly six to eight root choices and one child level. This is a hypothesis informed by the examples below, not a proven universal optimum. A fixed concentric child ring and a submenu that moves to the pointer are different interaction models.

## Kando

Documented. Point-and-click accepts a click anywhere within an item's angular wedge. Marking mode uses a held mouse button and directional movement; stopping or making a sharp turn selects the next step, and pausing reveals a submenu. Turbo mode supports continued navigation while a modifier remains held, then selects on release. Hover mode is separately enabled and the documentation warns of accidental selections without visual confirmation. [Usage](https://kando.menu/usage/)

Documented. Kando recommends eight items as a rule of thumb, a maximum of twelve, and fixed-angle locks for memorable directions. Its preference for deep hierarchies is product guidance, not a reported controlled-study result. [Menu layout guidance](https://kando.menu/creating-menus/)

Documented. Configuration distinguishes submenus opening at the pointer from an anchored mode that retains the initial opening position. It also documents a center region for parent selection or closing, separate click/drag detection, and the hovered item's name in the center. [Configuration](https://kando.menu/config-files/)

Transfer. Use generous directional hit areas and a readable current-command label. Choose the submenu coordinate model deliberately. Kando's zigzag navigation does not establish that every additional concentric ring is easy to select. Keep hover execution optional.

## Loop, native Mac window manager

Documented. Hold the trigger key and move the cursor toward a window action. A preview shows the resize result before commitment. Repeated clicks or key combinations can cycle through related placements. Radial-menu visibility and cursor interaction can be toggled independently. [Official repository and README](https://github.com/MrKai77/Loop)

Source-confirmed. The trigger's close callback runs on trigger release. With preview enabled, normal closure applies the selected window action; the source also contains a separate forced-close path. These are observations of the development branch at commit `e8560f458ad14c403c1629dfbe0b3bfdce0fa6a7`, not verification of an installed release. [Trigger callback](https://github.com/MrKai77/Loop/blob/e8560f458ad14c403c1629dfbe0b3bfdce0fa6a7/Loop/Core/Observers/KeybindTrigger.swift#L56-L60), [commit handling](https://github.com/MrKai77/Loop/blob/e8560f458ad14c403c1629dfbe0b3bfdce0fa6a7/Loop/Core/LoopManager.swift#L349-L373)

Transfer. Let highlight explain the pending result before release commits it. Cycling related variants may avoid another ring, provided the current variant stays visible. Preview/cancel behavior is a stronger precedent here than submenu navigation.

## Logitech Options+ Actions Ring

Documented. Eight primary bubbles can contain actions or folders. Pointer selection uses highlight and click. For an adjustable action such as volume, wheel/dial input changes its value; click-drag reveals a horizontal adjustment bar. Keyboard access includes Tab and Shift-Tab, Enter or Space to select, arrows in adjustment mode, and Escape to exit adjustment, return from a folder, or close the ring. Profiles can change mappings with the active app. [Official support article](https://support.logi.com/hc/en-my/articles/17844647906967-Logi-Options-Actions-Ring)

Transfer. Size or opacity could enter an explicit adjustment mode with a visible value. Give Back and Cancel recognizable behavior, and provide keyboard operation. Automatic app-specific remapping is less compelling for a presentation utility whose commands need stable locations.

Uncertainty. The FAQ's capacity wording is inconsistent: it mentions nine supplementary folder bubbles and elsewhere says up to eight actions per bubble. Do not derive a precise nested-capacity specification from it. The documented keyboard controls are stronger evidence than that wording.

## BetterTouchTool floating menus

Documented. Circular layout places items around the menu center. Menus can anchor to the pointer, screen, or window. Expandable menus offer press, slide onto an item, and release to trigger. [Floating-menu basics](https://docs.folivora.ai/docs/floating-menus/basics/)

Documented. A shortcut can toggle a menu, or show it on key-down and hide it on key-up. Hiding can optionally trigger the hovered item. Trackpad touch-release can also hide a menu. [Showing and hiding](https://docs.folivora.ai/docs/floating-menus/showing-hiding/)

Documented. Floating menus normally avoid keyboard focus until needed; item shortcuts can operate while visible without focus. This illustrates a real utility-window tradeoff between keyboard navigation and preserving the underlying app's input. [Keyboard shortcuts](https://docs.folivora.ai/docs/floating-menus/keyboard-shortcuts/)

Transfer. Specify focus and release behavior together. Circular placement alone is not evidence of full angular-wedge hit testing; the cited BTT pages do not establish that.

## Mac Pie Menu apps

Documented. Pie Menu offers two opening modes. One opens after shortcut release and can close via the shortcut again, Escape, or outside click. The other opens while held and triggers the pointed-to option on release. [Show options](https://www.pie-menu.com/help/show-options)

Documented. Pie Menu 2 opens a new pie menu when a submenu item is selected and supports recognizable SF Symbols or custom icons. The page does not establish continuous marking through those submenus or their back-navigation geometry. [Version 2 behavior](https://www.pie-menu.com/help/whats-new)

Documented. Pieoneer's developer describes hold/release and tap/click modes, full keyboard navigation, placement at the pointer or screen center, and separately disableable animations, sound, and haptics. Accessibility support is a developer claim, not independently tested here. [Developer's App Store description](https://apps.apple.com/us/app/pieoneer/id6739781207?mt=12)

Transfer. Treat persistent and held invocation as supported choices. Keep optional feedback independent of the menu's essential selection cues.

## Blender pie menus

Documented. Hold the invocation key, move toward an item, then release to select. Releasing without moving leaves the menu open for a click. A center disc indicates direction; selection becomes valid only when the pointer reaches or passes its boundary. The selected item highlights. Items support letter and number accelerators; a plus marks available sub-pies. [Blender 4.5 manual, Pie Menus](https://docs.blender.org/manual/en/4.5/interface/controls/buttons/menus.html#pie-menus)

Transfer. A visible neutral center can explain when a gesture is armed. “Release without movement leaves open” is a concrete alternative to “release in center cancels.” Choose one and teach it. Submenu indicators should distinguish branches before entry.

Access note. The web reader returned a fetch error. The canonical manual was read successfully through a read-only HTTP request, and its interaction text matched the [official manual source](https://projects.blender.org/blender/blender-manual/raw/branch/main/manual/interface/controls/buttons/menus.rst).

## Kurtenbach and Buxton marking-menu research

Documented. The 1993 hierarchical-menu paper uses the same directional movements for visible selection and remembered marks. Moving back to the center permits no selection or backing up. Increasing breadth and depth worsened performance, especially for off-axis paths. The experiment used twelve participants, mouse and pen input, and readily memorized compass/clock labels. [The limits of expert performance using hierarchic marking menus, InterCHI 1993](https://www.billbuxton.com/MMExpert.html)

Documented. The 1994 field study reports that experienced users still returned to visible menus to refresh their memory. It warns against dynamically changing item locations. It studied two users in a particular application; its speed results are not estimates for this Mac utility. [User learning and performance with marking menus, CHI 1994](https://billbuxton.com/MMUserLearn.html)

Transfer. Preserve the visible learning path even after adding expert gestures. Keep frequent actions in stable directions. Prefer a shallow initial design, then validate unfamiliar labels and trackpad input locally. Kando's enthusiasm for depth does not remove the research's breadth/depth tradeoff.

## Procreate QuickMenu

Documented. Six customizable radial buttons support persistent tap-then-tap selection or touch, drag toward a button, and release. Long-press on a button changes its assignment. The center button opens a profile picker; additional profiles provide different sets of six actions. The handbook describes directional familiarity developing into a flick. [Official QuickMenu handbook](https://help.procreate.com/procreate/handbook/interface-gestures/quickmenu)

Transfer. Use a compact set of frequently used actions with persistent positions. If more actions are required, an explicitly named profile or child set may be clearer than crowding the wheel. Keep customization distinct from ordinary selection. Six buttons are a product precedent, not proof that six is optimal for mouse input.

## Game weapon-wheel precedent

Documented. Ubisoft's Far Cry 6 accessibility article describes Holdless Mode and an individual hold/toggle choice for accessing the weapon wheel. It also documents menu navigation through either a free cursor or directional inputs. This is a publisher/developer primary source, with comments attributed to the game's lead designer. [Accessibility Spotlight: Far Cry 6, 2021](https://news.ubisoft.com/en-us/article/43Uvc8MM55rAsvq8JgaVXU/accessibility-spotlight-far-cry-6)

Transfer. Sustained holding should be optional even when the fast path uses it. Keyboard or directional navigation can supplement pointing.

Limit. This source supports input flexibility. It does not establish a weapon wheel's exact sector geometry, release-to-commit behavior, animation duration, or slowdown behavior. None of those are inferred here.

## Unresolved questions and timing evidence

- Moving submenu centers, fixed replacement menus, and simultaneous concentric rings are distinct designs. The sources do not establish a single best choice for Look Here Please.
- No reviewed study establishes an optimum root count, ring radius, child-entry threshold, screen-edge relocation policy, or hysteresis value for this utility and modern Mac trackpads. These remain local usability questions.
- Product documentation establishes intended behavior, not actual error rates, accessibility quality, or performance on Austin's Mac. Loop's cited source is pinned development code; several commercial help pages are unversioned.
- No animation durations were measured. Kando publishes configurable defaults of 150 ms fade-in and 200 ms fade-out and notes that some actions wait for fade-out. Those are documented settings, not measured end-to-end latency or recommendations for Quick controls. [Kando timing settings](https://kando.menu/config-files/)
- Do not quote numeric animation timings for Loop, Logitech, BTT, Pie Menu, Pieoneer, Procreate, or the game precedent from videos or visual impression. No verified numeric timing evidence for them is used in these notes.

Only this research note was written. Sources, tests, scripts, and project documentation were left unchanged; no builds, app launches, commits, uploads, or delegated agents were used.
