### Added
- The MCP image tool now supports native `max_dimension` downscaling, with inline `format: "data"` captures capped at 1500 pixels by default to reduce payload and model-context overhead. Thanks @jacobjove for #219.
### Changed
- The Sessions window was redesigned around native Liquid Glass: the empty-state ghost is now a smooth vector silhouette rendered as a real glass surface that floats over a soft shadow and occasionally glances around, the sidebar swaps its hand-rolled header and search box for the native toolbar search field plus a compose button (⌘N), session rows show tidier metadata with a model badge, and empty search results use the standard "No Results" view. The refreshed ghost (white with a soft gradient in both light and dark mode) also carries over to the status-bar popover and onboarding screens.
### Fixed
- `peekaboo capture action` now returns within a bounded interval when a child survives termination attempts, preserves graceful TERM handling for timeouts and cancellation, and eventually reaps an abandoned child. Thanks @SebTardif for #215.
