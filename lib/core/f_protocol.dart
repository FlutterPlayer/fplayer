// GENERATED CODE - DO NOT EDIT.
// Run: dart run tool/generate_protocol.dart

part of fplayer;

class FProtocol {
  const FProtocol._();

  static const String pluginChannel = 'fplayer.dev/fplayer';
  static const String pluginEventChannel = 'fplayer.dev/fplayer/event';
  static const String platformChannel = 'fplayer.dev/fplayer/platform';
  static const String playerChannelPrefix = 'fplayer.dev/fplayer/';
  static const String playerEventChannelPrefix = 'fplayer.dev/fplayer/event/';

  static String playerChannel(int id) =>
      '$playerChannelPrefix$id';

  static String playerEventChannel(int id) =>
      '$playerEventChannelPrefix$id';

  static const String methodGetPlatformVersion = 'getPlatformVersion';
  static const String methodInit = 'init';
  static const String methodCreatePlayer = 'createPlayer';
  static const String methodReleasePlayer = 'releasePlayer';
  static const String methodLogLevel = 'logLevel';
  static const String methodSetOrientationPortrait = 'setOrientationPortrait';
  static const String methodSetOrientationLandscape = 'setOrientationLandscape';
  static const String methodSetOrientationAuto = 'setOrientationAuto';
  static const String methodSetScreenOn = 'setScreenOn';
  static const String methodIsScreenKeptOn = 'isScreenKeptOn';
  static const String methodBrightness = 'brightness';
  static const String methodSetBrightness = 'setBrightness';
  static const String methodVolumeUp = 'volumeUp';
  static const String methodVolumeDown = 'volumeDown';
  static const String methodVolumeMute = 'volumeMute';
  static const String methodVolumeSet = 'volumeSet';
  static const String methodSystemVolume = 'systemVolume';
  static const String methodVolUiMode = 'volUiMode';
  static const String methodOnLoad = 'onLoad';
  static const String methodOnUnload = 'onUnload';
  static const String methodRequestAudioFocus = 'requestAudioFocus';
  static const String methodReleaseAudioFocus = 'releaseAudioFocus';
  static const String methodGetBatteryInfo = 'getBatteryInfo';
  static const String methodSetupSurface = 'setupSurface';
  static const String methodSetOption = 'setOption';
  static const String methodApplyOptions = 'applyOptions';
  static const String methodSetDataSource = 'setDataSource';
  static const String methodPrepareAsync = 'prepareAsync';
  static const String methodStart = 'start';
  static const String methodPause = 'pause';
  static const String methodStop = 'stop';
  static const String methodReset = 'reset';
  static const String methodGetCurrentPosition = 'getCurrentPosition';
  static const String methodSetVolume = 'setVolume';
  static const String methodSeekTo = 'seekTo';
  static const String methodSetLoop = 'setLoop';
  static const String methodSetSpeed = 'setSpeed';
  static const String methodSnapshot = 'snapshot';
  static const String methodGetAudioTracks = 'getAudioTracks';
  static const String methodSetAudioTrack = 'setAudioTrack';
  static const String methodOnSnapshot = '_onSnapshot';
  static const String eventPrepared = 'prepared';
  static const String eventStateChange = 'state_change';
  static const String eventRenderingStart = 'rendering_start';
  static const String eventFreeze = 'freeze';
  static const String eventBuffering = 'buffering';
  static const String eventPos = 'pos';
  static const String eventRotate = 'rotate';
  static const String eventSizeChanged = 'size_changed';
  static const String eventSeekComplete = 'seek_complete';
  static const String eventError = 'error';
  static const String eventVolume = 'volume';
  static const int stateIdle = 0;
  static const int stateInitialized = 1;
  static const int stateAsyncPreparing = 2;
  static const int statePrepared = 3;
  static const int stateStarted = 4;
  static const int statePaused = 5;
  static const int stateCompleted = 6;
  static const int stateStopped = 7;
  static const int stateError = 8;
  static const int stateEnd = 9;
}
