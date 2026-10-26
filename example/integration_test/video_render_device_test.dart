import 'dart:async';

import 'package:fplayer/fplayer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Guards against "playback started, audio is running, but no video frame is
/// ever rendered" - the OHOS hardware decoder path used to clear SPS/PPS on the
/// initial flush packet, so no frame was produced and the skin's
/// `!videoRenderStart` spinner stayed on screen forever.
///
///   flutter test integration_test/video_render_device_test.dart -d <device> \
///     [--dart-define=FPLAYER_TEST_URL=...] [--dart-define=FPLAYER_TLS_INSECURE=true]
const String _url = String.fromEnvironment(
  'FPLAYER_TEST_URL',
  defaultValue: 'http://player.alicdn.com/video/aliyunmedia.mp4',
);
const bool _tlsInsecure = bool.fromEnvironment('FPLAYER_TLS_INSECURE');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('video frames actually render into an FView',
      (WidgetTester tester) async {
    final FPlayer player = FPlayer();
    addTearDown(player.release);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: FView(player: player, width: 640, height: 360),
        ),
      ),
    ));
    await tester.pump();

    if (_tlsInsecure) {
      await player.setOption(FOption.formatCategory, 'tls_verify', 0);
    }

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
    final DateTime deadline = DateTime.now().add(const Duration(seconds: 20));
    while (!player.value.videoRenderStart) {
      if (DateTime.now().isAfter(deadline)) break;
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(player.value.videoRenderStart, isTrue,
        reason: 'audio=${player.value.audioRenderStart} '
            'buffering=${player.isBuffering} state=${player.state}');
  });
}
