part of fplayer;

class FPlayer extends ChangeNotifier implements ValueListenable<FValue> {
  static final Map<int, FPlayer> _allInstance = HashMap();
  String? _dataSource;

  int _playerId = -1;
  int _callId = -1;
  late MethodChannel _channel;
  StreamSubscription<dynamic>? _nativeEventSubscription;

  FValue _value;
  bool _released = false;
  bool _disposed = false;

  static Iterable<FPlayer> get all => _allInstance.values;

  /// Return the player unique id.
  ///
  /// Each public method in [FPlayer] `await` the id value firstly.
  Future<int> get id => _nativeSetup.future;

  /// Get is in sync, if the async [id] is not finished, idSync return -1;
  int get idSync => _playerId;

  /// return the current state
  FState get state => _value.state;

  @override
  FValue get value => _value;

  void _setValue(FValue newValue) {
    if (_disposed || _value == newValue) return;
    _value = newValue;
    notifyListeners();
  }

  Duration _bufferPos = const Duration();

  /// return the current buffered position
  Duration get bufferPos => _bufferPos;

  final StreamController<Duration> _bufferPosController =
      StreamController.broadcast();

  /// stream of [bufferPos].
  Stream<Duration> get onBufferPosUpdate => _bufferPosController.stream;

  int _bufferPercent = 0;

  /// return the buffer percent of water mark.
  ///
  /// If player is in [FState.started] state and is freezing ([isBuffering] is true),
  /// this value starts from 0, and when reaches or exceeds 100, the player start to play again.
  ///
  /// This is not the quotient of [bufferPos] / [value.duration]
  int get bufferPercent => _bufferPercent;

  final StreamController<int> _bufferPercentController =
      StreamController.broadcast();

  /// stream of [bufferPercent].
  Stream<int> get onBufferPercentUpdate => _bufferPercentController.stream;

  Duration _currentPos = const Duration();

  /// return the current playing position
  Duration get currentPos => _currentPos;

  final StreamController<Duration> _currentPosController =
      StreamController.broadcast();

  /// stream of [currentPos].
  Stream<Duration> get onCurrentPosUpdate => _currentPosController.stream;

  bool _buffering = false;
  bool _seeking = false;
  Timer? _seekTimeout;

  /// 当前在 Navigator 栈上的全屏路由（由 FView 压入/弹出时维护）。
  /// FView 的 State 可能因页面布局重建（如旋转触发响应式布局）被销毁重建，
  /// 用播放器级引用防止重复压入第二个全屏路由（导致退出全屏需要退两次）。
  TransitionRoute<void>? _fullscreenRoute;

  /// return true if the player is buffering
  bool get isBuffering => _buffering;

  final StreamController<bool> _bufferStateController =
      StreamController.broadcast();

  Stream<bool> get onBufferStateUpdate => _bufferStateController.stream;

  String? get dataSource => _dataSource;

  final Completer<int> _nativeSetup;
  Completer<Uint8List>? _snapShot;

  FPlayer()
      : _nativeSetup = Completer(),
        _value = const FValue.uninitialized(),
        super() {
    FLog.d("create new fplayer");
    _doNativeSetup();
  }

  Future<dynamic> _handler(MethodCall call) {
    switch (call.method) {
      case FProtocol.methodOnSnapshot:
        final img = call.arguments;
        final snapShot = _snapShot;
        _snapShot = null;
        if (snapShot != null && !snapShot.isCompleted) {
          final data = img is Map ? img['data'] : null;
          if (data is Uint8List) {
            snapShot.complete(data);
          } else {
            snapShot.completeError(UnsupportedError("snapshot"));
          }
        }
        break;
      default:
        break;
    }
    return Future.value(0);
  }

