---
summary: 'Paste text or rich content via peekaboo paste'
read_when:
  - 'you want fewer steps than clipboard set + menu/hotkey paste + clipboard restore'
  - 'pasting rich text (RTF) into a targeted app/window without drift'
---

# `peekaboo paste`

`paste` is an atomic “clipboard + Cmd+V + restore” helper. It temporarily replaces the system clipboard with your payload, pastes into the focused target, then restores the previous clipboard contents (or clears it if it was empty).

This reduces drift by collapsing multiple CLI steps into one command. Background process-targeted Cmd+V delivery is the default when Peekaboo can resolve a target process; pass `--foreground` for focused/global paste.

## Key options
| Flag | Description |
| --- | --- |
| `[text]` / `--text` | Plain text to paste. |
| `--file-path` / `--image-path` | Copy a file or image into the clipboard, then paste. |
| `--data-base64` + `--uti` | Paste raw base64 payload with explicit UTI (e.g. `public.rtf`). |
| `--also-text` | Optional plain-text companion when pasting binary. |
| `--restore-delay-ms` | Delay before restoring the previous clipboard (default 150ms). |
| Target flags | `--app <name>`, `--pid <pid>`, `--window-id <id>`, `--window-title <title>`, `--window-index <n>` — send Cmd+V to a specific app/window in the background when possible. |
| `--foreground` | Focus target and send foreground/global Cmd+V. Focus flags also imply foreground delivery. |
| Focus flags | Foreground focus controls (`--space-switch`, `--no-auto-focus`, etc.). |

## Examples
```bash
# Paste plain text into TextEdit
peekaboo paste "Hello, world" --app TextEdit

# Paste rich text (RTF) into a specific window title
peekaboo paste --data-base64 "$RTF_B64" --uti public.rtf --also-text "fallback" --app TextEdit --window-title "Untitled"

# Paste a PNG into Notes
peekaboo paste --file-path /tmp/snippet.png --app Notes

# Force foreground paste for apps that ignore background Cmd+V
peekaboo paste "Hello" --app TextEdit --foreground
```

## Notes
- File paths for `--file-path` and `--image-path` accept `~/...`.
- JSON output reports delivery mode and target PID when background delivery is used.

## Troubleshooting
- Verify Screen Recording + Accessibility permissions (`peekaboo permissions status`). Background paste also requires Event Synthesizing access for the sending process; request it with `peekaboo permissions request-event-synthesizing`.
- Confirm your target (app/window/selector) with `peekaboo list`/`peekaboo see` before rerunning.
- Re-run with `--json` or `--verbose` to surface detailed errors.
