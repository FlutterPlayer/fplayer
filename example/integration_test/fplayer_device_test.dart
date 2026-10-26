import 'dart:async';

import 'package:fplayer/fplayer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Stream used by the playback test. Override it to exercise a custom source:
///
///   ./tool/device_test.sh -d <device> \
///     --dart-define=FPLAYER_TEST_URL=https://host/video.mp4
const String _streamUrl = String.fromEnvironment(
  'FPLAYER_TEST_URL',
  defaultValue: 'http://player.alicdn.com/video/aliyunmedia.mp4',
);

Future<void> _waitForState(
  FPlayer player,
  FState state, {
  Duration timeout = const Duration(seconds: 30),
}) {
  if (player.state == state) return Future<void>.value();
  if (player.state == FState.error) {
    return Future<void>.error(
      StateError('native error before $state: ${player.value.exception}'),
    );
  }

  final completer = Completer<void>();
  void listener() {
    if (completer.isCompleted) return;
    if (player.state == state) {
      completer.complete();
    } else if (player.state == FState.error) {
      completer.completeError(
        StateError('native error before $state: ${player.value.exception}'),
      );
    }
  }

  player.addListener(listener);
  return completer.future
      .timeout(timeout)
      .whenComplete(() => player.removeListener(listener));
}

Future<void> _prepare(FPlayer player, String source) async {
  final initialized = _waitForState(player, FState.initialized);
  await player.setDataSource(source);
  await initialized;

  final prepared = _waitForState(player, FState.prepared);
  await player.prepareAsync();
  await prepared;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('creates and releases a native player', (WidgetTester tester) async {
    final player = FPlayer();
    final id = await player.id.timeout(const Duration(seconds: 10));

    expect(id, greaterThan(0));
    expect(player.idSync, id);
    expect(player.state, FState.idle);
    expect(FPlayer.all, contains(player));

    await player.release().timeout(const Duration(seconds: 10));

    expect(player.state, FState.end);
    expect(FPlayer.all, isNot(contains(player)));
  });

  testWidgets('prepares, plays and pauses a stream', (WidgetTester tester) async {
    final player = FPlayer();
    addTearDown(player.release);

    final id = await player.id.timeout(const Duration(seconds: 10));
    expect(id, greaterThan(0));

    await _prepare(player, _streamUrl);

    expect(player.value.prepared, isTrue);
    expect(player.value.duration, greaterThan(Duration.zero));
    expect(player.dataSource, _streamUrl);
    expect(player.isPlayable(), isTrue);
    expect(player.value.exception.code, FException.ok);

    final firstPosition = player.onCurrentPosUpdate
        .firstWhere((Duration pos) => pos > Duration.zero)
        .timeout(const Duration(seconds: 20));
    final started = _waitForState(player, FState.started, timeout: const Duration(seconds: 10));
    await player.start();
    await started;

    expect(player.state, FState.started);
    expect(await firstPosition, greaterThan(Duration.zero));

    await player.setVolume(0.5);
    await player.setSpeed(1.5);
    await player.setLoop(1);

    final paused = _waitForState(player, FState.paused, timeout: const Duration(seconds: 10));
    await player.pause();
    await paused;
    expect(player.state, FState.paused);

    await player.seekTo(1000);

    final reset = _waitForState(player, FState.idle, timeout: const Duration(seconds: 10));
    await player.reset();
    await reset;
    expect(player.state, FState.idle);
    expect(player.value.prepared, isFalse);
    expect(player.value.duration, Duration.zero);
  });

  testWidgets('exposes real device capabilities', (WidgetTester tester) async {
    expect(FPlugin.supportsSystemVolume, isTrue);

    final volume = await FVolume.getVol();
    expect(volume, inInclusiveRange(0.0, 1.0));
    await FVolume.setUIMode(FVolume.alwaysShowUI);

    final battery = await FPlugin.getBatteryInfo();
    expect(battery, isNotNull);
    expect(battery!.level, inInclusiveRange(0, 100));

    await FPlugin.keepScreenOn(true);
    expect(await FPlugin.isScreenKeptOn(), isTrue);
    await FPlugin.keepScreenOn(false);
  });
}
