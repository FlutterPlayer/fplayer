import 'dart:async';

import 'package:fplayer/fplayer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const int _playerId = 42;

class _FakePlatform {
  static const MethodChannel _pluginChannel =
      MethodChannel(FProtocol.pluginChannel);
  static final MethodChannel _playerChannel =
      MethodChannel(FProtocol.playerChannel(_playerId));
  static final EventChannel _eventChannel =
      EventChannel(FProtocol.playerEventChannel(_playerId));

  final List<MethodCall> pluginCalls = <MethodCall>[];
  final List<MethodCall> playerCalls = <MethodCall>[];
  final StreamController<MethodCall> _playerCallController =
      StreamController<MethodCall>.broadcast();
  final Completer<void> _listening = Completer<void>();
  final List<FPlayer> _players = <FPlayer>[];

  late final TestDefaultBinaryMessenger _messenger;
  MockStreamHandlerEventSink? events;

  _FakePlatform() {
    _messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    _messenger.setMockMethodCallHandler(_pluginChannel, (MethodCall call) async {
      pluginCalls.add(call);
      if (call.method == FProtocol.methodCreatePlayer) return _playerId;
      return null;
    });
    _messenger.setMockMethodCallHandler(_playerChannel, (MethodCall call) async {
      playerCalls.add(call);
      _playerCallController.add(call);
      return null;
    });
    _messenger.setMockStreamHandler(
      _eventChannel,
      MockStreamHandler.inline(
        onListen: (Object? arguments, MockStreamHandlerEventSink sink) {
          events = sink;
          if (!_listening.isCompleted) {
            _listening.complete();
          }
        },
        onCancel: (Object? arguments) {},
      ),
    );
  }

  Future<FPlayer> createPlayer() async {
    final player = FPlayer();
    _players.add(player);
    expect(await player.id, _playerId);
    await _listening.future.timeout(const Duration(seconds: 2));
    return player;
  }

  MethodCall lastCall(String method) =>
      playerCalls.lastWhere((MethodCall call) => call.method == method);

  bool hasCall(String method) =>
      playerCalls.any((MethodCall call) => call.method == method);

  Future<MethodCall> waitForCall(String method) => _playerCallController.stream
      .firstWhere((MethodCall call) => call.method == method)
      .timeout(const Duration(seconds: 2));

  void emit(Map<String, Object?> event) {
    final sink = events;
    if (sink == null) {
      throw StateError('event channel is not listening');
    }
    sink.success(event);
  }

  Future<void> sendPlatformCall(String method, Object? arguments) {
    final data = const StandardMethodCodec()
        .encodeMethodCall(MethodCall(method, arguments));
    return _messenger.handlePlatformMessage(_playerChannel.name, data, (_) {});
  }

  Future<void> dispose() async {
    for (final player in _players) {
      await player.release().timeout(const Duration(seconds: 2));
    }
    _players.clear();
    _messenger.setMockMethodCallHandler(_pluginChannel, null);
    _messenger.setMockMethodCallHandler(_playerChannel, null);
    _messenger.setMockStreamHandler(_eventChannel, null);
    await _playerCallController.close();
  }
}

Future<FValue> waitForValue(FPlayer player, void Function() action) async {
  final completer = Completer<FValue>();
  void listener() {
    if (!completer.isCompleted) {
      completer.complete(player.value);
    }
  }

  player.addListener(listener);
  try {
    action();
    return await completer.future.timeout(const Duration(seconds: 2));
  } finally {
    player.removeListener(listener);
  }
}

Future<T> waitForStream<T>(Stream<T> stream, void Function() action) async {
  final completer = Completer<T>();
  final subscription = stream.listen((T value) {
    if (!completer.isCompleted) {
      completer.complete(value);
    }
  });
  try {
    action();
    return await completer.future.timeout(const Duration(seconds: 2));
  } finally {
    await subscription.cancel();
  }
}

Future<FValue> emitState(FPlayer player, FState state) {
  return waitForValue(
    player,
    () => _platform.emit(<String, Object?>{
      'event': FProtocol.eventStateChange,
      'new': state.index,
      'old': player.state.index,
    }),
  );
}