  Future<void> _doNativeSetup() async {
    _playerId = -1;
    _callId = 0;
    try {
      _playerId = await FPlugin._createPlayer();
    } catch (error, stackTrace) {
      _setValue(value.copyWith(
        state: FState.error,
        exception: FException(FException.unknown, error.toString()),
      ));
      if (!_nativeSetup.isCompleted) {
        _nativeSetup.completeError(error, stackTrace);
      }
      return;
    }
    if (_playerId < 0) {
      final error = StateError("failed to create native player");
      _setValue(value.copyWith(
        state: FState.error,
        exception: FException(FException.unknown, error.message),
      ));
      if (!_nativeSetup.isCompleted) {
        _nativeSetup.completeError(error);
      }
      return;
    }
    if (_disposed || _released) {
      FPlugin._releasePlayer(_playerId).catchError((Object _) {});
      if (!_nativeSetup.isCompleted) {
        _nativeSetup.completeError(StateError("player disposed during setup"));
      }
      return;
    }
    FLog.i("create player id:$_playerId");

    _allInstance[_playerId] = this;
    _channel = MethodChannel(FProtocol.playerChannel(_playerId));
    _nativeEventSubscription =
        EventChannel(FProtocol.playerEventChannel(_playerId))
            .receiveBroadcastStream()
            .listen(_eventListener, onError: _errorListener);
    _channel.setMethodCallHandler(_handler);
    _nativeSetup.complete(_playerId);
  }

  void _closeControllers() {
    _bufferPosController.close();
    _bufferPercentController.close();
    _currentPosController.close();
    _bufferStateController.close();
  }

  void _disposeLocal() {
    if (_disposed) return;
    _disposed = true;
    _seekTimeout?.cancel();
    _seekTimeout = null;
    _nativeEventSubscription?.cancel();
    _nativeEventSubscription = null;
    _allInstance.remove(_playerId);
    _closeControllers();
  }

  @override
  void dispose() {
    if (_disposed) return;
    final pid = _playerId;
    if (pid >= 0) {
      FPlugin._releasePlayer(pid).catchError((Object _) {});
    }
    _disposeLocal();
    super.dispose();
  }

  /// Check if player is playable
  ///
  /// Only the four state [FState.prepared] \ [FState.started] \
  /// [FState.paused] \ [FState.completed] are playable
  bool isPlayable() {
    FState current = value.state;
    return FState.prepared == current ||
        FState.started == current ||
        FState.paused == current ||
        FState.completed == current;
  }

  /// set option
  /// [value] must be int or String
  Future<void> setOption(int category, String key, dynamic value) async {
    await _nativeSetup.future;
    if (value is String) {
      FLog.i("$this setOption k:$key, v:$value");
      return _channel.invokeMethod(FProtocol.methodSetOption,
          <String, dynamic>{"cat": category, "key": key, "str": value});
    } else if (value is int) {
      FLog.i("$this setOption k:$key, v:$value");
      return _channel.invokeMethod(FProtocol.methodSetOption,
          <String, dynamic>{"cat": category, "key": key, "long": value});
    } else {
      FLog.e("$this setOption invalid value: $value");
      return Future.error(
          ArgumentError.value(value, "value", "Must be int or String"));
    }
  }

  Future<void> applyOptions(FOption fOption) async {
    await _nativeSetup.future;
    return _channel.invokeMethod(FProtocol.methodApplyOptions, fOption.data);
  }

  Future<int?> setupSurface() async {
    await _nativeSetup.future;
    FLog.i("$this setupSurface");
    return _channel.invokeMethod(FProtocol.methodSetupSurface);
  }

  /// Take snapshot (screen shot) of current playing video
  ///
  /// If you want to use [takeSnapshot], you must call
  /// `player.setOption(FOption.hostCategory, "enable-snapshot", 1);`
  /// after you create a [FPlayer].
  /// Or else this method returns error.
  ///
  /// Example:
  /// ```
  /// var imageData = await player.takeSnapShot();
  /// var provider = MemoryImage(v);
  /// Widget image = Image(image: provider)
  /// ```
  Future<Uint8List> takeSnapShot() async {
    await _nativeSetup.future;
    FLog.i("$this takeSnapShot");
    var snapShot = _snapShot;
    if (snapShot != null && !snapShot.isCompleted) {
      return Future.error(StateError("last snapShot is not finished"));
    }
    snapShot = Completer<Uint8List>();
    _snapShot = snapShot;
    try {
      await _channel.invokeMethod(FProtocol.methodSnapshot);
      return await snapShot.future.timeout(const Duration(seconds: 10));
    } catch (error) {
      if (!snapShot.isCompleted) {
        snapShot.completeError(error);
      }
      rethrow;
    } finally {
      if (identical(_snapShot, snapShot)) {
        _snapShot = null;
      }
    }
  }

