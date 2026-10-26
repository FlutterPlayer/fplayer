#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

REPO="${IJKPLAYER_REPO:-FlutterPlayer/ijkplayer}"
VERSION="${1:-${IJKPLAYER_VERSION:-}}"
ASSET_DIR="${IJKPLAYER_ASSET_DIR:-}"
SKIP_WINDOWS="${IJKPLAYER_SKIP_WINDOWS:-0}"
PYTHON="${PYTHON:-python3}"
if ! command -v "$PYTHON" >/dev/null 2>&1; then
  PYTHON=python
fi

if [ -z "$VERSION" ] && [ -n "$ASSET_DIR" ]; then
  VERSION="local"
fi

if [ -z "$VERSION" ]; then
  AUTH=()
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    AUTH=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
  fi
  VERSION="$(curl -fsSL "${AUTH[@]}" "https://api.github.com/repos/${REPO}/releases/latest" \
    | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    | head -n 1)"
fi

if [ -z "$VERSION" ]; then
  printf 'Unable to resolve an ijkplayer release. Pass a version or set IJKPLAYER_VERSION.\n' >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ASSETS=(
  fplayercore-release.aar
  fplayercore-ios.xcframework.zip
  fplayercore-macos.xcframework.zip
  fplayercore-ohos.har
  fplayercore-manifest.json
)
if [ "$SKIP_WINDOWS" != "1" ]; then
  ASSETS+=(fplayercore-windows.zip)
fi

for asset in "${ASSETS[@]}"; do
  if [ -n "$ASSET_DIR" ]; then
    src="$ASSET_DIR/$asset"
    if [ ! -f "$src" ]; then
      if [ "$asset" = "fplayercore-manifest.json" ]; then
        continue
      fi
      printf 'Missing asset: %s\n' "$src" >&2
      exit 1
    fi
    cp "$src" "$TMP/$asset"
  else
    if ! curl -fL --retry 3 -o "$TMP/$asset" \
      "https://github.com/${REPO}/releases/download/${VERSION}/${asset}"; then
      if [ "$asset" = "fplayercore-manifest.json" ]; then
        rm -f "$TMP/$asset"
        continue
      fi
      exit 1
    fi
  fi
done

if [ -f "$TMP/fplayercore-manifest.json" ]; then
  "$PYTHON" - "$TMP" <<'PY'
import hashlib
import json
import os
import sys

root = sys.argv[1]
with open(os.path.join(root, "fplayercore-manifest.json"), encoding="utf-8") as handle:
    manifest = json.load(handle)
for asset in manifest.get("assets", []):
    path = os.path.join(root, asset["name"])
    if not os.path.isfile(path):
        continue
    digest = hashlib.sha256(open(path, "rb").read()).hexdigest()
    if digest != asset.get("sha256"):
        raise SystemExit(f"checksum mismatch: {asset['name']}")
PY
fi

extract() {
  if command -v ditto >/dev/null 2>&1; then
    ditto -x -k "$1" "$2"
    return
  fi
  "$PYTHON" - "$1" "$2" <<'PY'
import sys
import zipfile

zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])
PY
}

mkdir -p android/local-repo ios/fplayer/Frameworks macos/fplayer/Frameworks ohos/har windows/third_party
MAVEN_VERSION="$VERSION"
if [ "$VERSION" = "local" ]; then
  MAVEN_VERSION="0.0.0-local"
fi
MAVEN_DIR="android/local-repo/io/github/flutterplayer/fplayercore/$MAVEN_VERSION"
mkdir -p "$MAVEN_DIR"
cp "$TMP/fplayercore-release.aar" "$MAVEN_DIR/fplayercore-$MAVEN_VERSION.aar"
cat > "$MAVEN_DIR/fplayercore-$MAVEN_VERSION.pom" <<POM
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>io.github.flutterplayer</groupId>
  <artifactId>fplayercore</artifactId>
  <version>$MAVEN_VERSION</version>
  <packaging>aar</packaging>
</project>
POM
printf '%s\n' "$MAVEN_VERSION" > android/fplayercore.version
rm -f android/libs/fplayercore.jar android/libs/*.aar
rm -rf android/src/main/jniLibs
rm -rf ios/fplayer/Frameworks/fplayercore.xcframework
rm -rf macos/fplayer/Frameworks/fplayercore.xcframework
extract "$TMP/fplayercore-ios.xcframework.zip" ios/fplayer/Frameworks
extract "$TMP/fplayercore-macos.xcframework.zip" macos/fplayer/Frameworks
cp "$TMP/fplayercore-ohos.har" ohos/har/fplayercore-ohos.har
if [ "$SKIP_WINDOWS" != "1" ]; then
  rm -rf windows/third_party/ijkplayer windows/third_party/fplayercore
  extract "$TMP/fplayercore-windows.zip" windows/third_party
fi

printf 'ijkplayer %s packages installed\n' "$VERSION"