late _FakePlatform _platform;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _platform = _FakePlatform();
  });

  tearDown(() async {
    await _platform.dispose();
  });

  group('setup and release', () {
    test('create completes id, registers instance and reports state', () async {
      final player = await _platform.createPlayer();

      expect(player.idSync, _playerId);
      expect(player.state, FState.idle);
      expect(player.isPlayable(), isFalse);
      expect(player.toString(), 'FPlayer{id:$_playerId}');
      expect(FPlayer.all, contains(player));
      expect(
        _platform.pluginCalls
            .where((MethodCall call) => call.method == FProtocol.methodCreatePlayer),
        hasLength(1),
      );
    });

    test('release stops native player, ends state and unregisters', () async {
      final player = await _platform.createPlayer();

      await emitState(player, FState.started);
      expect(player.state, FState.started);

      await player.release().timeout(const Duration(seconds: 2));

      expect(player.state, FState.end);
      expect(FPlayer.all, isNot(contains(player)));
      expect(
        _platform.lastCall(FProtocol.methodStop).method,
        FProtocol.methodStop,
      );
      final release = _platform.pluginCalls.lastWhere(
          (MethodCall call) => call.method == FProtocol.methodReleasePlayer);
      expect(release.arguments, <String, dynamic>{'pid': _playerId});

      // Release is idempotent.
      await player.release();
    });

    test('reset restores uninitialized value and keeps full screen', () async {
      final player = await _platform.createPlayer();
      player.enterFullScreen();
      await waitForValue(
        player,
        () => _platform
            .emit(<String, Object?>{'event': FProtocol.eventPrepared, 'duration': 1000}),
      );
      expect(player.value.prepared, isTrue);

      await player.reset();

      expect(player.state, FState.idle);
      expect(player.value.prepared, isFalse);
      expect(player.value.duration, Duration.zero);
      expect(player.value.fullScreen, isTrue);
      expect(_platform.hasCall(FProtocol.methodReset), isTrue);
    });
  });

  group('data source', () {
    test('forwards url and remembers data source', () async {
      final player = await _platform.createPlayer();

      await player.setDataSource('https://example.com/video.mp4');

      final call = _platform.lastCall(FProtocol.methodSetDataSource);
      expect(call.arguments, <String, dynamic>{
        'url': 'https://example.com/video.mp4',
      });
      expect(player.dataSource, 'https://example.com/video.mp4');
    });

    test('rejects empty path', () async {
      final player = await _platform.createPlayer();

      await expectLater(player.setDataSource(''), throwsArgumentError);
      expect(_platform.hasCall(FProtocol.methodSetDataSource), isFalse);
    });

    test('rejects call in non idle/initialized state', () async {
      final player = await _platform.createPlayer();
      await emitState(player, FState.started);

      await expectLater(
        player.setDataSource('https://example.com/video.mp4'),
        throwsStateError,
      );
    });

    test('sends http headers as a format option', () async {
      final player = await _platform.createPlayer();

      await player.setDataSource(
        'https://example.com/video.m3u8',
        headers: <String, String?>{'A': '1', 'B': null},
      );

      final option = _platform.lastCall(FProtocol.methodSetOption);
      expect(option.arguments, <String, dynamic>{
        'cat': FOption.formatCategory,
        'key': 'headers',
        'str': 'A: 1\r\nB: ',
      });
    });

    test('showCover enables cover-after-prepared then prepares', () async {
      final player = await _platform.createPlayer();
      await emitState(player, FState.initialized);

      await player.setDataSource('https://example.com/video.mp4', showCover: true);

      final option = _platform.lastCall(FProtocol.methodSetOption);
      expect(option.arguments, <String, dynamic>{
        'cat': FOption.playerCategory,
        'key': 'cover-after-prepared',
        'long': 1,
      });
      expect(_platform.hasCall(FProtocol.methodPrepareAsync), isTrue);
    });
  });

  group('options and controls', () {
    test('setOption encodes strings and ints, rejects other types', () async {
      final player = await _platform.createPlayer();

      await player.setOption(FOption.playerCategory, 'name', 'value');
      expect(_platform.lastCall(FProtocol.methodSetOption).arguments,
          <String, dynamic>{'cat': 4, 'key': 'name', 'str': 'value'});

      await player.setOption(FOption.codecCategory, 'int', 7);
      expect(_platform.lastCall(FProtocol.methodSetOption).arguments,
          <String, dynamic>{'cat': 2, 'key': 'int', 'long': 7});

      await expectLater(
        player.setOption(FOption.playerCategory, 'bad', true),
        throwsArgumentError,
      );
    });

    test('applyOptions forwards a category to value map', () async {
      final player = await _platform.createPlayer();
      final options = FOption()
        ..setHostOption('host-key', 'host-value')
        ..setPlayerOption('player-key', 3);

      await player.applyOptions(options);

      final call = _platform.lastCall(FProtocol.methodApplyOptions);
      final data = call.arguments as Map<dynamic, dynamic>;
      expect(data[FOption.hostCategory], <String, dynamic>{'host-key': 'host-value'});
      expect(data[FOption.playerCategory], <String, dynamic>{'player-key': 3});
    });

    test('start from initialized prepares with start-on-prepared', () async {
      final player = await _platform.createPlayer();
      await emitState(player, FState.initialized);

      await player.start();

      final calls = _platform.playerCalls
          .map((MethodCall call) => call.method)
          .toList();
      expect(
        calls,
        containsAllInOrder(<String>[
          FProtocol.methodSetOption,
          FProtocol.methodPrepareAsync,
        ]),
      );
      final option = _platform.lastCall(FProtocol.methodSetOption);
      expect(option.arguments, <String, dynamic>{
        'cat': FOption.playerCategory,
        'key': 'start-on-prepared',
        'long': 1,
      });
    });

    test('volume, loop and speed forward their values', () async {
      final player = await _platform.createPlayer();

      await player.setVolume(0.25);
      expect(_platform.lastCall(FProtocol.methodSetVolume).arguments,
          <String, dynamic>{'volume': 0.25});

      await player.setLoop(3);
      expect(_platform.lastCall(FProtocol.methodSetLoop).arguments,
          <String, dynamic>{'loop': 3});

      await player.setSpeed(1.5);
      expect(_platform.lastCall(FProtocol.methodSetSpeed).arguments,
          <String, dynamic>{'speed': 1.5});
    });

    test('invalid arguments and states are rejected', () async {
      final player = await _platform.createPlayer();

      await expectLater(player.setVolume(-0.1), throwsArgumentError);
      await expectLater(player.setLoop(-1), throwsArgumentError);
      await expectLater(player.setSpeed(0), throwsArgumentError);
      await expectLater(player.seekTo(-1), throwsArgumentError);
      await expectLater(player.seekTo(10), throwsStateError);
      await expectLater(player.pause(), throwsStateError);
      await expectLater(player.stop(), throwsStateError);
    });
  });

  group('native events', () {
    test('prepared, rotate and size events update value', () async {
      final player = await _platform.createPlayer();

      final prepared = await waitForValue(
        player,
        () => _platform.emit(<String, Object?>{
          'event': FProtocol.eventPrepared,
          'duration': 1500,
        }),
      );
      expect(prepared.prepared, isTrue);
      expect(prepared.duration, const Duration(milliseconds: 1500));

      final rotated = await waitForValue(
        player,
        () => _platform
            .emit(<String, Object?>{'event': FProtocol.eventRotate, 'degree': 90}),
      );
      expect(rotated.rotate, 90);

      final sized = await waitForValue(
        player,
        () => _platform.emit(<String, Object?>{
          'event': FProtocol.eventSizeChanged,
          'width': 640,
          'height': 360,
        }),
      );
      expect(sized.size, const Size(640, 360));
    });

    test('state change event maps native state ids', () async {
      final player = await _platform.createPlayer();

      final prepared =
          await waitForValue(player, () => _platform.emit(<String, Object?>{
                'event': FProtocol.eventStateChange,
                'new': FProtocol.statePrepared,
                'old': FProtocol.stateIdle,
              }));
      expect(prepared.state, FState.prepared);
      expect(prepared.prepared, isTrue);

      final started =
          await waitForValue(player, () => _platform.emit(<String, Object?>{
                'event': FProtocol.eventStateChange,
                'new': FProtocol.stateStarted,
                'old': FProtocol.statePrepared,
              }));
      expect(started.state, FState.started);
      expect(started.prepared, isTrue);

      final stopped =
          await waitForValue(player, () => _platform.emit(<String, Object?>{
                'event': FProtocol.eventStateChange,
                'new': FProtocol.stateStopped,
                'old': FProtocol.stateStarted,
              }));
      expect(stopped.state, FState.stopped);

      final errored =
          await waitForValue(player, () => _platform.emit(<String, Object?>{
                'event': FProtocol.eventStateChange,
                'new': FProtocol.stateError,
                'old': FProtocol.stateStopped,
              }));
      expect(errored.state, FState.error);
      expect(errored.prepared, isFalse);

      // Unknown native ids are ignored without crashing. The following
      // rotate event proves the unknown one was processed first.
      _platform.emit(<String, Object?>{
        'event': FProtocol.eventStateChange,
        'new': 99,
        'old': FProtocol.stateError,
      });
      await waitForValue(
        player,
        () => _platform
            .emit(<String, Object?>{'event': FProtocol.eventRotate, 'degree': 45}),
      );
      expect(player.state, FState.error);
    });

    test('rendering start events set audio and video flags', () async {
      final player = await _platform.createPlayer();

      final video = await waitForValue(
        player,
        () => _platform.emit(<String, Object?>{
          'event': FProtocol.eventRenderingStart,
          'type': 'video',
        }),
      );
      expect(video.videoRenderStart, isTrue);
      expect(video.audioRenderStart, isFalse);

      final audio = await waitForValue(
        player,
        () => _platform.emit(<String, Object?>{
          'event': FProtocol.eventRenderingStart,
          'type': 'audio',
        }),
      );
      expect(audio.audioRenderStart, isTrue);
    });

    test('freeze and buffering events update streams', () async {
      final player = await _platform.createPlayer();

      final freezing = await waitForStream(player.onBufferStateUpdate,
          () => _platform.emit(<String, Object?>{
                'event': FProtocol.eventFreeze,
                'value': true,
              }));
      expect(freezing, isTrue);
      expect(player.isBuffering, isTrue);

      final head = await waitForStream(player.onBufferPosUpdate,
          () => _platform.emit(<String, Object?>{
                'event': FProtocol.eventBuffering,
                'head': 2000,
                'percent': 40,
              }));
      expect(head, const Duration(milliseconds: 2000));
      expect(player.bufferPos, const Duration(milliseconds: 2000));
      expect(player.bufferPercent, 40);

      final percent = await waitForStream(player.onBufferPercentUpdate,
          () => _platform.emit(<String, Object?>{
                'event': FProtocol.eventBuffering,
                'head': 3000,
                'percent': 60,
              }));
      expect(percent, 60);
    });

    test('seek suppresses position updates until seek completes', () async {
      final player = await _platform.createPlayer();
      await emitState(player, FState.started);

      final positions = <Duration>[];
      final subscription = player.onCurrentPosUpdate.listen(positions.add);
      addTearDown(subscription.cancel);

      await player.seekTo(1000);
      expect(_platform.lastCall(FProtocol.methodSeekTo).arguments,
          <String, dynamic>{'msec': 1000});

      _platform.emit(<String, Object?>{'event': FProtocol.eventPos, 'pos': 5000});
      _platform.emit(<String, Object?>{'event': FProtocol.eventSeekComplete});
      _platform.emit(<String, Object?>{'event': FProtocol.eventPos, 'pos': 6000});

      final first = await player.onCurrentPosUpdate
          .first
          .timeout(const Duration(seconds: 2));
      expect(first, const Duration(milliseconds: 6000));
      expect(player.currentPos, const Duration(milliseconds: 6000));
      expect(positions, <Duration>[const Duration(milliseconds: 6000)]);
    });

    test('platform errors are exposed through the value', () async {
      final player = await _platform.createPlayer();

      final errored = await waitForValue(
        player,
        () => _platform.events!.error(
          code: '${FException.noDecoder}',
          message: 'no decoder',
        ),
      );
      expect(errored.prepared, isFalse);
      expect(errored.exception.code, FException.noDecoder);
      expect(errored.exception.message, 'no decoder');
    });

    test('isPlayable only for prepared, started, paused and completed', () async {
      final player = await _platform.createPlayer();

      for (final state in FState.values.skip(1)) {
        await emitState(player, state);
        final expected = state == FState.prepared ||
            state == FState.started ||
            state == FState.paused ||
            state == FState.completed;
        expect(player.isPlayable(), expected, reason: 'state $state');
      }
    });
  });

  group('snapshot', () {
    test('completes with bytes delivered by the platform', () async {
      final player = await _platform.createPlayer();
      final bytes = Uint8List.fromList(<int>[1, 2, 3]);

      final requested = _platform.waitForCall(FProtocol.methodSnapshot);
      final snapshot = player.takeSnapShot();
      await requested;

      await _platform.sendPlatformCall(
        FProtocol.methodOnSnapshot,
        <String, dynamic>{'data': bytes},
      );

      expect(await snapshot.timeout(const Duration(seconds: 2)), bytes);
    });

    test('rejects a second snapshot while one is pending', () async {
      final player = await _platform.createPlayer();
      final bytes = Uint8List.fromList(<int>[4, 5]);

      final requested = _platform.waitForCall(FProtocol.methodSnapshot);
      final first = player.takeSnapShot();
      await requested;

      await expectLater(player.takeSnapShot(), throwsStateError);

      await _platform.sendPlatformCall(
        FProtocol.methodOnSnapshot,
        <String, dynamic>{'data': bytes},
      );
      expect(await first.timeout(const Duration(seconds: 2)), bytes);
    });

    test('rejects payloads that are not bytes', () async {
      final player = await _platform.createPlayer();

      final requested = _platform.waitForCall(FProtocol.methodSnapshot);
      final snapshot = player.takeSnapShot();
      await requested;

      final expectation = expectLater(
        snapshot.timeout(const Duration(seconds: 2)),
        throwsA(isA<UnsupportedError>()),
      );
      await _platform.sendPlatformCall(
        FProtocol.methodOnSnapshot,
        <String, dynamic>{'data': 'not-bytes'},
      );
      await expectation;
    });
  });
}
