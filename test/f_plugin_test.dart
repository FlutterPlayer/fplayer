import 'package:fplayer/fplayer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(FProtocol.pluginChannel);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  void mockPlugin(Future<Object?> Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, handler);
  }

  test('getBatteryInfo parses level and charging flag', () async {
    mockPlugin((MethodCall call) async {
      expect(call.method, FProtocol.methodGetBatteryInfo);
      return <String, dynamic>{'level': 77, 'charging': true};
    });

    final info = await FPlugin.getBatteryInfo();

    expect(info, isNotNull);
    expect(info!.level, 77);
    expect(info.charging, isTrue);
  });

  test('getBatteryInfo defaults invalid payload fields', () async {
    mockPlugin((MethodCall call) async =>
        <String, dynamic>{'level': 'unknown', 'charging': 1});

    final info = await FPlugin.getBatteryInfo();

    expect(info!.level, 0);
    expect(info.charging, isFalse);
  });

  test('getBatteryInfo returns null when the platform has no answer', () async {
    mockPlugin((MethodCall call) async => null);

    expect(await FPlugin.getBatteryInfo(), isNull);
  });

  test('setScreenBrightness rejects values outside [0.0, 1.0]', () async {
    await expectLater(FPlugin.setScreenBrightness(-0.1), throwsArgumentError);
    await expectLater(FPlugin.setScreenBrightness(1.1), throwsArgumentError);
  });

  test('system volume setters reject values outside [0.0, 1.0]', () async {
    await expectLater(FVolume.setVol(-0.1), throwsArgumentError);
    await expectLater(FVolume.setVol(1.1), throwsArgumentError);
    await expectLater(FVolume.up(step: 2.0), throwsArgumentError);
    await expectLater(FVolume.down(step: -0.1), throwsArgumentError);
  });
}
