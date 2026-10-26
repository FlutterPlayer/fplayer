import 'dart:async';

import 'package:fplayer/fplayer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const int _playerId = 42;

/// Mocks the fplayer platform channels so [FView] can drive the fullscreen
/// route without a native player.
class _FakePlatform {
  static const MethodChannel _pluginChannel =
      MethodChannel(FProtocol.pluginChannel);
  static final MethodChannel _playerChannel =
      MethodChannel(FProtocol.playerChannel(_playerId));
  static final EventChannel _eventChannel =
      EventChannel(FProtocol.playerEventChannel(_playerId));

  final Completer<void> _listening = Completer<void>();
  MockStreamHandlerEventSink? events;

  _FakePlatform() {
    final TestDefaultBinaryMessenger messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_pluginChannel, (MethodCall call) async {
      if (call.method == FProtocol.methodCreatePlayer) return _playerId;
      return null;
    });
    // SystemChrome (immersive mode / preferred orientations) talks on
    // 'flutter/platform'; without a handler those futures never complete here.
    messenger.setMockMethodCallHandler(
        SystemChannels.platform, (MethodCall call) async => null);
    messenger.setMockMethodCallHandler(_playerChannel, (MethodCall call) async {
      return null;
    });
    messenger.setMockStreamHandler(
      _eventChannel,
      MockStreamHandler.inline(
        onListen: (Object? arguments, MockStreamHandlerEventSink sink) {
          events = sink;
          if (!_listening.isCompleted) {
            _listening.complete();
          }
        },
        onCancel: (Object? arguments) {},
      ),
    );
  }

  Future<FPlayer> createPlayer() async {
    final FPlayer player = FPlayer();
    expect(await player.id, _playerId);
    await _listening.future.timeout(const Duration(seconds: 2));
    return player;
  }

  void emit(Map<String, Object?> event) {
    final MockStreamHandlerEventSink? sink = events;
    if (sink == null) {
      throw StateError('event channel is not listening');
    }
    sink.success(event);
  }
}

class _RouteRecorder extends NavigatorObserver {
  final List<Route<dynamic>> pushes = <Route<dynamic>>[];
  final List<Route<dynamic>> pops = <Route<dynamic>>[];
  final List<Route<dynamic>> removals = <Route<dynamic>>[];

  /// The home route is pushed when the MaterialApp first builds.
  static const int _homeRoutes = 1;

  int get fullscreenRoutes => pushes.length - _homeRoutes;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pops.add(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    removals.add(route);
  }
}

/// Mirrors StudyApp's `CustomResponsiveLayout`: rotating swaps in a different
/// subtree, so the [FView] State that pushed the fullscreen route is disposed
/// and a new one is created while `player.value.fullScreen` is still true.
class _ResponsivePlayer extends StatelessWidget {
  const _ResponsivePlayer({required this.player, required this.landscape});

  final FPlayer player;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final Widget view = KeyedSubtree(
      key: ValueKey<bool>(landscape),
      child: FView(
        player: player,
        width: landscape ? 800 : 400,
        height: landscape ? 400 : 225,
        color: Colors.black,
      ),
    );
    return MediaQuery(
      data: MediaQueryData(
        size: landscape ? const Size(800, 400) : const Size(400, 800),
      ),
      child: Scaffold(body: Center(child: view)),
    );
  }
}

Widget _app(FPlayer player, _RouteRecorder recorder,
    {required bool landscape}) {
  return MaterialApp(
    navigatorObservers: <NavigatorObserver>[recorder],
    home: _ResponsivePlayer(player: player, landscape: landscape),
  );
}

/// Pumps the player until it is prepared with a landscape frame size and has
/// entered full screen.
Future<_RouteRecorder> _enterFullScreen(
    WidgetTester tester, _FakePlatform platform, FPlayer player) async {
  final _RouteRecorder recorder = _RouteRecorder();
  await tester.pumpWidget(_app(player, recorder, landscape: false));
  await tester.pump();

  platform.emit(<String, Object?>{
    'event': FProtocol.eventPrepared,
    'duration': 1000,
  });
  platform.emit(<String, Object?>{
    'event': FProtocol.eventSizeChanged,
    'width': 1920,
    'height': 1080,
  });
  await tester.pump();

  player.enterFullScreen();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  expect(recorder.fullscreenRoutes, 1,
      reason: 'entering fullscreen pushes exactly one route');
  return recorder;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('rotation rebuild must not stack a second fullscreen route',
      (WidgetTester tester) async {
    final _FakePlatform platform = _FakePlatform();
    final FPlayer player = await platform.createPlayer();
    final _RouteRecorder recorder =
        await _enterFullScreen(tester, platform, player);

    // Rotation disposes the FView State that owns the pushed route.
    await tester.pumpWidget(_app(player, recorder, landscape: true));
    await tester.pump();
    expect(player.value.fullScreen, isTrue);

    // The rebuild must adopt the route already on the stack instead of
    // pushing another one; a duplicate route is what made leaving fullscreen
    // need two back presses.
    platform.emit(<String, Object?>{
      'event': FProtocol.eventSizeChanged,
      'width': 1080,
      'height': 1920,
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(recorder.fullscreenRoutes, 1,
        reason: 'a rebuilt FView must adopt the existing route, not push again');

    // A single back press leaves fullscreen and keeps the page below.
    final NavigatorState navigator =
        tester.state<NavigatorState>(find.byType(Navigator).first);
    navigator.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(player.value.fullScreen, isFalse);
    expect(find.byType(FView), findsOneWidget);
    expect(recorder.fullscreenRoutes, 1);
  });

  testWidgets('exiting via the panel button removes the one fullscreen route',
      (WidgetTester tester) async {
    final _FakePlatform platform = _FakePlatform();
    final FPlayer player = await platform.createPlayer();
    final _RouteRecorder recorder =
        await _enterFullScreen(tester, platform, player);

    player.exitFullScreen();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(recorder.removals.length, 1,
        reason: 'only the fullscreen route is removed');
    expect(recorder.pops, isEmpty,
        reason: 'the page below must not be popped');
    expect(player.value.fullScreen, isFalse);
    expect(find.byType(FView), findsOneWidget);
  });
}
