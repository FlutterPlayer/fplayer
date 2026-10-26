import 'dart:async';

import 'package:fplayer/fplayer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Playback must keep advancing after a seek; a stalled seek shows up as
/// `currentPos` frozen at the seek target while the state stays `started`.
///
///   flutter test integration_test/seek_resume_device_test.dart -d <device> \
///     [--dart-define=FPLAYER_TEST_URL=...]
///
/// The source must support HTTP Range requests - MP4 seeking needs them, and
/// Python's http.server does not implement them, so a locally served MP4 looks
/// stalled even on a healthy kernel. A local FLV works either way.
const String _url = String.fromEnvironment(
  'FPLAYER_TEST_URL',
  defaultValue: 'http://player.alicdn.com/video/aliyunmedia.mp4',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('playback resumes after seek', (WidgetTester tester) async {
    final FPlayer player = FPlayer();
    addTearDown(player.release);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: FView(player: player, width: 640, height: 360)),
      ),
    ));
    await tester.pump();

    final Completer<void> prepared = Completer<void>();
    void onValue() {
      if (prepared.isCompleted) return;
      if (player.state == FState.error) {
        prepared.completeError(StateError(
            'error: ${player.value.exception.code} ${player.value.exception.message}'));
      } else if (player.value.prepared) {
        prepared.complete();
      }
    }

    player.addListener(onValue);
    await player.setDataSource(_url);
    await player.prepareAsync();
    await prepared.future.timeout(const Duration(seconds: 30));
    player.removeListener(onValue);
    await player.start();

    Future<void> waitUntil(bool Function() condition, String what,
        {Duration timeout = const Duration(seconds: 15)}) async {
      final DateTime deadline = DateTime.now().add(timeout);
      while (!condition()) {
        if (DateTime.now().isAfter(deadline)) {
          fail('timeout waiting for $what '
              '(pos=${player.currentPos} state=${player.state} '
              'buffering=${player.isBuffering} '
              'rendered=${player.value.videoRenderStart})');
        }
        await tester.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }

    await waitUntil(() => player.value.videoRenderStart, 'first video frame');
    await waitUntil(() => player.currentPos > const Duration(milliseconds: 500),
        'playback to advance');

    await player.seekTo(5000);
    await waitUntil(() => player.currentPos > const Duration(milliseconds: 5200),
        'playback to resume after seek');
    expect(player.currentPos, greaterThan(const Duration(milliseconds: 5200)));
  });
}
