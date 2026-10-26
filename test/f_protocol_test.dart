import 'package:fplayer/fplayer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('protocol builds player channel names from one source', () {
    expect(FProtocol.playerChannel(7), 'fplayer.dev/fplayer/7');
    expect(
      FProtocol.playerEventChannel(7),
      'fplayer.dev/fplayer/event/7',
    );
    expect(FProtocol.pluginChannel, 'fplayer.dev/fplayer');
    expect(FProtocol.platformChannel, 'fplayer.dev/fplayer/platform');
    expect(FProtocol.methodCreatePlayer, 'createPlayer');
    expect(FProtocol.eventStateChange, 'state_change');
  });
}
