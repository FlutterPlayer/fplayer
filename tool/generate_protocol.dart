import 'dart:convert';
import 'dart:io';

/// Generates the Dart, Objective-C and Java protocol constants from
/// `tool/fplayer_protocol.json`.
///
/// Run from the repository root:
///   dart run tool/generate_protocol.dart
void main() {
  final root = File.fromUri(Platform.script).parent.parent;
  final spec = jsonDecode(
    File('${root.path}/tool/fplayer_protocol.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  final channels = spec['channels'] as Map<String, dynamic>;
  final methods = spec['methods'] as Map<String, dynamic>;
  final pluginMethods = methods['plugin'] as Map<String, dynamic>;
  final playerMethods = methods['player'] as Map<String, dynamic>;
  final events = spec['events'] as Map<String, dynamic>;
  final states = (spec['states'] as List<dynamic>).cast<String>();

  final dart = _dart(channels, pluginMethods, playerMethods, events, states);
  final objc = _objc(channels, pluginMethods, playerMethods, events, states);
  final java = _java(channels, pluginMethods, playerMethods, events, states);
  final cpp = _cpp(channels, pluginMethods, playerMethods, events, states);

  _write('${root.path}/lib/core/f_protocol.dart', dart);
  for (final path in <String>[
    '${root.path}/shared/objc/FPlayerProtocol.h',
    '${root.path}/ios/fplayer/Sources/fplayer/FPlayerProtocol.h',
    '${root.path}/macos/fplayer/Sources/fplayer/FPlayerProtocol.h',
  ]) {
    _write(path, objc);
  }
  _write(
    '${root.path}/android/src/main/java/com/flutterplayer/fplayer/FPlayerProtocol.java',
    java,
  );
  _write('${root.path}/windows/fplayer_protocol.h', cpp);
}

void _write(String path, String content) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(content);
  stdout.writeln('generated $path');
}

String _upperSnake(String value) {
  final buffer = StringBuffer();
  for (var i = 0; i < value.length; i++) {
    final char = value[i];
    if (char == char.toUpperCase() && char != char.toLowerCase() && i > 0) {
      buffer.write('_');
    }
    buffer.write(char.toUpperCase());
  }
  return buffer.toString();
}

String _cap(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

String _dart(
  Map<String, dynamic> channels,
  Map<String, dynamic> pluginMethods,
  Map<String, dynamic> playerMethods,
  Map<String, dynamic> events,
  List<String> states,
) {
  final out = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT EDIT.')
    ..writeln('// Run: dart run tool/generate_protocol.dart')
    ..writeln()
    ..writeln('part of fplayer;')
    ..writeln()
    ..writeln('class FProtocol {')
    ..writeln('  const FProtocol._();')
    ..writeln()
    ..writeln("  static const String pluginChannel = '${channels['plugin']}';")
    ..writeln(
      "  static const String pluginEventChannel = '${channels['pluginEvent']}';",
    )
    ..writeln(
      "  static const String platformChannel = '${channels['platform']}';",
    )
    ..writeln(
      "  static const String playerChannelPrefix = '${channels['playerPrefix']}';",
    )
    ..writeln(
      "  static const String playerEventChannelPrefix = '${channels['playerEventPrefix']}';",
    )
    ..writeln()
    ..writeln('  static String playerChannel(int id) =>')
    ..writeln("      '\$playerChannelPrefix\$id';")
    ..writeln()
    ..writeln('  static String playerEventChannel(int id) =>')
    ..writeln("      '\$playerEventChannelPrefix\$id';")
    ..writeln();

  for (final entry in pluginMethods.entries) {
    out.writeln(
      "  static const String method${_cap(entry.key)} = '${entry.value}';",
    );
  }
  for (final entry in playerMethods.entries) {
    if (pluginMethods.containsKey(entry.key)) continue;
    out.writeln(
      "  static const String method${_cap(entry.key)} = '${entry.value}';",
    );
  }
  for (final entry in events.entries) {
    out.writeln(
      "  static const String event${_cap(entry.key)} = '${entry.value}';",
    );
  }
  for (var i = 0; i < states.length; i++) {
    out.writeln('  static const int state${_cap(states[i])} = $i;');
  }
  out.writeln('}');
  return out.toString();
}

String _objc(
  Map<String, dynamic> channels,
  Map<String, dynamic> pluginMethods,
  Map<String, dynamic> playerMethods,
  Map<String, dynamic> events,
  List<String> states,
) {
  final out = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT EDIT.')
    ..writeln('// Run: dart run tool/generate_protocol.dart')
    ..writeln()
    ..writeln('#ifndef FPlayerProtocol_h')
    ..writeln('#define FPlayerProtocol_h')
    ..writeln()
    ..writeln('#import <Foundation/Foundation.h>')
    ..writeln()
    ..writeln(
      '#define FPLAYER_CHANNEL_PLUGIN @"${channels['plugin']}"',
    )
    ..writeln(
      '#define FPLAYER_CHANNEL_PLUGIN_EVENT @"${channels['pluginEvent']}"',
    )
    ..writeln(
      '#define FPLAYER_CHANNEL_PLATFORM @"${channels['platform']}"',
    )
    ..writeln(
      '#define FPLAYER_CHANNEL_PLAYER_PREFIX @"${channels['playerPrefix']}"',
    )
    ..writeln(
      '#define FPLAYER_CHANNEL_PLAYER_EVENT_PREFIX @"${channels['playerEventPrefix']}"',
    )
    ..writeln();

  for (final entry in pluginMethods.entries) {
    out.writeln(
      '#define FPLAYER_METHOD_${_upperSnake(entry.key)} @"${entry.value}"',
    );
  }
  for (final entry in playerMethods.entries) {
    if (pluginMethods.containsKey(entry.key)) continue;
    out.writeln(
      '#define FPLAYER_METHOD_${_upperSnake(entry.key)} @"${entry.value}"',
    );
  }
  for (final entry in events.entries) {
    out.writeln(
      '#define FPLAYER_EVENT_${_upperSnake(entry.key)} @"${entry.value}"',
    );
  }
  out
    ..writeln()
    ..writeln('typedef NS_ENUM(NSInteger, FPlayerStateCode) {');
  for (var i = 0; i < states.length; i++) {
    out.writeln('    FPlayerStateCode${_cap(states[i])} = $i,');
  }
  out
    ..writeln('};')
    ..writeln()
    ..writeln('#endif /* FPlayerProtocol_h */');
  return out.toString();
}

String _cpp(
  Map<String, dynamic> channels,
  Map<String, dynamic> pluginMethods,
  Map<String, dynamic> playerMethods,
  Map<String, dynamic> events,
  List<String> states,
) {
  final out = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT EDIT.')
    ..writeln('// Run: dart run tool/generate_protocol.dart')
    ..writeln()
    ..writeln('#ifndef FPLAYER_PROTOCOL_H_')
    ..writeln('#define FPLAYER_PROTOCOL_H_')
    ..writeln()
    ..writeln('#include <string>')
    ..writeln()
    ..writeln('namespace fplayer_protocol {')
    ..writeln()
    ..writeln(
      'inline constexpr char kPluginChannel[] = "${channels['plugin']}";',
    )
    ..writeln(
      'inline constexpr char kPluginEventChannel[] = "${channels['pluginEvent']}";',
    )
    ..writeln(
      'inline constexpr char kPlatformChannel[] = "${channels['platform']}";',
    )
    ..writeln(
      'inline constexpr char kPlayerChannelPrefix[] = "${channels['playerPrefix']}";',
    )
    ..writeln(
      'inline constexpr char kPlayerEventChannelPrefix[] = "${channels['playerEventPrefix']}";',
    )
    ..writeln();

  for (final entry in pluginMethods.entries) {
    out.writeln(
      'inline constexpr char kMethod${_cap(entry.key)}[] = "${entry.value}";',
    );
  }
  for (final entry in playerMethods.entries) {
    if (pluginMethods.containsKey(entry.key)) continue;
    out.writeln(
      'inline constexpr char kMethod${_cap(entry.key)}[] = "${entry.value}";',
    );
  }
  for (final entry in events.entries) {
    out.writeln(
      'inline constexpr char kEvent${_cap(entry.key)}[] = "${entry.value}";',
    );
  }
  for (var i = 0; i < states.length; i++) {
    out.writeln('inline constexpr int kState${_cap(states[i])} = $i;');
  }
  out
    ..writeln()
    ..writeln('inline std::string PlayerChannel(int id) {')
    ..writeln('  return std::string(kPlayerChannelPrefix) + std::to_string(id);')
    ..writeln('}')
    ..writeln()
    ..writeln('inline std::string PlayerEventChannel(int id) {')
    ..writeln(
      '  return std::string(kPlayerEventChannelPrefix) + std::to_string(id);',
    )
    ..writeln('}')
    ..writeln()
    ..writeln('}  // namespace fplayer_protocol')
    ..writeln()
    ..writeln('#endif  // FPLAYER_PROTOCOL_H_')
    ..writeln();
  return out.toString();
}

String _java(
  Map<String, dynamic> channels,
  Map<String, dynamic> pluginMethods,
  Map<String, dynamic> playerMethods,
  Map<String, dynamic> events,
  List<String> states,
) {
  final out = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT EDIT.')
    ..writeln('// Run: dart run tool/generate_protocol.dart')
    ..writeln()
    ..writeln('package com.flutterplayer.fplayer;')
    ..writeln()
    ..writeln('public final class FPlayerProtocol {')
    ..writeln('    private FPlayerProtocol() {}')
    ..writeln()
    ..writeln(
      '    public static final String CHANNEL_PLUGIN = "${channels['plugin']}";',
    )
    ..writeln(
      '    public static final String CHANNEL_PLUGIN_EVENT = "${channels['pluginEvent']}";',
    )
    ..writeln(
      '    public static final String CHANNEL_PLATFORM = "${channels['platform']}";',
    )
    ..writeln(
      '    public static final String CHANNEL_PLAYER_PREFIX = "${channels['playerPrefix']}";',
    )
    ..writeln(
      '    public static final String CHANNEL_PLAYER_EVENT_PREFIX = "${channels['playerEventPrefix']}";',
    )
    ..writeln();

  for (final entry in pluginMethods.entries) {
    out.writeln(
      '    public static final String METHOD_${_upperSnake(entry.key)} = "${entry.value}";',
    );
  }
  for (final entry in playerMethods.entries) {
    if (pluginMethods.containsKey(entry.key)) continue;
    out.writeln(
      '    public static final String METHOD_${_upperSnake(entry.key)} = "${entry.value}";',
    );
  }
  for (final entry in events.entries) {
    out.writeln(
      '    public static final String EVENT_${_upperSnake(entry.key)} = "${entry.value}";',
    );
  }
  for (var i = 0; i < states.length; i++) {
    out.writeln('    public static final int STATE_${_upperSnake(states[i])} = $i;');
  }
  out.writeln('}');
  return out.toString();
}
