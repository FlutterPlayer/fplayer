part of fplayer;

class FPlayer extends ChangeNotifier implements ValueListenable<FValue> {
  static final Map<int, FPlayer> _allInstance = HashMap();
  String? _dataSource;

  int _playerId = -1;
  int _callId = -1;
  late MethodChannel _channel;
  StreamSubscription<dynamic>? _nativeEventSubscription;

  final bool _startAfterSetup = false;

  FValue _value;

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
    if (_value == newValue) return;
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

  Future<void> _startFromAnyState() async {
    await _nativeSetup.future;

    if (state == FState.error || state == FState.stopped) {
      await reset();
    }
    String? source = _dataSource;
    if (state == FState.idle && source != null) {
      await setDataSource(source);
    }
    if (state == FState.initialized) {
      await prepareAsync();
    }
    if (state == FState.asyncPreparing ||
        state == FState.prepared ||
        state == FState.completed ||
        state == FState.paused) {
      await start();
    }
  }

  Future<dynamic> _handler(MethodCall call) {
    switch (call.method) {
      case "_onSnapshot":
        var img = call.arguments;
        var snapShot = _snapShot;
        if (snapShot != null) {
          if (img is Map) {
            snapShot.complete(img['data']);
          } else {
            snapShot.completeError(UnsupportedError("snapshot"));
          }
        }
        _snapShot = null;
        break;
      default:
        break;
    }
    return Future.value(0);
  }

