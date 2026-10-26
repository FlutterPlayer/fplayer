import 'package:fplayer/fplayer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(FProtocol.pluginChannel);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('create failure completes setup and release does not hang', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == FProtocol.methodCreatePlayer) return -1;
      return null;
    });

    final player = FPlayer();

    await expectLater(player.id, throwsA(isA<StateError>()));
    expect(player.state, FState.error);

    await player.release().timeout(const Duration(seconds: 2));
  });
}
