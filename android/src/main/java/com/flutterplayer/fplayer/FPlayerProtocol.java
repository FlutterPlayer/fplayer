// GENERATED CODE - DO NOT EDIT.
// Run: dart run tool/generate_protocol.dart

package com.flutterplayer.fplayer;

public final class FPlayerProtocol {
    private FPlayerProtocol() {}

    public static final String CHANNEL_PLUGIN = "fplayer.dev/fplayer";
    public static final String CHANNEL_PLUGIN_EVENT = "fplayer.dev/fplayer/event";
    public static final String CHANNEL_PLATFORM = "fplayer.dev/fplayer/platform";
    public static final String CHANNEL_PLAYER_PREFIX = "fplayer.dev/fplayer/";
    public static final String CHANNEL_PLAYER_EVENT_PREFIX = "fplayer.dev/fplayer/event/";

    public static final String METHOD_GET_PLATFORM_VERSION = "getPlatformVersion";
    public static final String METHOD_INIT = "init";
    public static final String METHOD_CREATE_PLAYER = "createPlayer";
    public static final String METHOD_RELEASE_PLAYER = "releasePlayer";
    public static final String METHOD_LOG_LEVEL = "logLevel";
    public static final String METHOD_SET_ORIENTATION_PORTRAIT = "setOrientationPortrait";
    public static final String METHOD_SET_ORIENTATION_LANDSCAPE = "setOrientationLandscape";
    public static final String METHOD_SET_ORIENTATION_AUTO = "setOrientationAuto";
    public static final String METHOD_SET_SCREEN_ON = "setScreenOn";
    public static final String METHOD_IS_SCREEN_KEPT_ON = "isScreenKeptOn";
    public static final String METHOD_BRIGHTNESS = "brightness";
    public static final String METHOD_SET_BRIGHTNESS = "setBrightness";
    public static final String METHOD_VOLUME_UP = "volumeUp";
    public static final String METHOD_VOLUME_DOWN = "volumeDown";
    public static final String METHOD_VOLUME_MUTE = "volumeMute";
    public static final String METHOD_VOLUME_SET = "volumeSet";
    public static final String METHOD_SYSTEM_VOLUME = "systemVolume";
    public static final String METHOD_VOL_UI_MODE = "volUiMode";
    public static final String METHOD_ON_LOAD = "onLoad";
    public static final String METHOD_ON_UNLOAD = "onUnload";
    public static final String METHOD_REQUEST_AUDIO_FOCUS = "requestAudioFocus";
    public static final String METHOD_RELEASE_AUDIO_FOCUS = "releaseAudioFocus";
    public static final String METHOD_GET_BATTERY_INFO = "getBatteryInfo";
    public static final String METHOD_SETUP_SURFACE = "setupSurface";
    public static final String METHOD_SET_OPTION = "setOption";
    public static final String METHOD_APPLY_OPTIONS = "applyOptions";
    public static final String METHOD_SET_DATA_SOURCE = "setDataSource";
    public static final String METHOD_PREPARE_ASYNC = "prepareAsync";
    public static final String METHOD_START = "start";
    public static final String METHOD_PAUSE = "pause";
    public static final String METHOD_STOP = "stop";
    public static final String METHOD_RESET = "reset";
    public static final String METHOD_GET_CURRENT_POSITION = "getCurrentPosition";
    public static final String METHOD_SET_VOLUME = "setVolume";
    public static final String METHOD_SEEK_TO = "seekTo";
    public static final String METHOD_SET_LOOP = "setLoop";
    public static final String METHOD_SET_SPEED = "setSpeed";
    public static final String METHOD_SNAPSHOT = "snapshot";
    public static final String METHOD_GET_AUDIO_TRACKS = "getAudioTracks";
    public static final String METHOD_SET_AUDIO_TRACK = "setAudioTrack";
    public static final String METHOD_ON_SNAPSHOT = "_onSnapshot";
    public static final String EVENT_PREPARED = "prepared";
    public static final String EVENT_STATE_CHANGE = "state_change";
    public static final String EVENT_RENDERING_START = "rendering_start";
    public static final String EVENT_FREEZE = "freeze";
    public static final String EVENT_BUFFERING = "buffering";
    public static final String EVENT_POS = "pos";
    public static final String EVENT_ROTATE = "rotate";
    public static final String EVENT_SIZE_CHANGED = "size_changed";
    public static final String EVENT_SEEK_COMPLETE = "seek_complete";
    public static final String EVENT_ERROR = "error";
    public static final String EVENT_VOLUME = "volume";
    public static final int STATE_IDLE = 0;
    public static final int STATE_INITIALIZED = 1;
    public static final int STATE_ASYNC_PREPARING = 2;
    public static final int STATE_PREPARED = 3;
    public static final int STATE_STARTED = 4;
    public static final int STATE_PAUSED = 5;
    public static final int STATE_COMPLETED = 6;
    public static final int STATE_STOPPED = 7;
    public static final int STATE_ERROR = 8;
    public static final int STATE_END = 9;
}
