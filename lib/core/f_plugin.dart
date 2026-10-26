part of fplayer;

class FBatteryInfo {
  const FBatteryInfo(this.level, this.charging);

  final int level;
  final bool charging;
}

class FPlugin {
  /// Make constructor private
  const FPlugin._();

  static const MethodChannel _channel = MethodChannel(FProtocol.pluginChannel);

  static Future<int> _createPlayer() async {
    int? pid = await _channel.invokeMethod(FProtocol.methodCreatePlayer);
    if (pid != null) {
      return Future.value(pid);
    }
    FLog.e("failed to create native player");
    return Future.value(-1);
  }

  static Future<void> _releasePlayer(int pid) {
    return _channel
        .invokeMethod(FProtocol.methodReleasePlayer, <String, dynamic>{'pid': pid});
  }

  static bool isDesktop() {
    return Platform.isWindows ||
        Platform.isMacOS ||
        Platform.isLinux ||
        Platform.isFuchsia;
  }

  /// Whether the native implementation exposes system volume APIs.
  static bool get supportsSystemVolume =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  /// Whether the native implementation exposes screen related APIs.
  static bool get supportsScreenControls =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  static bool get _supportsNativeLogLevel =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  /// Only works on Android and iOS
  static Future<bool> setOrientationPortrait() async {
    if (isDesktop()) return Future<bool>.value(true);
    // ios crash Supported orientations has no common orientation with the application
    bool? changed = await _channel.invokeMethod(FProtocol.methodSetOrientationPortrait);
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    return Future.value(changed);
  }

  /// Only works on Android and iOS
  /// return false if current orientation is landscape
  /// return true if current orientation is portrait and after this API
  /// call finished, the orientation becomes landscape.
  /// return false if can't change orientation.
  static Future<bool> setOrientationLandscape() async {
    if (isDesktop()) return Future.value(false);
    bool? changed = await _channel.invokeMethod(FProtocol.methodSetOrientationLandscape);
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeRight, DeviceOrientation.landscapeLeft]);
    return Future.value(changed);
  }

  static Future<void> setOrientationAuto() {
    if (isDesktop()) return Future.value();
    if (Platform.isAndroid) {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    return _channel.invokeMethod(FProtocol.methodSetOrientationAuto);
  }

  /// Works on Android and iOS
  /// Keep screen on or not
  static Future<void> keepScreenOn(bool on) {
    if (supportsScreenControls) {
      FLog.i("keepScreenOn :$on");
      return _channel.invokeMethod(FProtocol.methodSetScreenOn, <String, dynamic>{'on': on});
    }
    return Future.value();
  }

  /// Check if screen is kept on
  static Future<bool> isScreenKeptOn() async {
    if (supportsScreenControls) {
      var keptOn = await _channel.invokeMethod(FProtocol.methodIsScreenKeptOn);
      if (keptOn != null) {
        return Future.value(keptOn);
      }
    }
    return Future.value(false);
  }

  /// Set screen brightness.
  /// The range of [value] is [0.0, 1.0]
  static Future<void> setScreenBrightness(double value) {
    if (value < 0.0 || value > 1.0) {
      return Future.error(ArgumentError.value(
          value, "brightness value must be not null and in range [0.0, 1.0]"));
    } else if (supportsScreenControls) {
      return _channel.invokeMethod(
          FProtocol.methodSetBrightness, <String, dynamic>{'brightness': value});
    }
    return Future.value();
  }

  /// Get the screen brightness.
  /// The range of returned value is [0.0, 1.0]
  static Future<double> screenBrightness() async {
    if (supportsScreenControls) {
      var brightness = await _channel.invokeMethod(FProtocol.methodBrightness);
      if (brightness != null) return Future.value(brightness);
    }
    return Future.value(0);
  }

  /// Only works on Android
  /// request audio focus for media usage
  static Future<void> requestAudioFocus() {
    if (Platform.isAndroid) {
      return _channel.invokeMethod(FProtocol.methodRequestAudioFocus);
    }
    return Future.value();
  }

  /// Only works on Android
  /// release audio focus
  static Future<void> releaseAudioFocus() {
    if (Platform.isAndroid) {
      return _channel.invokeMethod(FProtocol.methodReleaseAudioFocus);
    }
    return Future.value();
  }

  static Future<FBatteryInfo?> getBatteryInfo() async {
    final result = await _channel
        .invokeMapMethod<String, dynamic>(FProtocol.methodGetBatteryInfo);
    if (result == null) return null;
    final level = result['level'];
    return FBatteryInfo(
      level is int ? level : 0,
      result['charging'] == true,
    );
  }

  static Future<void> _setLogLevel(int level) {
    if (!_supportsNativeLogLevel) return Future.value();
    return _channel.invokeMethod(FProtocol.methodLogLevel, <String, dynamic>{'level': level});
  }

  static StreamSubscription? _eventSubs;
  static bool _eventListening = false;

  static void _onLoad(String type) {
    if (_eventListening) return;
    _eventListening = true;
    FLog.i("_onLoad $type");
    _eventSubs ??= const EventChannel(FProtocol.pluginEventChannel)
        .receiveBroadcastStream()
        .listen(FPlugin._eventListener, onError: FPlugin._errorListener);
    _channel.invokeMethod(FProtocol.methodOnLoad).catchError((Object error) {
      FLog.w("_onLoad failed: $error");
    });
  }

  static void _onUnload() {
    if (!_eventListening) return;
    _eventListening = false;
    FLog.i("_onUnload");
    _channel.invokeMethod(FProtocol.methodOnUnload).catchError((Object error) {
      FLog.w("_onUnload failed: $error");
    });
    _eventSubs?.cancel();
    _eventSubs = null;
  }

  static void _eventListener(dynamic event) {
    final Map<dynamic, dynamic> map = event;
    FLog.d("plugin listener: $map");
    switch (map['event']) {
      case FProtocol.eventVolume:
        bool sui = map['sui'] ?? false;
        double vol = map['vol'] ?? 0.0;
        FVolume._instance._onVolCallback(vol, sui);
        break;
      default:
        break;
    }
  }

  static void _errorListener(Object obj) {
    FLog.e("plugin errorListerner: $obj");
  }
}
