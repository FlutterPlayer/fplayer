import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'fplayer_platform_interface.dart';

/// An implementation of [FplayerPlatform] that uses method channels.
class MethodChannelFplayer extends FplayerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('fplayer');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
