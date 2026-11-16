# App review milestone architecture check

Surveyed CLAUDE.md, ARCHITECTURE.md, FIXLOG.md, the current source, recent file
history and the completed source-review findings. The app keeps its two SwiftPM
executable targets, Swift 5 language mode and macOS 13 deployment target. There
is no ADR directory and no new decision requires an ADR for this milestone.

## Capture orchestration, Worth exploring

Files: OverlayController.swift, 876 lines; ScreenCapture.swift;
ScreenshotSelection.swift; ScreenshotResult.swift.

Signal: OverlayController remains the largest and most frequently changed file.
The capture method coordinates cancellation, output, temporary pointer visibility
and result UI. Geometry, capture transport, region selection and result actions
already have separate modules. Their complexity would spread back into the
controller if those modules were deleted, so they earn their interfaces.

Proposal: when another capture target or output is added, move the asynchronous
capture/output lifetime into a ScreenshotSession with one request and completion
result. Keep presentation eligibility and pointer hiding in OverlayController.
Its interface must include cancellation identity and partial-output errors.

Proof before any future refactor: capture error/crop tests, native full-display
and region output, Escape cancellation, result actions, deactivation cancellation
and the same own-window screenshots. Move it in one behavior-preserving commit.

No current source-review finding or measured runtime problem makes this a Strong
refactor before delivery.

## Import publication, Worth exploring after measurement

Files: PresentationArchive.swift, 275 lines; PresentationStore.swift, 550 lines;
PresetsSettings.swift, 219 lines; HandRestoreTransaction.swift.

The archive owns the bounded value schema. The store hides preview validation,
staging, before/after journals and recovery. Preparation runs off-main. Final
validation and same-volume publication share the main queue with native/control
preference writers. Hand restoration has a separate preference-persistence phase.
These boundaries directly resolved the audited corruption and ordering failures.

The file, persistence and failure adapters are exercised by real temporary files
and deterministic failures. They are real seams, rather than unused protocols.
Keep this arrangement. Measure the largest supported publication before moving
or splitting it. A private queue lock that other preference writers do not use
would reintroduce the stale-preview defect.

## Confirmed module boundaries

- DisplayInkStore owns per-display documents. InkVisibility owns lifetime;
  AnnotationDocument owns full geometry/history. AnnotationHitTest owns selective
  erasing. None needs a second event tap.
- RadialInput owns input-session identity and pair ownership. RadialSession owns
  geometry/candidates. Native menu callbacks carry their originating session ID.
- HotKeyBindings owns independent registrations. One failure does not determine
  the lifetime of another command.
- PointerConfigurationDocument owns inheritance and validated overrides.
  SoundOutputConfiguration owns output audibility. TapSound owns the serial
  driver and deadlines; fake drivers and schedulers test the same interface.
- DrawingPracticeSession and PointerPreviewPlayback own disposable local state.
  Preview rendering does not subscribe to or modify the live annotation store.
- PointerThumbnailCache hides encoding and export reuse. Steady catalog polls
  do not repeatedly encode or rewrite unchanged artwork.

## Top recommendation

Keep the current modules for this handoff. No additional Strong refactor is
required. Capture-session extraction is the next Worth exploring change when
capture behavior grows again.

Considered and not recommended: a Swift 6 migration in this milestone, extra
targets without a testability benefit, a generic event bus, a second input tap,
or splitting files into extensions solely to reduce line counts.
