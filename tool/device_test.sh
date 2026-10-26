#!/usr/bin/env bash
#
# Runs the on-device assertion tests against a connected phone.
#
# Usage:
#   ./tool/device_test.sh -d <device-id>
#   ./tool/device_test.sh -d <device-id> --dart-define=FPLAYER_TEST_URL=https://host/video.mp4
#
# `flutter devices` lists the device ids. Without FPLAYER_TEST_URL the remote
# source test is skipped.
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# The example app still pins Gradle 8.0 / AGP 8.1.4, which require JDK 17.
if [ -z "${JAVA_HOME:-}" ]; then
    if [ -x /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home/bin/java ]; then
        JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
    else
        JAVA_HOME="$(/usr/libexec/java_home -v 17 2>/dev/null || true)"
    fi
    export JAVA_HOME
fi

cd "$SCRIPT_DIR/../example"

if command -v fvm >/dev/null 2>&1; then
    FLUTTER=(fvm flutter)
else
    FLUTTER=(flutter)
fi

"${FLUTTER[@]}" pub get
"${FLUTTER[@]}" test integration_test/fplayer_device_test.dart "$@"