  /// Set data source for this player
  ///
  /// [path] must be a valid uri, otherwise this method return ArgumentError
  ///
  /// set assets as data source
  /// first add assets in app's pubspec.yml
  ///   assets:
  ///     - assets/butterfly.mp4
  ///
  /// pass "asset:///assets/butterfly.mp4" to [path]
  /// scheme is `asset`, `://` is scheme's separator， `/` is path's separator.
  ///
  /// [headers] http header
  /// If set [autoPlay] true, player will stat to play.
  /// The behavior of [setDataSource(url, autoPlay: true)] is like
  ///    await setDataSource(url);
  ///    await setOption(FOption.playerCategory, "start-on-prepared", 1);
  ///    await prepareAsync();
  ///
  /// If set [showCover] true, player will display the first video frame and then enter [FState.paused] state.
  /// The behavior of [setDataSource(url, showCover: true)] is like
  ///    await setDataSource(url);
  ///    await setOption(FOption.playerCategory, "cover-after-prepared", 1);
  ///    await prepareAsync();
  ///
  /// If both [autoPlay] and [showCover] are true, [showCover] will be ignored.
  Future<void> setDataSource(
    String path, {
    Map<String, String?>? headers,
    bool autoPlay = false,
    bool showCover = false,
  }) async {
    if (path.isEmpty || Uri.tryParse(path) == null) {
      FLog.e("$this setDataSource invalid path:$path");
      return Future.error(
          ArgumentError.value(path, "path must be a valid url"));
    }
    if (autoPlay == true && showCover == true) {
      FLog.w(
          "call setDataSource with both autoPlay and showCover true, showCover will be ignored");
    }
    await _nativeSetup.future;
    if (state == FState.idle || state == FState.initialized) {
      try {
        FLog.i("$this invoke setDataSource $path");
        _dataSource = path;
        await _channel.invokeMethod(FProtocol.methodSetDataSource,
            <String, dynamic>{'url': path});
      } on PlatformException catch (e) {
        return _errorListener(e);
      }
      if (headers != null && headers.isNotEmpty) {
        final headersStr = headers.entries
            .map((entry) => '${entry.key}: ${entry.value ?? ''}')
            .join('\r\n');
        await setOption(FOption.formatCategory, 'headers', headersStr);
      }
      if (autoPlay == true) {
        await start();
      } else if (showCover == true) {
        await setOption(FOption.playerCategory, "cover-after-prepared", 1);
        await prepareAsync();
      }
    } else {
      FLog.e("$this setDataSource invalid state:$state");
      return Future.error(StateError("setDataSource on invalid state $state"));
    }
  }

  /// start the async preparing tasks
  ///
  /// see [fstate zh](https://fplayer.dev/basic/status.html) for details
  Future<void> prepareAsync() async {
    await _nativeSetup.future;
    if (state == FState.initialized) {
      FLog.i("$this invoke prepareAsync");
      await _channel.invokeMethod(FProtocol.methodPrepareAsync);
    } else {
      FLog.e("$this prepareAsync invalid state:$state");
      return Future.error(StateError("prepareAsync on invalid state $state"));
    }
  }

  /// set volume of this player audio track
  ///
  /// This dose not change system volume.
  /// Default value of audio track is 1.0,
  /// [volume] must be greater or equals to 0.0
  Future<void> setVolume(double volume) async {
    if (volume < 0) {
      FLog.e("$this invoke seekTo invalid volume:$volume");
      return Future.error(
          ArgumentError.value(volume, "setVolume invalid volume"));
    } else {
      await _nativeSetup.future;
      FLog.i("$this invoke setVolume $volume");
      return _channel
          .invokeMethod(FProtocol.methodSetVolume, <String, dynamic>{"volume": volume});
    }
  }

  /// enter full screen mode, set [FValue.fullScreen] to true
  void enterFullScreen() {
    FLog.i("$this enterFullScreen");
    _setValue(value.copyWith(fullScreen: true));
  }

  /// exit full screen mode, set [FValue.fullScreen] to false
  void exitFullScreen() {
    FLog.i("$this exitFullScreen");
    _setValue(value.copyWith(fullScreen: false));
  }

  /// change player's state to [FState.started]
  ///
  /// throw [StateError] if call this method on invalid state.
  /// see [fstate zh](https://fplayer.dev/basic/status.html) for details
  Future<void> start() async {
    await _nativeSetup.future;
    if (state == FState.initialized) {
      _callId += 1;
      int cid = _callId;
      FLog.i("$this invoke prepareAsync and start #$cid");
      await setOption(FOption.playerCategory, "start-on-prepared", 1);
      await _channel.invokeMethod(FProtocol.methodPrepareAsync);
      FLog.i("$this invoke prepareAsync and start #$cid -> done");
    } else if (state == FState.asyncPreparing ||
        state == FState.prepared ||
        state == FState.paused ||
        state == FState.started ||
        state == FState.completed) {
      FLog.i("$this invoke start");
      await _channel.invokeMethod(FProtocol.methodStart);
    } else {
      FLog.e("$this invoke start invalid state:$state");
      return Future.error(StateError("call start on invalid state $state"));
    }
  }

