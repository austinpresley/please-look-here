# Fork upgrade architecture check

The current app is protected in checkpoint `8451227`. Read the existing architecture and fix log before this check. The active signal is OverlayController crossing 600 lines while adding capture, motion and system lifecycle behavior. The app remains in its established Swift 5 language mode and keeps its two executable targets.

## Live magnification owns capture and frame delivery, Strong

Files: OverlayController.swift, new Magnifier.swift and MagnifierCapture.swift.

Problem: adding stream startup, frame buffering, permission errors, display switching and cancellation directly to OverlayController would duplicate capture knowledge and make stale asynchronous callbacks hard to test.

Proposal: a magnifier module exposes update, suspend and status, hides one current capture session and a bounded latest-frame mailbox, and publishes a Core Animation layer. A real ScreenCaptureKit driver and a deterministic test driver exercise the same lifecycle interface. Pure layout owns coordinate conversion. Overlay supplies only presentation eligibility and the selected display/cursor.

Proof: layout tests cover negative origins, display bounds and mixed scales; driver tests cover delayed frames, stop/start and stale callbacks; native fixture checks verify permission and feedback exclusion. No screen-frame state is published through SettingsModel.

This is the top recommendation for the unattended milestone and is applied while adding the selected magnification feature. The independent audio driver already has production and blocked/failing test adapters; system notification ownership and trail geometry also have separate modules.

## Extract existing screenshot orchestration, Worth exploring

The existing screenshot implementation occupies about 85 lines of OverlayController. Moving its cancellation and output policy into a screenshot session could simplify that file later. It is deferred to avoid mixing a behavior-preserving capture refactor with ten authorized feature changes. Existing screenshot semantics and regression checks stay intact.

## Considered, not recommended

- Migrating the entire app to Swift 6 is unrelated to the selected changes.
- A new app target, generic event bus or second event tap would add coordination without solving a current problem.
- Splitting OverlayController into extensions solely to reduce line count would preserve its coupling while hiding it.
