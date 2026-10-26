part of fplayer;

@immutable
class FVolumeEvent {
  final double vol;
  final bool sui;
  final int type;

  const FVolumeEvent({
    required this.vol,
    required this.sui,
    required this.type,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FVolumeEvent &&
          vol == other.vol &&
          sui == other.sui &&
          type == other.type);

  @override
  int get hashCode => Object.hash(vol, sui, type);
}

class _VolumeValueNotifier extends ValueNotifier<FVolumeEvent> {
  _VolumeValueNotifier(FVolumeEvent value) : super(value);
}

class FVolume {
  FVolume._();

  static const int STREAM_VOICE_CALL = 0;
  static const int STREAM_SYSTEM = 1;
  static const int STREAM_RING = 2;
  static const int STREAM_MUSIC = 3;
  static const int STREAM_ALARM = 4;

  /// show system volume changed UI if no playable player.
  /// hide system volume changed UI if some players are in playable state.
  static const int hideUIWhenPlayable = 0;

  /// show system volume changed UI if no start state player.
  /// hide system volume changed UI if some players are in start state.
  static const int hideUIWhenPlaying = 1;

  /// never show system volume changed UI.
  static const int neverShowUI = 2;

  /// always show system volume changed UI
  static const int alwaysShowUI = 3;

  static final FVolume _instance = FVolume._();

  static final _VolumeValueNotifier _notifier =
      _VolumeValueNotifier(const FVolumeEvent(vol: 0, sui: false, type: 0));

  static const double _defaultStep = 1.0 / 16.0;
  static int _listenerCount = 0;

  /// Mute system volume.
  /// return system volume after mute
  static Future<double> mute() async {
    if (!FPlugin.supportsSystemVolume) return Future.value(0);
    var vol = await FPlugin._channel.invokeMethod(FProtocol.methodVolumeMute);
    if (vol != null) return Future.value(vol);
    return Future.value(0);
  }

  /// set system volume to [vol].
  /// the range of [vol] is [0.0, 1,0].
  /// return the system volume value after set.
  static Future<double> setVol(double vol) async {
    if (vol < 0.0 || vol > 1.0) {
      return Future.error(ArgumentError.value(
          vol, "step must be not null and in range [0.0, 1.0]"));
    } else if (!FPlugin.supportsSystemVolume) {
      return Future.value(vol);
    } else {
      var afterSet = await FPlugin._channel
          .invokeMethod(FProtocol.methodVolumeSet, <String, dynamic>{'vol': vol});
      if (afterSet != null) return Future.value(afterSet);
      return Future.value(vol);
    }
  }

  /// get ths current system volume.
  /// the range of returned value is [0.0, 1.0].
  static Future<double> getVol() async {
    if (!FPlugin.supportsSystemVolume) return Future.value(0);
    var vol = await FPlugin._channel.invokeMethod(FProtocol.methodSystemVolume);
    if (vol != null) return Future.value(vol);
    return Future.value(0);
  }

  /// increase system volume by step, step must be in range [0.0, 1.0].
  /// return the system volume value after increase.
  /// the return volume value may be not equals to the current volume + step.
  static Future<double> up({double step = _defaultStep}) async {
    if (step < 0.0 || step > 1.0) {
      return Future.error(ArgumentError.value(
          step, "step must be not null and in range [0.0, 1.0]"));
    } else if (!FPlugin.supportsSystemVolume) {
      return Future.value(0);
    } else {
      var vol = await FPlugin._channel
          .invokeMethod(FProtocol.methodVolumeUp, <String, dynamic>{'step': step});
      if (vol != null) return Future.value(vol);
      return Future.value(0);
    }
  }

  /// decrease system volume by step, step must be in range [0.0, 1.0].
  /// return the system volume value after decrease.
  /// the return volume value may be not equals to the current volume - step.
  static Future<double> down({double step = _defaultStep}) async {
    if (step < 0.0 || step > 1.0) {
      return Future.error(ArgumentError.value(
          step, "step must be not null and in range [0.0, 1.0]"));
    } else if (!FPlugin.supportsSystemVolume) {
      return Future.value(0);
    } else {
      var vol = await FPlugin._channel
          .invokeMethod(FProtocol.methodVolumeDown, <String, dynamic>{'step': step});
      if (vol != null) return Future.value(vol);
      return Future.value(0);
    }
  }

  /// update the ui mode when system volume changing.
  /// mode can be one of
  /// {[hideUIWhenPlayable], [hideUIWhenPlaying], [neverShowUI], [alwaysShowUI]}
  static Future<void> setUIMode(int mode) {
    if (mode < hideUIWhenPlayable || mode > alwaysShowUI) {
      return Future.error(ArgumentError.value(mode, "mode"));
    } else if (!FPlugin.supportsSystemVolume) {
      return Future.value();
    } else {
      return FPlugin._channel
          .invokeMethod(FProtocol.methodVolUiMode, <String, dynamic>{'mode': mode});
    }
  }

  void _onVolCallback(double vol, bool ui) {
    _notifier.value = FVolumeEvent(vol: vol, sui: ui, type: STREAM_MUSIC);
  }

  /// the [listener] wiil be nitified after system volume changed.
  /// the value after change can be obtained through [FVolume.value]
  static void addListener(VoidCallback listener) {
    if (!FPlugin.supportsSystemVolume) return;
    if (_listenerCount == 0) {
      FPlugin._onLoad("vol");
    }
    _listenerCount++;
    _notifier.addListener(listener);
  }

  /// remove the [listener] set using [addListener]
  static void removeListener(VoidCallback listener) {
    _notifier.removeListener(listener);
    if (!FPlugin.supportsSystemVolume || _listenerCount == 0) return;
    _listenerCount--;
    if (_listenerCount == 0) {
      FPlugin._onUnload();
    }
  }

  /// get the system volume event.
  /// a valid value is returned only if [addListener] is called and there's really volume changing
  static FVolumeEvent get value => _notifier.value;
}
