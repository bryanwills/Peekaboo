## [3.9.7] - 2026-07-21

### Fixed
- Restore standalone and npm CLI launches on macOS 15 by bundling every Swift back-deployment compatibility library required by the release binary and rejecting dangling compatibility dependencies during release verification. Thanks @gyfis for #291.
- Canceling during a ScreenCaptureKit transient-denial retry sleep now stops before a second capture attempt or permission probe. Thanks @SebTardif for #289.
- Prevent dialog discovery and element traversal from recursing indefinitely when an app reports cyclic accessibility relationships.