  Future<void> pause() async {
    await _nativeSetup.future;
    if (isPlayable()) {
      FLog.i("$this invoke pause");
      await _channel.invokeMethod(FProtocol.methodPause);
    } else {
      FLog.e("$this invoke pause invalid state:$state");
      return Future.error(StateError("call pause on invalid state $state"));
    }
  }

  Future<void> stop() async {
    await _nativeSetup.future;
    if (state == FState.end ||
        state == FState.idle ||
        state == FState.initialized) {
      FLog.e("$this invoke stop invalid state:$state");
      return Future.error(StateError("call stop on invalid state $state"));
    } else {
      FLog.i("$this invoke stop");
      await _channel.invokeMethod(FProtocol.methodStop);
    }
  }

  Future<void> reset() async {
    await _nativeSetup.future;
    if (state == FState.end) {
      FLog.e("$this invoke reset invalid state:$state");
      return Future.error(StateError("call reset on invalid state $state"));
    } else {
      _callId += 1;
      int cid = _callId;
      FLog.i("$this invoke reset #$cid");
      await _channel.invokeMethod(FProtocol.methodReset).then((_) {
        FLog.i("$this invoke reset #$cid -> done");
      });
      _seeking = false;
      _seekTimeout?.cancel();
      _seekTimeout = null;
      _buffering = false;
      _bufferPercent = 0;
      _bufferPos = const Duration();
      _currentPos = const Duration();
      _setValue(FValue.uninitialized().copyWith(fullScreen: value.fullScreen));
    }
  }

  Future<void> seekTo(int msec) async {
    await _nativeSetup.future;
    if (msec < 0) {
      FLog.e("$this invoke seekTo invalid msec:$msec");
      return Future.error(
          ArgumentError.value(msec, "speed must be not null and >= 0"));
    } else if (!isPlayable()) {
      FLog.e("$this invoke seekTo invalid state:$state");
      return Future.error(StateError("Non playable state $state"));
    } else {
      FLog.i("$this invoke seekTo msec:$msec");
      _seeking = true;
      _seekTimeout?.cancel();
      _seekTimeout = Timer(const Duration(seconds: 10), () {
        if (!_disposed) {
          _seeking = false;
        }
      });
      _channel.invokeMethod(FProtocol.methodSeekTo, <String, dynamic>{"msec": msec});
    }
  }

  /// Release native player. Release memory and resource
  Future<void> release() async {
    if (_released || _disposed) return;
    _released = true;

    int pid = -1;
    try {
      pid = await _nativeSetup.future;
    } catch (error) {
      FLog.e("$this release before native setup completed: $error");
    }

    _callId += 1;
    int cid = _callId;
    FLog.i("$this invoke release #$cid");

    if (pid >= 0) {
      if (isPlayable()) {
        try {
          await stop();
        } catch (error) {
          FLog.w("$this stop before release failed: $error");
        }
      }
      _setValue(value.copyWith(state: FState.end));
      await FPlugin._releasePlayer(pid).then((_) {
        FLog.i("$this invoke release #$cid -> done");
      }).catchError((Object error) {
        FLog.w("$this release native player failed: $error");
      });
    }

    _disposeLocal();
    super.dispose();
  }

  /// Set player loop count
  ///
  /// [loopCount] must not null and greater than or equal to 0.
  /// Default loopCount of player is 1, which also means no loop.
  /// A positive value of [loopCount] means special repeat times.
  /// If [loopCount] is 0, is means infinite repeat.
  Future<void> setLoop(int loopCount) async {
    await _nativeSetup.future;
    if (loopCount < 0) {
      FLog.e("$this invoke setLoop invalid loopCount:$loopCount");
      return Future.error(ArgumentError.value(
          loopCount, "loopCount must not be null and >= 0"));
    } else {
      FLog.i("$this invoke setLoop $loopCount");
      return _channel
          .invokeMethod(FProtocol.methodSetLoop, <String, dynamic>{"loop": loopCount});
    }
  }

