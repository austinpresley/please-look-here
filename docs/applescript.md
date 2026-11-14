# AppleScript

Look Here Please has a native scripting dictionary. In Script Editor, choose
File > Open Dictionary and select Look Here Please. The first script that controls
the app shows a macOS Automation prompt for the app running the script.

## Vocabulary

| Term | Type | Meaning |
| --- | --- | --- |
| `pointer active` | boolean, read/write | Whether the pointer is on |
| `interact` | boolean, read/write | True uses apps normally. False draws on screen and needs Accessibility |
| `selected pointer` | pointer, read/write | Set it to a pointer or a pointer id. Does not turn the pointer on |
| `drawing tool` | `pen tool`, `rectangle tool`, `arrow tool`, `text tool`, `number tool` | Setting it also turns Interact off, as the toolbar does |
| `pointers` | elements | Every available pointer, each with `id` and `name` |
| `toggle pointer` | command | Returns whether the pointer is now on |
| `toggle interact` | command | Returns whether Interact is now on |

## Examples

```applescript
tell application "Look Here Please"
    set selected pointer to pointer "Robot"
    set pointer active to true
    set interact to true
    get {pointer active, interact, name of selected pointer, drawing tool}
end tell
```

```applescript
tell application "Look Here Please"
    get name of every pointer
end tell
```

```applescript
tell application "Look Here Please"
    try
        set drawing tool to arrow tool
    on error message number code
        display dialog message
    end try
end tell
```

## Errors

Script commands use the same validation as the [local control protocol](control-protocol.md).

| Number | Meaning |
| --- | --- |
| 1001 | Accessibility is needed to draw |
| 1002 | Unavailable, for example while a screenshot is pending |
| 1003 | That pointer is not available |
| 1004 | The pointer image could not be loaded |
| 1005 | The pointer could not start |
| 1000 | Any other rejection |

S-018 selection requires an enabled, available pointer. An available disabled
pointer reports error 1006 and keeps both selection and activation unchanged.
Missing images still report 1004. `pointers` continues to expose the complete
library for compatibility. Read enabled/available metadata and change eligibility
through the v1 JSON control protocol documented in [control-protocol.md](control-protocol.md).
