## [3.5.4] - 2026-07-03

### Added
- MiniMax-M3 can now power screenshot analysis and agent runs through the global and China MiniMax routes. Thanks @Tugser for #191.
- Kimi K2.6 and K2.7 Code can now power screenshot analysis and agent runs through Moonshot's API. Thanks @Tugser for #192.

### Fixed
- CLI paste now completes and reports clipboard restoration before returning, warning without inviting a retry when delivery succeeded but restoration failed.
- MCP paste now warns without suggesting a retry when clipboard restoration fails after delivery. Thanks @SebTardif for #210.
- MCP inline image capture now returns an explicit error when neither capture nor saved-file fallback contains image data, instead of reporting a successful zero-byte PNG. Thanks @SebTardif for #209.
- Speech recording now cancels and releases its recorder observer on stop and send, including after recorder errors. Thanks @SebTardif for #204.
- Go-to-Folder navigation now stops before typing or submitting when a required synthetic hotkey fails. Thanks @SebTardif for #206.
- Daemon launch, socket, and shutdown polling now stop promptly when their parent task is cancelled instead of spinning until the timeout. Thanks @SebTardif for #203.
- Public CLI, agent, MCP, and API guidance now treats runtime element IDs as opaque strings to copy exactly instead of implying role-specific ID shapes. Thanks @coygeek for #194.
- Sparkle update checks no longer received a 3.5.3 enclosure before its release assets were public; the validated feed entry was restored after publication. Thanks @bcharleson for #199.
- JSON-only `peekaboo see` runs without `--path` now keep required screenshots in snapshot storage instead of leaving files on Desktop or exposing their temporary paths. Thanks @coygeek for #196.
- Watch captures now honor stop requests during transient ScreenCaptureKit retry backoff instead of waiting out the full delay. Thanks @SebTardif for #193.
- Peekaboo agent skill install and usage guidance now uses the current `skills/peekaboo` path, treats observed element IDs as opaque, and keeps screenshot artifacts in explicit temporary paths. Thanks @coygeek for #197.
