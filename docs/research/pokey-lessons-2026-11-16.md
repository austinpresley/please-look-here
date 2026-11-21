# What Look Here Please can take from Pokey

16 November 2026. Combined review by Sol 6.1 and the requested independent Opus 5.5 at High effort. Opus's full findings are in [its research note](pokey-opus-review-2026-11-16.md).

## Recommendation

Borrow Pokey's clear explanation of the job and its expressive clicks. Look Here Please already has a broader toolkit. The useful additions are a Point tool that leaves both the underlying app and the drawing untouched, practical screen-share guidance, a few starter presets, and an optional tap effect that responds to click rhythm.

Start with Point and the sharing instructions. Prototype adaptive taps after that. A short recording of the actual app would explain the product better than another feature list.

## Evidence and limits

We reviewed Pokey's first-party home page, FAQ, guides, promotion terms, published website HTML and demo poster. We did not run, buy or install Pokey. Its behavior below is advertised behavior, not a runtime finding. The independent Opus review used `claude-opus-5-5` with `effort: high`, confirmed by the task result.

Our comparison uses the current local expanded app, including the completed S-036 through S-053 milestone. The public main branch has older functional source. See [project status](../project-status.md). Product recommendations are proposals; no app code or backlog was changed.

## What to take, in order

### 1. Point without clicking through or drawing

