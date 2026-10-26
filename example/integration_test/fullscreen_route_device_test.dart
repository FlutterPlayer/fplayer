import 'dart:async';

import 'package:fplayer/fplayer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// On-device counterpart of `fplayer/test/f_view_fullscreen_test.dart`.
///
/// It reproduces what the host test can only simulate: a real native player,
/// a real window rotation driven by `FPlugin.setOrientationLandscape`, and a
/// real player event arriving after the responsive layout rebuilt the FView.
///
///   cd example
///   flutter test integration_test/fullscreen_route_device_test.dart -d <device>
///
/// A network stream is used because the bundled-asset path could not be opened
/// by the kernel (see `fplayer_device_test.dart`).
const String _streamUrl = String.fromEnvironment(
  'FPLAYER_TEST_URL',
  defaultValue: 'http://player.alicdn.com/video/aliyunmedia.mp4',
);

class _RouteRecorder extends NavigatorObserver {
  final List<Route<dynamic>> pushed = <Route<dynamic>>[];
  final List<Route<dynamic>> popped = <Route<dynamic>>[];

  /// The home route is pushed when the app first builds.
  static const int _homeRoutes = 1;

  int get fullscreenRoutes => pushed.length - _homeRoutes;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popped.add(route);
  }
}

/// Mirrors StudyApp's `CustomResponsiveLayout`: the rotation swaps in a
/// different subtree, disposing and recreating the FView State while
/// `player.value.fullScreen` is still true.
class _ResponsivePlayer extends StatelessWidget {
  const _ResponsivePlayer(this.player);

  final FPlayer player;

  @override
  Widget build(BuildContext context) {
    final bool horizontal =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return Scaffold(
      backgroundColor: Colors.grey,
      body: Center(
        child: KeyedSubtree(
          key: ValueKey<bool>(horizontal),
          child: FView(
            player: player,
            width: horizontal ? 560 : 320,
            height: horizontal ? 315 : 180,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

Future<void> _waitForState(
  FPlayer player,
  FState state, {
  Duration timeout = const Duration(seconds: 30),
}) {
  if (player.state == state) return Future<void>.value();
  final Completer<void> completer = Completer<void>();
  void listener() {
    if (completer.isCompleted) return;
    if (player.state == state) {
      completer.complete();
    } else if (player.state == FState.error) {
      completer.completeError(
        StateError('native error before $state: ${player.value.exception}'),
      );
    }
  }

  player.addListener(listener);
  return completer.future
      .timeout(timeout)
      .whenComplete(() => player.removeListener(listener));
}

/// Pumps real frames until [condition] holds. Bounded by [timeout] so a
/// regression fails the test instead of hanging it.
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required String description,
  Duration timeout = const Duration(seconds: 30),
}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('timed out waiting for $description');
    }
    await tester.pump(const Duration(milliseconds: 50));
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fullscreen route survives the rotation rebuild and exits once',
      (WidgetTester tester) async {
    final FPlayer player = FPlayer();
    addTearDown(player.release);
    final int id = await player.id.timeout(const Duration(seconds: 10));
    // OHOS numbers players from 0; only a failed creation is negative.
    expect(id, greaterThanOrEqualTo(0));
    expect(player.idSync, id);

    final _RouteRecorder recorder = _RouteRecorder();
    await tester.pumpWidget(MaterialApp(
      navigatorObservers: <NavigatorObserver>[recorder],
      home: _ResponsivePlayer(player),
    ));
    await tester.pump();

    await player.setOption(FOption.playerCategory, 'start-on-prepared', 0);
    final initialized = _waitForState(player, FState.initialized);
    await player.setDataSource(_streamUrl);
    await initialized;
    final prepared = _waitForState(player, FState.prepared);
    await player.prepareAsync();
    await prepared;
    expect(player.value.prepared, isTrue);
    await tester.pump();

    // Enter fullscreen: this rotates the real window to landscape, which makes
    // the responsive host rebuild and swap out the FView subtree.
    player.enterFullScreen();
    await _pumpUntil(
      tester,
      () => recorder.fullscreenRoutes == 1,
      description: 'the fullscreen route to be pushed',
    );
    await _pumpUntil(
      tester,
      () => MediaQuery.of(tester.element(find.byType(FView))).orientation ==
          Orientation.landscape,
      description: 'the window to rotate to landscape',
    );
    await tester.pump(const Duration(milliseconds: 500));

    // A real player event after the rebuild (state change -> notifyListeners).
    // With the old routing this pushed a second fullscreen route.
    final started = _waitForState(player, FState.started);
    await player.start();
    await started;
    final paused = _waitForState(player, FState.paused);
    await player.pause();
    await paused;
    await tester.pump(const Duration(milliseconds: 500));
    expect(recorder.fullscreenRoutes, 1,
        reason: 'the rebuilt FView must adopt the route already on the stack');

    // One pop (what the system back does) leaves fullscreen.
    final NavigatorState navigator =
        tester.state<NavigatorState>(find.byType(Navigator).first);
    navigator.pop();
    await tester.pump();
    await _pumpUntil(
      tester,
      () => !player.value.fullScreen,
      description: 'fullscreen state to be cleared',
    );
    expect(recorder.popped.length, 1, reason: 'only one route is popped');
    expect(find.byType(FView), findsOneWidget,
        reason: 'the playing page stays below the fullscreen route');

    // The orientation lock must be released back to portrait, not left at
    // landscape (system rotation lock keeps AUTO_ROTATION at the old value).
    await _pumpUntil(
      tester,
      () => MediaQuery.of(tester.element(find.byType(FView))).orientation ==
          Orientation.portrait,
      description: 'the window to return to portrait',
    );
  });
}
