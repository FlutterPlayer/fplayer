# fplayer

Flutter media player for Android, iOS, macOS, Windows and OpenHarmony.

`fplayer` is the Flutter plugin layer. The media kernels are built and published
by [FlutterPlayer/ijkplayer](https://github.com/FlutterPlayer/ijkplayer); this
repository does not vendor kernel binaries. Every platform package is fetched
from an ijkplayer release, so one `fplayer` version always uses one kernel
version across all platforms.

- Android API 28+ (arm64-v8a)
- iOS 13+ (device arm64; arm64 simulator)
- macOS 10.15+ (CI ships arm64; universal builds can be produced locally)
- OpenHarmony API 12+ (arm64-v8a; see [docs/ohos.md](docs/ohos.md))
- Windows x64

## Kernel packages from ijkplayer

| Platform | ijkplayer release asset | fplayer destination | Consumer |
| --- | --- | --- | --- |
| Android | `fplayercore-release.aar` | `android/local-repo/` | Gradle Maven mirror |
| iOS | `fplayercore-ios.xcframework.zip` | `ios/fplayer/Frameworks/` | `fplayercore-ios` Swift Package; podspec |
| macOS | `fplayercore-macos.xcframework.zip` | `macos/fplayer/Frameworks/` | `fplayercore-macos` Swift Package |
| OpenHarmony | `fplayercore-ohos.har` | `ohos/har/` | `oh-package.json5` |
| Windows | `fplayercore-windows.zip` | `windows/third_party/fplayercore/` | CMake |
| Any | `fplayercore-manifest.json` | temporary | SHA-256 verification |

Fetch the latest ijkplayer release:

```bash
./tool/fetch_ijkplayer_packages.sh
```

Pin a specific kernel release:

```bash
./tool/fetch_ijkplayer_packages.sh 1.2.0
IJKPLAYER_VERSION=1.2.0 ./tool/fetch_ijkplayer_packages.sh
```

Offline or CI staging:

```bash
IJKPLAYER_ASSET_DIR=/path/to/assets IJKPLAYER_SKIP_WINDOWS=1 \
  ./tool/fetch_ijkplayer_packages.sh local
```

Version resolution order is: command-line argument, `IJKPLAYER_VERSION`, then
the latest GitHub release. `GITHUB_TOKEN` is optional and avoids API rate limits.
The fetched files are gitignored; run the fetch script after cloning and before
building. The Android AAR is mirrored into `android/local-repo` and Gradle
resolves `io.github.flutterplayer:fplayercore:<release-tag>` from that mirror or
Maven Central. The iOS and macOS `Package.swift` files resolve the
`fplayercore-ios` and `fplayercore-macos` Swift Packages at the same exact
version. The example project uses Flutter's Swift Package Manager integration
and has no Podfile; the podspecs remain for consumers that still use CocoaPods.

Release order: tag `ijkplayer` first, let its release workflow publish the
Android, iOS, macOS and Windows assets, dispatch the OHOS job for that tag, then
fetch that tag here. The `fplayer` CI workflow follows the same rule.

## Install

```yaml
dependencies:
  fplayer: ^1.3.0
  fplayer_ui:
    git:
      url: https://github.com/FlutterPlayer/fplayer.git
      path: packages/fplayer_ui
```

`fplayer_ui` contains the rich panels, gesture handling and volume/brightness
overlays. The core package includes the player and a minimal default panel.

For an unpublished branch:

```yaml
dependencies:
  fplayer:
    git:
      url: https://github.com/FlutterPlayer/fplayer.git
      ref: develop
```

## Build and test

```bash
./tool/fetch_ijkplayer_packages.sh
./tool/ci.sh

cd example
flutter pub get
flutter build apk --debug
flutter build ios --simulator --no-codesign
flutter build macos --debug
flutter build windows --debug
```

`tool/ci.sh` runs `pub get`, `analyze` and unit tests for the root package,
`packages/fplayer_ui` and `example`. Native builds require the fetched packages
for their platform.

## GitHub Actions

`.github/workflows/ci.yml` runs:

- `dart`: `tool/ci.sh` on Ubuntu.
- `android`: fetch the ijkplayer AAR into the local Maven mirror and build the example APK.
- `apple`: fetch the xcframeworks, build the iOS simulator app and the macOS app.
- `windows`: fetch the Windows zip and build the Windows app.
- `ohos`: manual `workflow_dispatch` on a `[self-hosted, ohos]` runner with the
  OpenHarmony Flutter SDK and DevEco toolchain.

A manual run can pin `ijkplayer_version` and opt into the OHOS job.

## Usage

See [example/lib/video_page.dart](example/lib/video_page.dart) for a complete
player page: `FPlayer`, `FView`, options, seek, fullscreen and the optional
`fplayer_ui` panel.

The iOS simulator is supported by the rebuilt arm64 kernel. The podspec excludes
`i386`/`x86_64` simulator slices; use an Apple Silicon simulator or a device.

## Links

- Kernel source and releases: https://github.com/FlutterPlayer/ijkplayer
- Documentation: https://fplayer.dev/
- Issues: https://github.com/FlutterPlayer/fplayer/issues
