// GENERATED CODE - DO NOT EDIT.
// Run: dart run tool/generate_protocol.dart

#ifndef FPLAYER_PROTOCOL_H_
#define FPLAYER_PROTOCOL_H_

#include <string>

namespace fplayer_protocol {

inline constexpr char kPluginChannel[] = "fplayer.dev/fplayer";
inline constexpr char kPluginEventChannel[] = "fplayer.dev/fplayer/event";
inline constexpr char kPlatformChannel[] = "fplayer.dev/fplayer/platform";
inline constexpr char kPlayerChannelPrefix[] = "fplayer.dev/fplayer/";
inline constexpr char kPlayerEventChannelPrefix[] = "fplayer.dev/fplayer/event/";

inline constexpr char kMethodGetPlatformVersion[] = "getPlatformVersion";
inline constexpr char kMethodInit[] = "init";
inline constexpr char kMethodCreatePlayer[] = "createPlayer";
inline constexpr char kMethodReleasePlayer[] = "releasePlayer";
inline constexpr char kMethodLogLevel[] = "logLevel";
inline constexpr char kMethodSetOrientationPortrait[] = "setOrientationPortrait";
inline constexpr char kMethodSetOrientationLandscape[] = "setOrientationLandscape";
inline constexpr char kMethodSetOrientationAuto[] = "setOrientationAuto";
inline constexpr char kMethodSetScreenOn[] = "setScreenOn";
inline constexpr char kMethodIsScreenKeptOn[] = "isScreenKeptOn";
inline constexpr char kMethodBrightness[] = "brightness";
inline constexpr char kMethodSetBrightness[] = "setBrightness";
inline constexpr char kMethodVolumeUp[] = "volumeUp";
inline constexpr char kMethodVolumeDown[] = "volumeDown";
inline constexpr char kMethodVolumeMute[] = "volumeMute";
inline constexpr char kMethodVolumeSet[] = "volumeSet";
inline constexpr char kMethodSystemVolume[] = "systemVolume";
inline constexpr char kMethodVolUiMode[] = "volUiMode";
inline constexpr char kMethodOnLoad[] = "onLoad";
inline constexpr char kMethodOnUnload[] = "onUnload";
inline constexpr char kMethodRequestAudioFocus[] = "requestAudioFocus";
inline constexpr char kMethodReleaseAudioFocus[] = "releaseAudioFocus";
inline constexpr char kMethodGetBatteryInfo[] = "getBatteryInfo";
inline constexpr char kMethodSetupSurface[] = "setupSurface";
inline constexpr char kMethodSetOption[] = "setOption";
inline constexpr char kMethodApplyOptions[] = "applyOptions";
inline constexpr char kMethodSetDataSource[] = "setDataSource";
inline constexpr char kMethodPrepareAsync[] = "prepareAsync";
inline constexpr char kMethodStart[] = "start";
inline constexpr char kMethodPause[] = "pause";
inline constexpr char kMethodStop[] = "stop";
inline constexpr char kMethodReset[] = "reset";
inline constexpr char kMethodGetCurrentPosition[] = "getCurrentPosition";
inline constexpr char kMethodSetVolume[] = "setVolume";
inline constexpr char kMethodSeekTo[] = "seekTo";
inline constexpr char kMethodSetLoop[] = "setLoop";
inline constexpr char kMethodSetSpeed[] = "setSpeed";
inline constexpr char kMethodSnapshot[] = "snapshot";
inline constexpr char kMethodOnSnapshot[] = "_onSnapshot";
inline constexpr char kEventPrepared[] = "prepared";
inline constexpr char kEventStateChange[] = "state_change";
inline constexpr char kEventRenderingStart[] = "rendering_start";
inline constexpr char kEventFreeze[] = "freeze";
inline constexpr char kEventBuffering[] = "buffering";
inline constexpr char kEventPos[] = "pos";
inline constexpr char kEventRotate[] = "rotate";
inline constexpr char kEventSizeChanged[] = "size_changed";
inline constexpr char kEventSeekComplete[] = "seek_complete";
inline constexpr char kEventError[] = "error";
inline constexpr char kEventVolume[] = "volume";
inline constexpr int kStateIdle = 0;
inline constexpr int kStateInitialized = 1;
inline constexpr int kStateAsyncPreparing = 2;
inline constexpr int kStatePrepared = 3;
inline constexpr int kStateStarted = 4;
inline constexpr int kStatePaused = 5;
inline constexpr int kStateCompleted = 6;
inline constexpr int kStateStopped = 7;
inline constexpr int kStateError = 8;
inline constexpr int kStateEnd = 9;

inline std::string PlayerChannel(int id) {
  return std::string(kPlayerChannelPrefix) + std::to_string(id);
}

inline std::string PlayerEventChannel(int id) {
  return std::string(kPlayerEventChannelPrefix) + std::to_string(id);
}

}  // namespace fplayer_protocol

#endif  // FPLAYER_PROTOCOL_H_

