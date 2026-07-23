## [3.9.8] - 2026-07-23

### Fixed
- Prevent MCP shell commands from deadlocking when either stdout or stderr exceeds its pipe buffer by draining both streams concurrently. Thanks @SebTardif for #292.