Pokey advertises a presentation setting that swallows mouse clicks while the pointer taps and the keyboard keeps working. Its [Figma guide](https://pokeyapp.com/guides/highlight-cursor-figma-screen-share/) explains the benefit through a concrete problem: pointing at a design should not select or move its layers.

We already suppress clicks with Interact off, but route them to annotation tools. Pen records movement of at least 1.5 points, so a slightly shaky tap can leave a mark. Control-click overrides the selected tool with Number. Sources: [InputTap.swift](../../Sources/TinyHand/InputTap.swift), mouse routing around lines 243-279; [Ink.swift](../../Sources/TinyHand/Ink.swift), lines 99-104; [OverlayController.swift](../../Sources/TinyHand/OverlayController.swift), lines 504-530.

Add Point to the existing tool choices. With Interact off, it would animate taps and optional sound, consume clicks and drags, and never alter annotations. It must also bypass the Control-click number override. Existing ink and Undo history should remain intact.

Opus's strongest design correction was to make this a tool rather than another mode. We already use Presentation for a pointer style. Keep Interact as the way to choose whether input reaches the underlying app. Add Point consistently to the toolbar, radial controls, menus, automation and Stream Deck, preserving existing action IDs. Any shortcut starts unassigned.

The menu bar already remains reachable during suppressed input. Teach that route back when a user first turns Interact off. Source: [OverlayController.swift](../../Sources/TinyHand/OverlayController.swift), lines 811-816. A clear way back matters especially when the new tool creates no ink to explain what happened.

### 2. Explain what the audience can see and hear

Pokey repeatedly explains capture scope and computer audio in its [Zoom guide](https://pokeyapp.com/guides/highlight-cursor-zoom-screen-share/) and [Loom guide](https://pokeyapp.com/guides/highlight-cursor-loom-recording/). Its [Figma guide](https://pokeyapp.com/guides/highlight-cursor-figma-screen-share/) also distinguishes watching a screen share from following a collaborator cursor inside a shared file. These are good questions to answer before users assume the pointer is broken.

Our practice currently teaches pointer activation, Interact, drawing and radial controls, without teaching capture scope or how tap audio reaches viewers. Source: [GettingStartedPractice.swift](../../Sources/TinyHand/GettingStartedPractice.swift), lines 25-39. Our sounds use AVAudioEngine output, with existing volume and mute controls. Sources: [TapSound.swift](../../Sources/TinyHand/TapSound.swift), lines 38-66; [SoundOutput.swift](../../Sources/TinyHand/SoundOutput.swift).

Add a brief sharing lesson and a Sound-page explanation. Tell users to choose capture that includes the overlay, normally the whole display, and enable computer-audio capture when taps should be audible. Explain that an overlay does not replace another application's multiplayer cursors. Use a short test recording to verify both picture and sound. Confirm actual Zoom, Meet, Loom and OBS behavior locally before publishing checkbox names or a compatibility table. Do not promise every capture method works.

### 3. Offer a few starter presets

Pokey frames expression as a few understandable levels. Look Here Please already saves complete named pointer, drawing and sound setups, but its preset page starts empty. Source: [PresetsSettings.swift](../../Sources/TinyHand/PresetsSettings.swift), lines 131-169. Our existing Tap swing control is a numeric slider. Source: [PresentationSettings.swift](../../Sources/TinyHand/PresentationSettings.swift), lines 187-192.

Add read-only starters such as Quiet, Teaching and Playful, using the existing preset machinery. Quiet could use a laser with sound and swing off. Teaching could use an easy-to-follow hand with restrained motion. Playful could use more swing. These are proposed starting points, not Pokey's exact settings.

Preserve user presets and their Undo behavior. Applying a starter should keep the current activation, Interact setting and shortcut assignments, as presets already do. Avoid another set of controls named modes. Five levels are not a requirement.

### 4. Prototype tap emphasis that follows click rhythm

Pokey advertises stronger pokes when clicking speeds up. This is the clearest new animation idea in its [home page](https://pokeyapp.com/) and [Zoom guide](https://pokeyapp.com/guides/highlight-cursor-zoom-screen-share/).

Our tap already has a wind-up, strike and release. Its amplitude comes from a fixed preference, with no click-rate input. The strike time is 0.22 seconds, and tap sound waits for visual contact. Sources: [TapSwing.swift](../../Sources/TinyHand/TapSwing.swift), lines 16-28; [ArmView.swift](../../Sources/TinyHand/ArmView.swift), lines 197-201; [OverlayController.swift](../../Sources/TinyHand/OverlayController.swift), lines 706-712.

Prototype a bounded, short-lived emphasis value based on recent press intervals in the existing appearance preview. Let it settle after a pause. Faster clicks should shorten the wind-up and put extra motion into the strike and contact shadow. Preserve immediate drag contact, correct input delivery and Reduce Motion behavior. Keep it opt-in and preserve existing saved settings.

Opus proposed varying sound gain as well. I would keep the first version visual. Automatic volume changes complicate the existing volume promise, and louder repeated taps can distract during a recording. The [Loom guide](https://pokeyapp.com/guides/highlight-cursor-loom-recording/) itself recommends restrained or silent taps for longer recordings.

### 5. Demonstrate one audience problem at a time

Pokey leads with an audience outcome, includes a quick-demo entry point and publishes specific [guides](https://pokeyapp.com/guides/) for calls, recordings and design reviews. Its published hero script also draws a pointer that follows the mouse over parts of the landing page. That script was inspected, not successfully exercised in the parent browser.

Our [current page](../index.html) correctly presents local project status and lists capabilities. When the app is ready for public presentation, lead with a real recording that shows a hard-to-follow explanation becoming easy to follow. Then demonstrate Point, annotation and quick control as separate short moments. The main lesson is an understandable first demonstration.

Write a few task-focused guides using our own verified steps and recordings. The useful structure is a specific failure, a short fix and the limitations. Retain a restrained example for formal calls. We already have quiet visual choices; a larger pointer catalog is not needed to learn this lesson.

### 6. Consider phone-to-Mac handoff at launch

Pokey gives mobile visitors a way to send themselves the Mac link. That addresses a practical problem for a desktop utility discovered on a phone. The mechanism and single-email promise are described in its [privacy policy](https://pokeyapp.com/privacy/).

This is a later launch idea. A share or copy-link action may be sufficient initially. Look Here Please currently has no public app release or verified product website. There is no reason to build checkout, licensing or email infrastructure for this research task.

## What already exists

Menu bar activation, optional shortcuts, native clicking with a visible hand, tap sounds with mute and volume, multiple pointer styles, local previews and saved presets are existing capabilities, not new Pokey discoveries. Look Here Please also has annotations, magnification, screenshot capture, radial controls and Stream Deck support. Sources: [project status](../project-status.md), [review milestone](../app-review-implementation-2026-11-15.md), and the local source references above.

## What to skip

- Pokey's default shortcuts. Our shortcuts intentionally start unassigned.
- A new feature called Presentation Mode. Point fits the current input model more clearly.
- Five expression levels simply because Pokey has five. Start with a few clear presets.
- AI-generated audience faces as apparent social proof. Pokey discloses its generated people on the home page. Use real app recordings and permissioned feedback.
- Its refund-for-reels campaign. The [home FAQ](https://pokeyapp.com/) summarizes the offer more broadly than the [promotion terms](https://pokeyapp.com/reel/), which require 10,000 organic views and a public post for 30 days. Keep any future offer's headline and conditions consistent.
- Copying its artwork, wording, pricing or operating-system minimum. None follows from the product lessons.

## Suggested next decision

Choose Point and sharing guidance as the next small product improvement. Add starter presets after that. Adaptive emphasis deserves a short preview prototype before committing to production behavior. Prepare the real demo alongside those changes, then consider launch-specific work once a public release is planned.

This review added research documents only. No tests, builds, installs or hosted CI were run.
