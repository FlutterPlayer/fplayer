part of fplayer;

@immutable
class FLogLevel {
  final int level;
  final String name;

  const FLogLevel._(int l, String n)
      : level = l,
        name = n;

  /// Priority constant for the [FLog.log] method;
  static const FLogLevel All = FLogLevel._(000, 'all');

  /// Priority constant for the [FLog.log] method;
  static const FLogLevel Detail = FLogLevel._(100, 'det');

  /// Priority constant for the [FLog.log] method;
  static const FLogLevel Verbose = FLogLevel._(200, 'veb');

  /// Priority constant for the [FLog.log] method; use [FLog.d(msg)]
  static const FLogLevel Debug = FLogLevel._(300, 'dbg');

  /// Priority constant for the [FLog.log] method; use [FLog.i(msg)]
  static const FLogLevel Info = FLogLevel._(400, 'inf');

  /// Priority constant for the [FLog.log] method; use [FLog.w(msg)]
  static const FLogLevel Warn = FLogLevel._(500, 'war');

  /// Priority constant for the [FLog.log] method; use [FLog.e(msg)]
  static const FLogLevel Error = FLogLevel._(600, 'err');
  static const FLogLevel Fatal = FLogLevel._(700, 'fal');
  static const FLogLevel Silent = FLogLevel._(800, 'sil');

  @override
  String toString() {
    return 'FLogLevel{level:$level, name:$name}';
  }
}

/// API for sending log output
///
/// Generally, you should use the [FLog.d(msg)], [FLog.i(msg)],
/// [FLog.w(msg)], and [FLog.e(msg)] methods to write logs.
/// You can then view the logs in console/logcat.
///
/// The order in terms of verbosity, from least to most is ERROR, WARN, INFO, DEBUG, VERBOSE.
/// Verbose should always be skipped in an application except during development.
/// Debug logs are compiled in but stripped at runtime.
/// Error, warning and info logs are always kept.
class FLog {
  static FLogLevel _level = FLogLevel.Info;

  /// Make constructor private
  const FLog._();

  /// Set global whole log level
  ///
  /// Call this method on Android platform will load natvie shared libraries.
  /// If you care about app boot performance,
  /// you should call this method as late as possiable. Call this method before the first time you consturctor new [FPlayer]
  static setLevel(final FLogLevel level) {
    _level = level;
    log(FLogLevel.Silent, "set log level $level", "fplayer");
    FPlugin._setLogLevel(level.level).then((_) {
      log(FLogLevel.Silent, "native log level ${level.level}", "fplayer");
    });
  }

  /// log [msg] with [level] and [tag] to console
  static log(FLogLevel level, String msg, String tag) {
    if (level.level >= _level.level) {
      DateTime now = DateTime.now();
      print("[${level.name}] ${now.toLocal()} [$tag] $msg");
    }
  }

  /// log [msg] with [FLogLevel.Verbose] level
  static v(String msg, {String tag = 'fplayer'}) {
    log(FLogLevel.Verbose, msg, tag);
  }

  /// log [msg] with [FLogLevel.Debug] level
  static d(String msg, {String tag = 'fplayer'}) {
    log(FLogLevel.Debug, msg, tag);
  }

  /// log [msg] with [FLogLevel.Info] level
  static i(String msg, {String tag = 'fplayer'}) {
    log(FLogLevel.Info, msg, tag);
  }

  /// log [msg] with [FLogLevel.Warn] level
  static w(String msg, {String tag = 'fplayer'}) {
    log(FLogLevel.Warn, msg, tag);
  }

  /// log [msg] with [FLogLevel.Error] level
  static e(String msg, {String tag = 'fplayer'}) {
    log(FLogLevel.Error, msg, tag);
  }
}
