import 'package:fplayer/fplayer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses native audio track metadata', () {
    final track = FAudioTrack.fromMap(<String, Object?>{
      'index': 2,
      'language': 'eng',
      'codec': 'aac',
      'codec_long_name': 'AAC (Advanced Audio Coding)',
      'sample_rate': 48000,
      'channel_layout': 3,
      'selected': true,
    });

    expect(track.index, 2);
    expect(track.language, 'eng');
    expect(track.codec, 'aac');
    expect(track.codecLongName, 'AAC (Advanced Audio Coding)');
    expect(track.sampleRate, 48000);
    expect(track.channelLayout, 3);
    expect(track.selected, isTrue);
  });

  test('treats missing and empty native values as absent', () {
    final track = FAudioTrack.fromMap(<String, Object?>{
      'index': 1,
      'language': '',
      'codec': null,
    });

    expect(track.index, 1);
    expect(track.language, isNull);
    expect(track.codec, isNull);
    expect(track.codecLongName, isNull);
    expect(track.sampleRate, isNull);
    expect(track.channelLayout, isNull);
    expect(track.selected, isFalse);
  });

  test('uses the track index for equality', () {
    const a = FAudioTrack(index: 3, language: 'jpn', selected: true);
    const b = FAudioTrack(index: 3, language: 'jpn', selected: true);
    const c = FAudioTrack(index: 4, language: 'jpn', selected: true);

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(c));
  });
}
