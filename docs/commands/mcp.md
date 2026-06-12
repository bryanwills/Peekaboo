---
summary: 'Run Peekaboo as an MCP server via peekaboo mcp'
read_when:
  - 'exposing Peekaboo as an MCP server'
  - 'debugging MCP server startup or transport options'
---

# `peekaboo mcp`

`mcp` runs Peekaboo as a Model Context Protocol server. `peekaboo mcp` defaults to `serve`, so you can launch the server without specifying a subcommand.

## Subcommands
| Name | Purpose | Key options |
| --- | --- | --- |
| `serve` | Run Peekaboo’s MCP server over stdio/HTTP/SSE. | `--transport stdio|http|sse` (default stdio), `--port <int>` for HTTP/SSE; global `--bridge-socket <path>` attaches to an existing Bridge host. |

## Implementation notes
- `serve` instantiates `PeekabooMCPServer` and maps the transport string to `PeekabooCore.TransportType`. Stdio is the default for Claude Code integrations.
- HTTP/SSE server transports are stubbed; they currently throw “not implemented.”
- The MCP process owns its stdio lifecycle and never hosts a Bridge listener. Support stays process-local by default;
  an explicit `--bridge-socket <path>` uses that existing Bridge host and skips the embedded daemon.
- The native tool catalog includes bounded `capture` for live screen/window/region recording or video ingest. It writes retained frames, `contact.png`, `metadata.json`, and optional MP4 output, so use tool allow/deny filters when exposing MCP to untrusted clients.
- UI automation tools include action-first additions: `set_value` directly mutates a settable accessibility value, and `perform_action` invokes a named accessibility action on an element from `see`.
- `click` preserves element IDs and queries when forwarding to automation, so action-first policy can use accessibility actions before synthetic fallback.

## Examples
```bash
# Start the Peekaboo MCP server (defaults to stdio)
peekaboo mcp

# Explicit transport selection
peekaboo mcp serve --transport stdio

# Route MCP tools through an existing Bridge host
peekaboo mcp serve --bridge-socket "$HOME/Library/Application Support/Peekaboo/bridge.sock"
```

## Troubleshooting
- Verify Screen Recording + Accessibility permissions (`peekaboo permissions status`).
- Confirm your target (app/window/selector) with `peekaboo list`/`peekaboo see` before rerunning.
- Re-run with `--json` or `--verbose` to surface detailed errors.
