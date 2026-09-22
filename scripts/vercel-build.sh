#!/usr/bin/env bash
set -euo pipefail

# Vercel does not supply Flutter. Install the version validated for this app.
readonly FLUTTER_VERSION=3.24.4
readonly SDK_DIR="${TMPDIR:-/tmp}/yoyota-flutter-${FLUTTER_VERSION}"
if [[ ! -x "$SDK_DIR/bin/flutter" ]]; then
  git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$SDK_DIR"
fi
# Verify the release tag resolves to the official commit checked during setup.
readonly FLUTTER_COMMIT=603104015dd692ea3403755b55d07813d5cf8965
test "$(git -C "$SDK_DIR" rev-parse HEAD)" = "$FLUTTER_COMMIT"
export PATH="$SDK_DIR/bin:$PATH"
export CI=true
flutter config --no-analytics --enable-web
flutter --version
flutter pub get --enforce-lockfile
flutter analyze
flutter build web --release

test -s build/web/index.html
test -s build/web/main.dart.js
test -s build/web/flutter_bootstrap.js
test -s build/web/assets/assets/data/dealership_data.json
