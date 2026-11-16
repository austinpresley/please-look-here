# S-048 screenshot results and recovery

Implemented the result panel with Reveal in Finder, Copy Again and Close actions.
The panel retains only the most recent encoded screenshot and uses the existing
own-window input exclusions. Pointer shutdown closes it. A removed saved file
produces an inline message while the encoded image remains available to copy.

Recovery now offers Screen Recording settings only for the permission failure.
Display, frame, encoding and file-write failures offer Retry and Cancel. Retry
is dispatched after the prior capture's cleanup completes.

Local check: `swift test --filter ScreenshotRecoveryTests` passed all three
tests using suite `com.austinpresley.tinyhand.review.capture-tests` and temporary
hands. No normal settings, clipboard or screenshot destination was changed by
the tests. Active light/dark panel checks and end-to-end capture are pending
coordinator validation. Region/window selection is not implemented by this
commit.

Glossary proposal: Screenshot result is the temporary panel that offers actions
for the latest completed capture. It does not take a new screenshot.
