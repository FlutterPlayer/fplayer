import 'package:fplayer/fplayer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FVolumeEvent equality works at 0.0 and 1.0', () {
    const zero = FVolumeEvent(vol: 0.0, sui: false, type: FVolume.STREAM_MUSIC);
    const zeroAgain = FVolumeEvent(vol: 0.0, sui: false, type: FVolume.STREAM_MUSIC);
    const max = FVolumeEvent(vol: 1.0, sui: false, type: FVolume.STREAM_MUSIC);
    const maxAgain = FVolumeEvent(vol: 1.0, sui: false, type: FVolume.STREAM_MUSIC);

    expect(zero, equals(zeroAgain));
    expect(max, equals(maxAgain));
    expect(zero, isNot(equals(max)));
  });

  test('FVolume.setUIMode rejects out of range modes', () async {
    await expectLater(FVolume.setUIMode(99), throwsArgumentError);
  });
}