  Future<void> _doNativeSetup() async {
    _playerId = -1;
    _callId = 0;
    _playerId = await FPlugin._createPlayer();
    if (_playerId < 0) {
      _setValue(value.copyWith(state: FState.error));
      return;
    }
    FLog.i("create player id:$_playerId");

    _allInstance[_playerId] = this;
    _channel = MethodChannel('befovy.com/fijkplayer/$_playerId');
    _nativeEventSubscription =
        EventChannel('befovy.com/fijkplayer/event/$_playerId')
            .receiveBroadcastStream()
            .listen(_eventListener, onError: _errorListener);
    _nativeSetup.complete(_playerId);

    _channel.setMethodCallHandler(_handler);
    if (_startAfterSetup) {
      FLog.i("player id:$_playerId, start after setup");
      await _startFromAnyState();
    }
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
      return _channel.invokeMethod("setOption",
          <String, dynamic>{"cat": category, "key": key, "str": value});
    } else if (value is int) {
      FLog.i("$this setOption k:$key, v:$value");
      return _channel.invokeMethod("setOption",
          <String, dynamic>{"cat": category, "key": key, "long": value});
    } else {
      FLog.e("$this setOption invalid value: $value");
      return Future.error(
          ArgumentError.value(value, "value", "Must be int or String"));
    }
  }

  Future<void> applyOptions(FOption fOption) async {
    await _nativeSetup.future;
    return _channel.invokeMethod("applyOptions", fOption.data);
  }

  Future<int?> setupSurface() async {
    await _nativeSetup.future;
    FLog.i("$this setupSurface");
    return _channel.invokeMethod("setupSurface");
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
    _channel.invokeMethod("snapshot");
    return snapShot.future;
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
  ///
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
        await _channel
            .invokeMethod("setDataSource", <String, dynamic>{'url': path});
      } on PlatformException catch (e) {
        return _errorListener(e);
      }
      if (headers != null) {
        String headersStr = '';
        headers.forEach((key, value) {
          if (headersStr.isNotEmpty) {
            headersStr = '\r\n$headersStr';
          }
          headersStr = '$key: ${value ?? ''}$headersStr';
        });
        setOption(FOption.formatCategory, 'headers', headersStr);
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
      await _channel.invokeMethod("prepareAsync");
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
          .invokeMethod("setVolume", <String, dynamic>{"volume": volume});
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
      await _channel.invokeMethod("prepareAsync");
      FLog.i("$this invoke prepareAsync and start #$cid -> done");
    } else if (state == FState.asyncPreparing ||
        state == FState.prepared ||
        state == FState.paused ||
        state == FState.started ||
        value.state == FState.completed) {
      FLog.i("$this invoke start");
      await _channel.invokeMethod("start");
    } else {
      FLog.e("$this invoke start invalid state:$state");
      return Future.error(StateError("call start on invalid state $state"));
    }
  }

  Future<void> pause() async {
    await _nativeSetup.future;
    if (isPlayable()) {
      FLog.i("$this invoke pause");
      await _channel.invokeMethod("pause");
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
      await _channel.invokeMethod("stop");
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
      await _channel.invokeMethod("reset").then((_) {
        FLog.i("$this invoke reset #$cid -> done");
      });
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
      _channel.invokeMethod("seekTo", <String, dynamic>{"msec": msec});
    }
  }

  /// Release native player. Release memory and resource
  Future<void> release() async {
    await _nativeSetup.future;
    _callId += 1;
    int cid = _callId;
    FLog.i("$this invoke release #$cid");
    if (isPlayable()) await stop();
    _setValue(value.copyWith(state: FState.end));
    await _nativeEventSubscription?.cancel();
    _nativeEventSubscription = null;
    _allInstance.remove(_playerId);
    await FPlugin._releasePlayer(_playerId).then((_) {
      FLog.i("$this invoke release #$cid -> done");
    });
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
          .invokeMethod("setLoop", <String, dynamic>{"loop": loopCount});
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
      _channel.invokeMethod("setSpeed", <String, dynamic>{"speed": speed});
    }
  }

  void _eventListener(dynamic event) {
    final Map<dynamic, dynamic> map = event;
    switch (map['event']) {
      case 'prepared':
        int duration = map['duration'] ?? 0;
        Duration dur = Duration(milliseconds: duration);
        _setValue(value.copyWith(duration: dur, prepared: true));
        FLog.i("$this prepared duration $dur");
        break;
      case 'rotate':
        int degree = map['degree'] ?? 0;
        _setValue(value.copyWith(rotate: degree));
        FLog.i("$this rotate degree $degree");
        break;
      case 'state_change':
        int newStateId = map['new'] ?? 0;
        int _oldState = map['old'] ?? 0;
        FState fpState = FState.values[newStateId];
        FState oldState = (_oldState >= 0 && _oldState < FState.values.length)
            ? FState.values[_oldState]
            : state;

        if (fpState != oldState) {
          FLog.i("$this state changed to $fpState <= $oldState");
          FException? fException =
              (fpState != FState.error) ? FException.noException : null;
          if (newStateId == FState.prepared.index) {
            _setValue(value.copyWith(
                prepared: true, state: fpState, exception: fException));
          } else if (newStateId < FState.prepared.index) {
            _setValue(value.copyWith(
                prepared: false, state: fpState, exception: fException));
          } else {
            _setValue(value.copyWith(state: fpState, exception: fException));
          }
        }
        break;
      case 'rendering_start':
        String type = map['type'] ?? "none";
        if (type == "video") {
          _setValue(value.copyWith(videoRenderStart: true));
          FLog.i("$this video rendering started");
        } else if (type == "audio") {
          _setValue(value.copyWith(audioRenderStart: true));
          FLog.i("$this audio rendering started");
        }
        break;
      case 'freeze':
        bool value = map['value'] ?? false;
        _buffering = value;
        _bufferStateController.add(value);
        FLog.d("$this freeze ${value ? "start" : "end"}");
        break;
      case 'buffering':
        int head = map['head'] ?? 0;
        int percent = map['percent'] ?? 0;
        _bufferPos = Duration(milliseconds: head);
        _bufferPosController.add(_bufferPos);
        _bufferPercent = percent;
        _bufferPercentController.add(percent);
        break;
      case 'pos':
        int pos = map['pos'];
        _currentPos = Duration(milliseconds: pos);
        if (!_seeking) {
          _currentPosController.add(_currentPos);
        }
        break;
      case 'size_changed':
        double width = map['width'].toDouble();
        double height = map['height'].toDouble();
        FLog.i("$this size changed ($width, $height)");
        _setValue(value.copyWith(size: Size(width, height)));
        break;
      case 'seek_complete':
        _seeking = false;
        break;
      default:
        break;
    }
  }

  void _errorListener(Object obj) {
    final PlatformException e = obj as PlatformException;
    FException exception = FException.fromPlatformException(e);
    FLog.e("$this errorListener: $exception");
    _setValue(value.copyWith(exception: exception));
  }

  @override
  String toString() {
    return 'FPlayer{id:$_playerId}';
  }
}
