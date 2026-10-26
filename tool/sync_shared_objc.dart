import 'dart:io';

/// Copies the shared Objective-C sources into the iOS and macOS Swift packages.
///
/// Swift Package Manager rejects target sources outside the package directory,
/// so `ios/fplayer/Sources/fplayer` and `macos/fplayer/Sources/fplayer` each
/// carry a copy of `shared/objc`. After editing `shared/objc`, run:
///
///   dart run tool/sync_shared_objc.dart
///
/// Pass `--check` to fail when a copy is out of date instead of rewriting it.
void main(List<String> args) {
  final check = args.contains('--check');
  final root = File.fromUri(Platform.script).parent.parent;
  final shared = Directory('${root.path}/shared/objc');
  var stale = false;

  for (final file in shared.listSync().whereType<File>()) {
    final name = file.uri.pathSegments.last;
    if (!name.endsWith('.h') && !name.endsWith('.m')) {
      continue;
    }
    final contents = file.readAsStringSync();
    for (final platform in const <String>['ios', 'macos']) {
      final relative = name == 'FplayerPlugin.h'
          ? 'include/$name'
          : name;
      final target = File(
        '${root.path}/$platform/fplayer/Sources/fplayer/$relative',
      );
      if (target.existsSync() && target.readAsStringSync() == contents) {
        continue;
      }
      stale = true;
      if (check) {
        stdout.writeln('out of date: ${target.path}');
      } else {
        target.writeAsStringSync(contents);
        stdout.writeln('updated ${target.path}');
      }
    }
  }

  if (!stale) {
    stdout.writeln('shared Objective-C sources are in sync');
  } else if (check) {
    exit(1);
  }
}
