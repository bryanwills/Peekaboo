## [3.5.0] - 2026-06-12

### Added
- `peekaboo agent` now supports explicit Claude Fable 5 (`claude-fable-5`) selection with 1M context and 128K max output while keeping Anthropic defaults on Opus 4.8 for zero-retention compatibility.

### Changed
- Agent runs now honor the saved `agent.temperature` and `agent.maxTokens` values shared by the CLI and macOS Settings UI, clamp them to each provider's capabilities, infer Fable limits through compatible providers, and omit unsupported sampling parameters for GPT-5 and current Anthropic reasoning models.
- Project, issue, build, release, and app About links now use the canonical `openclaw/Peekaboo` repository.

### Fixed
- Bridge hosts now use atomic lease-backed socket ownership and bounded nonblocking transport, keep Peekaboo.app and the reusable daemon on distinct paths while preserving the healthy app's TCC-backed fallback, preserve lifecycle settings while migrating legacy daemons, prevent MCP from hosting a bridge listener, safely recover stale sockets, and release abandoned client connections instead of wedging. Thanks @Artifact-LV for #184.
- Legacy screen and area capture now fails with a permission or native capture error instead of returning wallpaper-only/redacted pixels from background sessions. Thanks @VishalJ99 for #185.
