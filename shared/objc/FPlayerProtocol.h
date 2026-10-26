// GENERATED CODE - DO NOT EDIT.
// Run: dart run tool/generate_protocol.dart

#ifndef FPlayerProtocol_h
#define FPlayerProtocol_h

#import <Foundation/Foundation.h>

#define FPLAYER_CHANNEL_PLUGIN @"fplayer.dev/fplayer"
#define FPLAYER_CHANNEL_PLUGIN_EVENT @"fplayer.dev/fplayer/event"
#define FPLAYER_CHANNEL_PLATFORM @"fplayer.dev/fplayer/platform"
#define FPLAYER_CHANNEL_PLAYER_PREFIX @"fplayer.dev/fplayer/"
#define FPLAYER_CHANNEL_PLAYER_EVENT_PREFIX @"fplayer.dev/fplayer/event/"

#define FPLAYER_METHOD_GET_PLATFORM_VERSION @"getPlatformVersion"
#define FPLAYER_METHOD_INIT @"init"
#define FPLAYER_METHOD_CREATE_PLAYER @"createPlayer"
#define FPLAYER_METHOD_RELEASE_PLAYER @"releasePlayer"
#define FPLAYER_METHOD_LOG_LEVEL @"logLevel"
#define FPLAYER_METHOD_SET_ORIENTATION_PORTRAIT @"setOrientationPortrait"
#define FPLAYER_METHOD_SET_ORIENTATION_LANDSCAPE @"setOrientationLandscape"
#define FPLAYER_METHOD_SET_ORIENTATION_AUTO @"setOrientationAuto"
#define FPLAYER_METHOD_SET_SCREEN_ON @"setScreenOn"
#define FPLAYER_METHOD_IS_SCREEN_KEPT_ON @"isScreenKeptOn"
#define FPLAYER_METHOD_BRIGHTNESS @"brightness"
#define FPLAYER_METHOD_SET_BRIGHTNESS @"setBrightness"
#define FPLAYER_METHOD_VOLUME_UP @"volumeUp"
#define FPLAYER_METHOD_VOLUME_DOWN @"volumeDown"
#define FPLAYER_METHOD_VOLUME_MUTE @"volumeMute"
#define FPLAYER_METHOD_VOLUME_SET @"volumeSet"
#define FPLAYER_METHOD_SYSTEM_VOLUME @"systemVolume"
#define FPLAYER_METHOD_VOL_UI_MODE @"volUiMode"
#define FPLAYER_METHOD_ON_LOAD @"onLoad"
#define FPLAYER_METHOD_ON_UNLOAD @"onUnload"
#define FPLAYER_METHOD_REQUEST_AUDIO_FOCUS @"requestAudioFocus"
#define FPLAYER_METHOD_RELEASE_AUDIO_FOCUS @"releaseAudioFocus"
#define FPLAYER_METHOD_GET_BATTERY_INFO @"getBatteryInfo"
#define FPLAYER_METHOD_SETUP_SURFACE @"setupSurface"
#define FPLAYER_METHOD_SET_OPTION @"setOption"
#define FPLAYER_METHOD_APPLY_OPTIONS @"applyOptions"
#define FPLAYER_METHOD_SET_DATA_SOURCE @"setDataSource"
#define FPLAYER_METHOD_PREPARE_ASYNC @"prepareAsync"
#define FPLAYER_METHOD_START @"start"
#define FPLAYER_METHOD_PAUSE @"pause"
#define FPLAYER_METHOD_STOP @"stop"
#define FPLAYER_METHOD_RESET @"reset"
#define FPLAYER_METHOD_GET_CURRENT_POSITION @"getCurrentPosition"
#define FPLAYER_METHOD_SET_VOLUME @"setVolume"
#define FPLAYER_METHOD_SEEK_TO @"seekTo"
#define FPLAYER_METHOD_SET_LOOP @"setLoop"
#define FPLAYER_METHOD_SET_SPEED @"setSpeed"
#define FPLAYER_METHOD_SNAPSHOT @"snapshot"
#define FPLAYER_METHOD_ON_SNAPSHOT @"_onSnapshot"
#define FPLAYER_EVENT_PREPARED @"prepared"
#define FPLAYER_EVENT_STATE_CHANGE @"state_change"
#define FPLAYER_EVENT_RENDERING_START @"rendering_start"
#define FPLAYER_EVENT_FREEZE @"freeze"
#define FPLAYER_EVENT_BUFFERING @"buffering"
#define FPLAYER_EVENT_POS @"pos"
#define FPLAYER_EVENT_ROTATE @"rotate"
#define FPLAYER_EVENT_SIZE_CHANGED @"size_changed"
#define FPLAYER_EVENT_SEEK_COMPLETE @"seek_complete"
#define FPLAYER_EVENT_ERROR @"error"
#define FPLAYER_EVENT_VOLUME @"volume"

typedef NS_ENUM(NSInteger, FPlayerStateCode) {
    FPlayerStateCodeIdle = 0,
    FPlayerStateCodeInitialized = 1,
    FPlayerStateCodeAsyncPreparing = 2,
    FPlayerStateCodePrepared = 3,
    FPlayerStateCodeStarted = 4,
    FPlayerStateCodePaused = 5,
    FPlayerStateCodeCompleted = 6,
    FPlayerStateCodeStopped = 7,
    FPlayerStateCodeError = 8,
    FPlayerStateCodeEnd = 9,
};

#endif /* FPlayerProtocol_h */