  /// Set playback speed
  ///
  /// [speed] must not null and greater than 0.
  /// Default speed is 1
  Future<void> setSpeed(double speed) async {
    await _nativeSetup.future;
    if (speed <= 0) {
      FLog.e("$this invoke setSpeed invalid speed:$speed");
      return Future.error(ArgumentError.value(
          speed, "speed must be not null and greater than 0"));
    } else {
      FLog.i("$this invoke setSpeed $speed");
      _channel.invokeMethod(FProtocol.methodSetSpeed, <String, dynamic>{"speed": speed});
    }
  }

  void _eventListener(dynamic event) {
    if (_disposed) return;
    final Map<dynamic, dynamic> map = event;
    switch (map['event']) {
      case FProtocol.eventPrepared:
        int duration = map['duration'] ?? 0;
        Duration dur = Duration(milliseconds: duration);
        _setValue(value.copyWith(duration: dur, prepared: true));
        FLog.i("$this prepared duration $dur");
        break;
      case FProtocol.eventRotate:
        int degree = map['degree'] ?? 0;
        _setValue(value.copyWith(rotate: degree));
        FLog.i("$this rotate degree $degree");
        break;
      case FProtocol.eventStateChange:
        final newStateId = map['new'] is int ? map['new'] as int : -1;
        final oldStateId = map['old'] is int ? map['old'] as int : -1;
        if (newStateId < 0 || newStateId >= FState.values.length) {
          FLog.w("$this ignore unknown native state: $newStateId");
          break;
        }
        final fpState = FState.values[newStateId];
        final oldState = (oldStateId >= 0 && oldStateId < FState.values.length)
            ? FState.values[oldStateId]
            : state;

        if (fpState != oldState) {
          FLog.i("$this state changed to $fpState <= $oldState");
          final fException =
              (fpState != FState.error) ? FException.noException : null;
          if (newStateId == FState.prepared.index) {
            _setValue(value.copyWith(
                prepared: true, state: fpState, exception: fException));
          } else if (newStateId < FState.prepared.index ||
              fpState == FState.error) {
            _setValue(value.copyWith(
                prepared: false, state: fpState, exception: fException));
          } else {
            _setValue(value.copyWith(state: fpState, exception: fException));
          }
        }
        break;
      case FProtocol.eventRenderingStart:
        String type = map['type'] ?? "none";
        if (type == "video") {
          _setValue(value.copyWith(videoRenderStart: true));
          FLog.i("$this video rendering started");
        } else if (type == "audio") {
          _setValue(value.copyWith(audioRenderStart: true));
          FLog.i("$this audio rendering started");
        }
        break;
      case FProtocol.eventFreeze:
        bool value = map['value'] ?? false;
        _buffering = value;
        _bufferStateController.add(value);
        FLog.d("$this freeze ${value ? "start" : "end"}");
        break;
      case FProtocol.eventBuffering:
        int head = map['head'] ?? 0;
        int percent = map['percent'] ?? 0;
        _bufferPos = Duration(milliseconds: head);
        _bufferPosController.add(_bufferPos);
        _bufferPercent = percent;
        _bufferPercentController.add(percent);
        break;
      case FProtocol.eventPos:
        final pos = map['pos'];
        if (pos is num) {
          _currentPos = Duration(milliseconds: pos.toInt());
          if (!_seeking) {
            _currentPosController.add(_currentPos);
          }
        }
        break;
      case FProtocol.eventSizeChanged:
        final width = map['width'];
        final height = map['height'];
        if (width is num && height is num) {
          final size = Size(width.toDouble(), height.toDouble());
          FLog.i("$this size changed ($size)");
          _setValue(value.copyWith(size: size));
        }
        break;
      case FProtocol.eventSeekComplete:
        _seeking = false;
        _seekTimeout?.cancel();
        _seekTimeout = null;
        break;
      default:
        break;
    }
  }

  void _errorListener(Object obj) {
    if (_disposed) return;
    if (obj is! PlatformException) {
      FLog.e("$this errorListener: $obj");
      _setValue(value.copyWith(
        prepared: false,
        exception: FException(FException.unknown, obj.toString()),
      ));
      return;
    }
    final exception = FException.fromPlatformException(obj);
    FLog.e("$this errorListener: $exception");
    _setValue(value.copyWith(prepared: false, exception: exception));
  }

  @override
  String toString() {
    return 'FPlayer{id:$_playerId}';
  }
}
