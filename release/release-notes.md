## [3.6.0] - 2026-07-03

### Changed
- Visualizer animations were redesigned around a single "Ghost HUD" design language: one violet accent with red reserved for destructive operations, dark translucent HUD chips, and a shared motion vocabulary. Clicks show a targeting reticle with impact pulses (dashed ring for right-click), typing streams the actual keystrokes into a caption pill instead of a fake QWERTY keyboard, hotkeys press real macOS-style keycaps in sequence, mouse moves and drags trace a glowing comet with press/release rings, scrolls show flowing chevrons with a count tag, screenshots snap viewfinder brackets, and app lifecycle, window operations, menu paths, dialogs, and Space switches render as matching HUD toasts, outlines, and breadcrumbs.
- Agent-skill documentation now defines Peekaboo as the authority for product and workflow guidance while allowing distributors such as OpenClaw to ship release-pinned snapshots with host-specific overlays.

### Fixed
- Bridge hosts now always return a non-empty decodable error when error encoding fails, instead of surfacing EOF or a secondary decode failure. Thanks @SebTardif for #211.
- Snapshot listing and cleanup now propagate lock-open failures instead of treating unavailable storage as an empty snapshot list. Thanks @SebTardif for #212.
- Element-detection highlights from `see` now land exactly on the detected controls: bounds are converted from accessibility to screen coordinates before dispatch (they previously rendered vertically mirrored) and each outline is sized to its element instead of filling the padded overlay window; the overlays also use the shared accent style with an ID tag instead of orange boxes.
- The Sessions window no longer opens uninvited: it is suppressed at app launch, excluded from state restoration, no longer pops up when the running app is reopened programmatically, and the missing-API-key nudge shows it once instead of on every launch. Open it via the status-bar menu or ⌘⇧P as before.
- Automation services now route visual feedback to the visualizer by default; the wiring was never hooked up, so click, type, scroll, hotkey, swipe, mouse-move, window, menu, dialog, dock, Space-switch, and screenshot-flash animations were silently dropped even with Peekaboo.app running.
- Typing feedback masks printable characters as bullets before events are persisted or displayed, so automated password/token entry never leaves secrets in the visualizer event store or on screen; set `PEEKABOO_VISUALIZER_SHOW_TYPED_TEXT=true` to stream the actual text (e.g. for demo recordings).
- Debug Mac app builds are now signed with a development identity when one is available, so Screen Recording/Accessibility grants survive rebuilds instead of resetting (and re-prompting) on every build; machines without a certificate keep the unsigned fallback.
- Visualizer overlays now center on their target instead of pinning to the window's top-leading corner, which had offset click feedback by its padding and clipped or truncated HUD widgets.
- Mouse-trail and swipe visualizations now convert screen coordinates into window-local space with the correct Y-flip, so the paths render along the cursor's actual travel instead of drawing outside the overlay window.

### Removed
- The visualizer keyboard-theme setting (`visualizerKeyboardTheme`, config `visualizer.keyboardTheme`) is gone; it only themed the removed QWERTY typing widget and never affected anything else.
