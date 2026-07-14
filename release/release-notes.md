## [3.9.1] - 2026-07-14

### Changed
- `peekaboo inspect-ui` now accepts the standard `--app` target option used by other desktop commands; `--app-target` remains available as a legacy alias.
- `peekaboo move --smooth` now uses natural eased pointer arcs by default, while `--profile linear` preserves deterministic straight-line travel; explicit `--steps` values are honored and human paths are capped at 96 samples to avoid redundant input events.
- Pointer-movement feedback now follows the real move with a short fading tail and one coalesced overlay instead of replaying a slow, thick line across the screen after the pointer arrives.

### Fixed
- Canceling `peekaboo window close` now propagates through disappearance checks and stops before focus, hotkey, or pointer fallbacks. Thanks @SebTardif for #270.
- Canceling `peekaboo window maximize` now stops frame-settling polls before any additional accessibility reads. Thanks @SebTardif for #271.
- Default action-first clicks now synthesize a real pointer click for SwiftUI segmented tabs, whose accessibility `AXPress` action can report success without changing the selected tab.
- Local `see` now confirms snapshot publication before reporting success, preserving its timeout and failure guarantees when a command-level mutation barrier is active.
- Human pointer paths now use bounded minimum-jerk Bézier motion, land exactly on the requested coordinate, and drive the real drag/swipe event path instead of calculating an organic path and then discarding it for a linear drag.
