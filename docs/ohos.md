# OpenHarmony (OHOS) support

This plugin ships an OHOS HAR module under `ohos/` that ports the proven
fijkplayer OHOS ArkTS plugin (`FIjkPlayer` / `FIjkPlayerPlugin`) to fplayer's
own Dart protocol. It talks to the native ijkplayer OHOS library through the
`@fplayer/fplayercore` HAR, which is built from the sibling
`ijkplayer/platform/ohos` repository.

## Prerequisites

- A Flutter build with OpenHarmony support (the `flutter` command must
  understand the `ohos` platform and generate `ohos/entry` in the app).
- The Flutter OHOS engine HAR at `ohos/har/flutter.har` (provided by your
  Flutter OHOS SDK; referenced by `oh-package.json5` as
  `@ohos/flutter_ohos`).
- The ijkplayer OHOS HAR built from the sibling repository at
  `ijkplayer/platform/ohos` (referenced by `oh-package.json5` as
  `@fplayer/fplayercore`). See `docs/ohos.md` note below for the module
  import surface it must export.
- DevEco Studio / hvigor toolchain with an OpenHarmony SDK.

## Dependency paths

Both dependencies are local `file:` references resolved relative to the HAR
module root (`ohos/`):

- `@ohos/flutter_ohos` -> `file:./har/flutter.har`
- `@fplayer/fplayercore` -> `file:./har/fplayercore-ohos.har`

The ijkplayer HAR is checked in as a prebuilt artifact. It contains
`libijkplayer_napi.so`, `libijkplayer.so` and `libijksdl.so` for arm64-v8a.
To refresh it after changing the ijkplayer sources, build the
`ijkplayer/platform/ohos` module as a HAR (add it to an OHOS project's
`build-profile.json5` and run `hvigorw assembleHar --mode module -p
module=fplayercore_ohos@default` with `IJKROOT_PATH` pointing at the ijkplayer
repository root), then copy the produced `.har` to `ohos/har/`.

The native module import is a single module:

```typescript
import { IjkMediaPlayer, MessageType } from '@fplayer/fplayercore';
```

`@fplayer/fplayercore` must export `IjkMediaPlayer` and the `MessageType`
enum (the native `FFP_MSG` codes, e.g. `MEDIA_PREPARED`,
`MEDIA_PLAYBACK_STATE_CHANGED`, `MEDIA_VIDEO_RENDERING_START`,
`MEDIA_VIDEO_SIZE_CHANGED`, ...). The `onMessage(what, arg1, arg2, obj)`
callback receives these codes directly. The runtime library is
`libijkplayer_napi.so` with NAPI module name `ijkplayer_napi`.

> Note: this port does **not** depend on `@zaiohos/ijkplayer-surface` (the
> reference implementation's packaged HAR). If your ijkplayer OHOS build does
> not yet publish the `@fplayer/fplayercore` package name, you can either
> rename the package, or temporarily point the import and the
> `oh-package.json5` dependency at your local `@zaiohos/ijkplayer-surface`
> HAR. The single-module import surface (`IjkMediaPlayer`, `MessageType`) is
> the only contract this plugin relies on.

## Build

1. Use the prebuilt `ohos/har/fplayercore-ohos.har` (or rebuild it as described
   above and copy it into `ohos/har/`).
2. Place the Flutter OHOS `flutter.har` at `ohos/har/flutter.har`.
3. From the app's `ohos` directory, run the normal Flutter OHOS build, e.g.:

   ```sh
   flutter build hap
   ```

   The plugin is registered through `pubspec.yaml`:

   ```yaml
   flutter:
     plugin:
       platforms:
         ohos:
           pluginClass: FplayerPlugin
   ```

4. The generated plugin registrant imports the default export of the
   `fplayer` HAR (`ohos/index.ets`), which is `FplayerPlugin`.

## Channel / protocol mapping

The OHOS side uses fplayer's own channel names (not the reference
implementation's `befovy.com` names):

- plugin channel: `fplayer.dev/fplayer`
- player channel: `fplayer.dev/fplayer/<id>`
- player event channel: `fplayer.dev/fplayer/event/<id>`

Player events emitted match the Dart side in `lib/core/f_player.dart`:
`prepared`, `state_change`, `rendering_start`, `freeze`, `buffering`, `pos`,
`rotate`, `size_changed`, `seek_complete`, `error` (via the event channel's
error sink).

## Verification

The ijkplayer OHOS native libraries (`libijksdl.so`, `libijkplayer.so`,
`libijkplayer_napi.so`) are cross-compiled and link successfully against the
OpenHarmony 5.1.0 native SDK (arm64); see `ijkplayer/platform/ohos/README.md`.

An unsigned `entry-default-unsigned.hap` (149 MB) was built with Flutter
3.27.4-ohos, DevEco command-line tools 5.0.5 and the API 18 SDK. Installation
on the connected device (`LNG0224A09000859`) failed because hdc reports
`Unauthorized`; the HAP is also unsigned, so a HarmonyOS debug signing
config is required before installing on a retail device.

To verify OHOS end-to-end:

1. Build the `example` app for OHOS after adding an `example/ohos` app
   scaffold (the reference repository's `example/ohos` can be used as a
   template).
2. Confirm `@fplayer/fplayercore` resolves and the HAR compiles with
   hvigor.
3. Run a stream (HLS/RTMP) plus a local `asset://` and a `file://` source and
   confirm playback, seek, loop and speed.

## Current limitations

- **System volume writes are not supported.** OpenHarmony only allows system
  applications to change the media volume. `volumeUp`, `volumeDown`,
  `volumeMute`, `volumeSet` and `volUiMode` return success without doing
  anything. The Dart side already gates these behind
  `FPlugin.supportsSystemVolume` (false on OHOS), so they are normally not
  invoked. `systemVolume` is read-only and returns the current media volume.
- **Snapshots (`snapshot`) are not implemented** and return
  `notImplemented`. `FPlayer.takeSnapShot()` therefore fails on OHOS.
- **Plugin volume event stream is not implemented.** The plugin event channel
  `fplayer.dev/fplayer/event` has no `StreamHandler`; the Dart side never
  listens on it because `supportsSystemVolume` is false on OHOS.
- **Screen/orientation/brightness/audio-focus methods** are implemented
  (ported from the reference) but the Dart side gates them behind Android /
  iOS / macOS, so they are effectively unused on OHOS.
- `logLevel` is accepted as a no-op.
