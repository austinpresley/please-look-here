# Native pointer preview layout correction

The active light/dark Settings review caught a blank pointer sample in the dark
capture. Its background and controls rendered, but the child ArmView could retain
zero bounds because the host relied on a later AppKit layout pass.

A regression that resizes the host without manually calling layout failed twice
before the fix. PointerPreviewView now updates its renderer bounds and aim when
its frame changes or it joins a window. The child also autoresizes with the host.
Local playback settles on its existing timer and stops normally. The desktop
renderer and live preferences are unchanged.

The focused pointer/practice run passes all 13 tests after the correction.
Logs are `/tmp/lhp-review-preview-layout-red.log` and
`/tmp/lhp-review-preview-layout-green.log`. Native light/dark recaptures follow.

The preceding native layout correction reduced the preview controls row from
256 points to 22 in both appearances. Hiding segmented-picker labels preserved
their accessibility names while removing truncation. Local drawing Undo/Clear
now observe the practice session's history/visibility changes.
