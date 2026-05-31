---
summary: 'Send modifier combos via peekaboo hotkey'
read_when:
  - 'triggering Cmd-based shortcuts without scripting AppleScript'
  - 'sending app shortcuts without stealing foreground focus'
---

# `peekaboo hotkey`

`hotkey` sends one shortcut chord (Cmd+C, Cmd+Shift+T, etc.). It accepts comma- or space-separated tokens either positionally or via `--keys`, normalizes them to lowercase, then hands the joined list to `AutomationServiceBridge.hotkey`. If Peekaboo can resolve a target process from app, PID, window, or snapshot metadata, delivery is background by default; pass `--foreground` for focused/global hotkeys. If you provide both key forms, the positional value wins.

## Key options
| Flag | Description |
| --- | --- |
| `keys` / `--keys "cmd,c"` | Required list of keys (positional or `--keys`). Use commas or spaces; modifiers (`cmd`, `alt`, `ctrl`, `shift`, `fn`) can be mixed with letters/numbers/special keys. |
| `--hold-duration <ms>` | Milliseconds to hold the combo before releasing (default `50`). |
| Target flags | `--app <name>`, `--pid <pid>`, `--window-id <id>`, `--window-title <title>`, `--window-index <n>` — send the hotkey to a specific app/window in the background when possible. (`--window-title`/`--window-index` require `--app` or `--pid`; `--window-id` does not.) |
| `--snapshot <id>` | Optional snapshot ID used for validation/focus (no implicit “latest snapshot” lookup). |
| `--foreground` | Focus target and send a foreground/global hotkey. Focus flags also imply foreground delivery. |
| `--focus-background` | Legacy alias for the default background delivery. |
| Focus flags | `FocusCommandOptions` flags apply in foreground mode. |

## Implementation notes
- The command errors if no keys are provided (either positionally or via `--keys`).
- When both forms are present, the positional value is used.
- Background hotkeys are parsed as one non-modifier key plus optional modifiers, such as `cmd,l` or `cmd,shift,p`. For key sequences, use `press` or another command that models sequential input.
- Background delivery uses CoreGraphics process-targeted keyboard events. Peekaboo preflights event-posting permission and confirms the target process is running before sending the event, but `postToPid` does not confirm delivery or that the app handled the shortcut. Apps that only handle shortcuts for their focused key window may ignore these events while in the background.
- If you omit both `--snapshot` and the target flags, the command sends a foreground/global hotkey to the current focus; this is handy for OS-global shortcuts like Spotlight, but for app-specific shortcuts you should provide a target or reuse the `see` snapshot.
- JSON mode returns the normalized key list, total count, delivery mode, optional target PID, and elapsed time, which is useful when logging scripted shortcuts.

## Examples
```bash
# Copy the current selection
peekaboo hotkey "cmd,c"

# Reopen the last closed tab in Safari
peekaboo hotkey --keys "cmd,shift,t" --snapshot $(jq -r '.data.snapshot_id' /tmp/see.json)

# Trigger Spotlight without needing a snapshot
peekaboo hotkey --keys "cmd space" --no-auto-focus

# Focus Safari's address field without bringing Safari forward
peekaboo hotkey "cmd,l" --app Safari

# Force foreground delivery for apps that require the focused key window
peekaboo hotkey "cmd,l" --app Safari --foreground

# Tab backwards using Shift+Tab (positional, space-separated)
peekaboo hotkey "shift tab"
```

## Troubleshooting
- Verify Screen Recording + Accessibility permissions (`peekaboo permissions status`). Background hotkeys also require Event Synthesizing access for the process that sends the event; request it with `peekaboo permissions request-event-synthesizing`. When Peekaboo is using a remote bridge host, that command requests access for the bridge host. Use `--no-remote` only when you want to grant the local CLI process.
- Confirm your target (app/window/selector) with `peekaboo list`/`peekaboo see` before rerunning.
- If you see `SNAPSHOT_NOT_FOUND`, regenerate the snapshot with `peekaboo see` (or omit `--snapshot` to use the most recent one).
- Re-run with `--json` or `--verbose` to surface detailed errors.
