# Pokey review, Opus 5.5 High second opinion

16 November 2026. Independent research note for Austin's question "what can we learn and take from this app?" about [Pokey](https://pokeyapp.com/). Read-only. No product changes, no backlog edits, nothing bought, downloaded or installed.

## Evidence limits

Everything about Pokey below comes from its own website, read on 16 November 2026. Nobody here has run Pokey. Treat every Pokey behavior as **advertised**, not observed. Claims about Look Here Please come from the local source on branch `feature/app-review-improvements-20261115` and cite exact files.

Pokey pages read:

- [Home and FAQ](https://pokeyapp.com/) (includes schema.org `SoftwareApplication` data giving version 2.6.0, price $4.99 and a feature list)
- [Guides index](https://pokeyapp.com/guides/)
- [Zoom guide](https://pokeyapp.com/guides/highlight-cursor-zoom-screen-share/), published 17 September 2026
- [Figma guide](https://pokeyapp.com/guides/highlight-cursor-figma-screen-share/), published 17 September 2026
- [Loom guide](https://pokeyapp.com/guides/highlight-cursor-loom-recording/), published 1 October 2026
- [Icebreaker guide](https://pokeyapp.com/guides/icebreaker-for-video-calls/), published 1 October 2026
- [Creator refund page](https://pokeyapp.com/reel/)

## What Pokey advertises

| Area | Pokey's claim | Source |
|---|---|---|
| Pointers | Four styles. Tiny hand, cat paw, "middle child" (a middle finger) and a classic arrow for formal calls. | Zoom guide, home page JSON-LD `featureList` |
| Adaptive expressiveness | "Five modes: from a subtle highlight to an expressive, in-your-face pointer," and "the faster you click, the wilder the poke." The guides call these five tap-expression levels that scale with click speed. | Home page, Zoom and Figma guides |
| Normal clicking | Only the look changes. Clicks, drags and selection reach apps as before. | Home page FAQ |
| Presentation Mode | Clicks tap the pointer and reach nothing underneath. Keyboard stays fully live. Toggled by ⌃⌥T. The FAQ calls ⌃⌥T "the one thing actually worth memorizing". | Home page FAQ, Figma guide |
| Shortcuts | ⌃⌥P toggles the pointer. JSON-LD lists "Custom keyboard shortcuts". | Zoom guide, JSON-LD |
| Sound | Every tap knocks. It plays as ordinary system audio, so call participants hear it only if the presenter shares system audio. Per-app steps are given for Zoom ("Share sound"), Google Meet ("Also share system audio", Chrome 142+) and the Loom desktop app ("Use System Audio"). Volume slider and off switch in the menu bar. | Home page FAQ, Zoom guide |
| Capture rule | Share or record the entire screen. Window capture leaves the pointer out. Every page repeats this. | All pages |
| Platform | macOS 26 or later. Developer ID signed and notarized. Multi-display. | Home page FAQ |
| Business | $4.99 once via Polar, 14-day refund, no trial. Refund for a public reel. | Home page, reel page |

Two site inconsistencies are worth knowing before anyone borrows the marketing. The home FAQ says a reel "with a mention and a link" earns a refund. The [reel page](https://pokeyapp.com/reel/) requires 10,000 organic views and a 30-day public post. The site also says the people pictured are AI-generated. Neither affects the app, but the first is the kind of promise mismatch that produces support email.

## What Look Here Please already has

Checked in source before recommending anything:

- **Normal clicking with a visible pointer.** Interact on forwards native clicks. The hand still presses and plays its tap sound on observed clicks (`Sources/TinyHand/OverlayController.swift:682-688`, `:706-712`). "Keep the hand visible while interacting" defaults on (`Sources/TinyHand/Preferences.swift:256-258`).
- **Click suppression.** Interact off consumes mouse presses at the event tap and routes them to drawing (`Sources/TinyHand/InputTap.swift:243-263`). The menu bar and visible toolbar stay pass-through (`Sources/TinyHand/OverlayController.swift:813-816`). Keyboard events are forwarded (`InputTap.swift:231-232`).
- **Tap expressiveness.** An optional wind-up and strike, `tapSwing`, from 0 to 2, default 0 (Off), disabled by Reduce Motion (`Sources/TinyHand/TapSwing.swift:24-28`, `Sources/TinyHand/Preferences.swift:220-222`, `Sources/TinyHand/PresentationSettings.swift:187-191`). It is a fixed amount. Nothing reads click cadence.
- **Sound.** Fifteen tap sounds (`Sources/TinyHand/TapSound.swift:4`), played through `AVAudioEngine` to the default output (`TapSound.swift:38-76`). That is the same system-audio path Pokey describes. App volume and master mute (`Sources/TinyHand/SoundOutput.swift:26-48`), Mute All Sounds in the menu bar (`Sources/TinyHand/MenuBarCommands.swift:37`), and per-pointer overrides from S-042.
- **Pointer range.** Enabled hands, Laser dot, Spotlight and Presentation pointer in one catalog, plus custom hands, search and filters (S-046).
- **Saved setups.** Named presets and portable backups (`Sources/TinyHand/PresetsSettings.swift:137`, S-051). I found no shipped starter presets.
- **Teaching.** A replayable practice window covering Pointer On, Interact, drawing and radial (`Sources/TinyHand/GettingStartedPractice.swift:25-38`).
- **Shortcuts.** All presentation and tool shortcuts start unassigned by design (`docs/project-status.md`, `docs/BRIEF.md`).
- **Things Pokey doesn't advertise at all.** Annotations with object edit and fading, magnifier, screenshot capture, radial controls, Stream Deck, AppleScript and a control protocol. Look Here Please is a much larger app. Pokey is a single trick done with a lot of polish in the copy.

## Ranked ideas

### 1. Add a "Point" tool so clicks tap without inking or clicking through

**New, high value, small.** This is Pokey's Presentation Mode, and Look Here Please is one tool away from it.

Today, Interact off with the Pen tool almost does this. A stationary click consumes the press, plays the tap and sound (`OverlayController.swift:504-523`), and creates no ink because a one-point pen stroke is not meaningful (`Sources/TinyHand/DrawingModel.swift:87-89`). The catch is that the pen appends a point after 1.5 pt of movement (`Sources/TinyHand/Ink.swift:101-102`). Any hand tremor during a tap leaves a tiny stroke on the presenter's screen. Control-click always drops a number marker (`OverlayController.swift:514`, `DrawingModel.swift:93`). So "point without touching the app" currently depends on holding the mouse perfectly still. Pokey's Figma guide names this exact failure, where tap-tap-tap pointing turns into accidental selection and drags.

Proposal: a `point` case in `DrawingTool` (`DrawingModel.swift:15`) that consumes the press, runs the tap animation and sound, and never creates an annotation regardless of drag distance. Ignore the Control-click number shortcut while it is selected.

Constraints and tradeoffs:

- S-052 set the rule that a new tool appears consistently in toolbar, radial, menus, automation and Stream Deck without changing existing key UUIDs. That makes this five touch points, not one.
- Drawing shortcuts the user assigned stay live in draw mode (`OverlayController.swift:99`). Pokey promises a "fully live" keyboard. That's true here for unassigned keys, so no change is needed, but the practice window copy should say it.
- Don't call it "Presentation Mode". See opinion A.

### 2. Teach the two screen-share failure modes inside the app

**New, highest value per hour.** Pokey's whole content strategy rests on two facts. Window capture omits overlays, and a tap sound reaches the call only when the presenter shares system audio. Every Pokey page repeats the whole-screen rule and calls it "the single most common reason a cursor tool appears not to work."

Both facts apply to Look Here Please. Its sound uses the default output (`TapSound.swift:38-76`), and its pointer is an overlay. The app never mentions either. A search of `Sources/TinyHand` for screen share, Zoom, Meet, Loom or OBS guidance finds nothing relevant.

Proposal: one short "Sharing your screen" step in the practice window and one line beside the Sound page status (`SoundOutput.swift:37-41`). Something like "Others hear taps only if you share computer sound. Share your entire screen, not a window."

Constraints:

- Verify locally before shipping any app-specific wording. Pokey's Zoom, Meet (Chrome 142+) and Loom checkbox names are Pokey's claims, not ours. Test each with Look Here Please on Austin's Mac and record results in `docs/VALIDATION.md`.
- Keep it to one step. The practice window is intentionally small (S-050).

### 3. Make tap emphasis respond to click rhythm, without adding latency

**New, medium value, needs a prototype.** Pokey's most distinctive claim is that faster clicking makes "wilder" pokes. Look Here Please has a fixed `tapSwing` amount and nothing that reads cadence (`TapSwing.swift:24`, `Sources/TinyHand/ArmView.swift:199`).

The local design has a trap here. The swing delays contact. `TapSwing.strike` is 0.22 s, and the tap sound waits for it (`TapSwing.swift:17-23`, `OverlayController.swift:706-712`). Scaling the wind-up with click speed would make rapid clicks feel laggy and let sounds trail behind the hand. That's the opposite of emphasis.

Proposal: derive a short-lived emphasis value from the interval between recent presses. Rapid presses should shorten the wind-up toward zero and put the extra energy into the strike overshoot, shadow gather and sound gain. Use a ceiling, a decay of about a second, Reduce Motion as a hard off, and keep it opt-in beside the existing Tap swing row.

Tradeoffs: more tuning than code. Test it in the existing appearance preview (S-047) before the overlay. Pokey's actual behavior is unknown, so copy the idea, not an imagined implementation.

### 4. Ship two or three read-only starter presets as "levels"

**Partly exists.** Pokey's five levels are a single dial users understand without opening Settings. Look Here Please spreads the same intent across size, shadow, tap swing, sound and pointer choice, and saved presets start empty.

Proposal: built-in presets such as Quiet (laser or Presentation pointer, no sound, no swing), Standard and Loud (hand, sound on, swing on, larger size). They'd use the S-051 machinery and appear above saved presets. Five is more granularity than the settings support. Three is enough.

Constraints: built-ins must be read-only and must not overwrite or rename user presets. Applying one keeps the existing Undo receipt (`PresetsSettings.swift:40`). Exposing them on Stream Deck is optional and would need new action UUIDs.

### 5. Say how to get back when clicks stop working

**Partly exists.** Pokey's FAQ singles out one thing to memorize, the shortcut that turns click suppression off. Look Here Please already avoids the trap better than Pokey does, because the menu bar and toolbar pass through in Interact off (`OverlayController.swift:813-816`). A first-time user with no assigned shortcuts may not know that. With the Point tool from idea 1 this matters more, because clicks would visibly do nothing.

Proposal: the first time Interact turns off in a session, show one toolbar message naming the way back ("Clicks draw now. Use the menu bar or your Interact shortcut to click apps again."). The toolbar message path already exists (`OverlayController.swift:832`). Don't assign a default shortcut.

### 6. Write a few use-case docs that answer real failures

**New, low effort, low urgency.** Pokey's guides are good. Each opens with a concrete scene ("a search party for a small grey arrow"), says what the competing built-in tool does well, explains the one rule that decides whether the pointer shows up, and ends with a "When is this the wrong call?" section. The Loom guide even advises turning the knock off for recordings.

Look Here Please has no product site and says so (`docs/index.html`). Short Markdown guides in `docs/` (sharing on calls, recording, pointing in Figma-like canvases without selecting) would still help Austin and any testers. They'd also be the source text for idea 2. Borrow the structure, especially the "wrong call" section. Don't copy Pokey's prose.

## What to skip

- **Default hotkeys** like ⌃⌥P and ⌃⌥T. They conflict with the project rule that shortcuts start unassigned, and S-039 put real work into conflict isolation.
- **A middle-finger pointer** and the "bad numbers" humor angle. Austin can make a custom hand if he wants one. It shouldn't ship as a built-in.
- **AI-generated people in marketing.** Pokey discloses it, but it still undercuts "real reaction" copy.
- **Reel-for-refund promotion, licensing and Polar checkout.** There is no public release to promote.
- **A macOS 26 floor.** Look Here Please targets macOS 13 (`Package.swift:6`). Nothing on Pokey's list needs a newer system.
- **Five levels.** Three starter presets cover the useful range (idea 4).

## Strong opinions the parent may miss

**A. Don't name the new behavior "Presentation Mode".** Look Here Please already uses "Presentation" for a pointer style in the catalog, for presentation shortcuts (`Sources/TinyHand/PresentationAction.swift:6`) and for a Settings page. A third meaning would make docs, menus and Stream Deck labels ambiguous. Make it a drawing tool named Point, with Interact off. That's how the app already models "clicks don't reach apps."

**B. The cheapest high-value lesson is copy, not code.** Pokey's app list is short, and most of its pages explain the whole-screen rule and the system-audio rule. Those two facts decide whether a pointer tool works on a call, and Look Here Please has the same two failure modes with no guidance. Idea 2 should land before idea 3, even though idea 3 is more fun.

**C. Speed-adaptive taps fight the existing tap swing.** Anyone porting "faster clicks, wilder poke" will reach for the `tapSwing` amount. That amount controls a wind-up that delays contact and sound by up to 0.22 s. Rapid clicking is exactly when users notice lag. Put emphasis into the strike, shadow and sound, and shorten the wind-up as cadence rises.

## Verification status

- Pokey site content was read in a T3 preview tab on 16 November 2026. App behavior was not observed.
- Local claims were checked by reading source at the cited lines. No build, test or UI run was needed for this note, and none was performed. Hosted CI stays disabled.
