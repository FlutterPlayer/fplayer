#!/usr/bin/env bash
set -euo pipefail

flutter pub get
flutter analyze --no-fatal-infos
flutter test

(
  cd packages/fplayer_ui
  flutter pub get
  flutter analyze --no-fatal-infos
  flutter test
)

(
  cd example
  flutter pub get
  flutter analyze --no-fatal-infos
  flutter test
)
