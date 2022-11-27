import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fplayer/fplayer_method_channel.dart';

void main() {
  MethodChannelFplayer platform = MethodChannelFplayer();
  const MethodChannel channel = MethodChannel('fplayer');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
