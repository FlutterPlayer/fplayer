import 'package:fplayer/fplayer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts with six empty option categories', () {
    final options = FOption();
    final data = options.data;

    expect(data.keys, containsAll(<int>[0, 1, 2, 3, 4, 5]));
    for (final category in data.values) {
      expect(category, isEmpty);
    }
  });

  test('setters write into their own category', () {
    final options = FOption()
      ..setHostOption('host', 1)
      ..setFormatOption('format', 'a')
      ..setCodecOption('codec', 2)
      ..setPlayerOption('player', 'b')
      ..setSwsOption('sws', 3)
      ..setSwrOption('swr', 'c');

    final data = options.data;
    expect(data[FOption.hostCategory], <String, dynamic>{'host': 1});
    expect(data[FOption.formatCategory], <String, dynamic>{'format': 'a'});
    expect(data[FOption.codecCategory], <String, dynamic>{'codec': 2});
    expect(data[FOption.playerCategory], <String, dynamic>{'player': 'b'});
    expect(data[FOption.swsCategory], <String, dynamic>{'sws': 3});
    expect(data[FOption.swrCategory], <String, dynamic>{'swr': 'c'});
  });

  test('data returns a snapshot that is independent from the options', () {
    final options = FOption()..setHostOption('a', 1);
    final snapshot = options.data;

    snapshot[FOption.hostCategory]!['a'] = 2;
    snapshot[FOption.hostCategory]!['b'] = 3;

    expect(options.data[FOption.hostCategory], <String, dynamic>{'a': 1});

    options.setHostOption('c', 4);
    expect(snapshot[FOption.hostCategory]!.containsKey('c'), isFalse);
  });

  test('rejects values that are neither int nor String', () {
    final options = FOption();
    final setters = <void Function(String, dynamic)>[
      options.setHostOption,
      options.setFormatOption,
      options.setCodecOption,
      options.setPlayerOption,
      options.setSwsOption,
      options.setSwrOption,
    ];

    for (final setter in setters) {
      expect(() => setter('key', true), throwsArgumentError);
      expect(() => setter('key', 1.5), throwsArgumentError);
      expect(() => setter('key', null), throwsArgumentError);
    }
    expect(options.data.values.every((category) => category.isEmpty), isTrue);
  });
}
