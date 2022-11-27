import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'fplayer_method_channel.dart';

abstract class FplayerPlatform extends PlatformInterface {
  /// Constructs a FplayerPlatform.
  FplayerPlatform() : super(token: _token);

  static final Object _token = Object();

  static FplayerPlatform _instance = MethodChannelFplayer();

  /// The default instance of [FplayerPlatform] to use.
  ///
  /// Defaults to [MethodChannelFplayer].
  static FplayerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FplayerPlatform] when
  /// they register themselves.
  static set instance(FplayerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
