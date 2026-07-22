#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION=$(node -p "require('$ROOT_DIR/package.json').version")
ARTIFACT_DIR=$(mktemp -d /tmp/peekaboo-extracted-artifact.XXXXXX)
trap 'rm -rf "$ARTIFACT_DIR"' EXIT

if [ "${PEEKABOO_BUILD_ARTIFACT:-true}" = true ]; then
    SIGN_IDENTITY=- CODESIGN_TIMESTAMP=off "$ROOT_DIR/scripts/build-swift-universal.sh"
fi

RELEASE_DIR="$ARTIFACT_DIR/peekaboo-macos-universal"
EXTRACT_DIR="$ARTIFACT_DIR/extracted"
mkdir -p "$RELEASE_DIR" "$EXTRACT_DIR"

cp "$ROOT_DIR/peekaboo" "$RELEASE_DIR/"
for runtime_library in "$ROOT_DIR"/libswiftCompatibility*.dylib; do
    [ -e "$runtime_library" ] || continue
    cp "$runtime_library" "$RELEASE_DIR/"
done
cp "$ROOT_DIR/LICENSE" "$ROOT_DIR/README.md" "$RELEASE_DIR/"
printf '%s\n' "$VERSION" > "$RELEASE_DIR/VERSION"

ARCHIVE_PATH="$ARTIFACT_DIR/peekaboo-macos-universal.tar.gz"
tar -czf "$ARCHIVE_PATH" -C "$ARTIFACT_DIR" peekaboo-macos-universal
tar -xzf "$ARCHIVE_PATH" -C "$EXTRACT_DIR"

EXTRACTED_DIR="$EXTRACT_DIR/peekaboo-macos-universal"
"$ROOT_DIR/scripts/verify-swift-runtime-libraries.sh" "$EXTRACTED_DIR/peekaboo" "$EXTRACTED_DIR"
"$EXTRACTED_DIR/peekaboo" --version | grep -Fq "Peekaboo $VERSION"

echo "test-extracted-cli-artifact: ok"
