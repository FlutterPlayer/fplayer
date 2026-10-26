import 'package:fplayer/fplayer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FValue equality compares fields, not hash codes', () {
    const a = FValue.uninitialized();
    final b = a.copyWith(state: FState.prepared, prepared: true, size: const Size(640, 360));
    final c = a.copyWith(state: FState.prepared, prepared: true, size: const Size(640, 360));

    expect(a, isNot(equals(b)));
    expect(b, equals(c));
    expect(b.hashCode, c.hashCode);
  });

  test('uninitialized value has documented defaults', () {
    const value = FValue.uninitialized();

    expect(value.prepared, isFalse);
    expect(value.completed, isFalse);
    expect(value.audioRenderStart, isFalse);
    expect(value.videoRenderStart, isFalse);
    expect(value.state, FState.idle);
    expect(value.size, isNull);
    expect(value.rotate, 0);
    expect(value.duration, Duration.zero);
    expect(value.fullScreen, isFalse);
    expect(value.exception, FException.noException);
  });

  test('copyWith keeps fields that are not passed', () {
    const value = FValue.uninitialized();
    final changed = value.copyWith(
      completed: true,
      audioRenderStart: true,
      rotate: 180,
      duration: const Duration(seconds: 3),
      fullScreen: true,
    );

    expect(changed.completed, isTrue);
    expect(changed.audioRenderStart, isTrue);
    expect(changed.rotate, 180);
    expect(changed.duration, const Duration(seconds: 3));
    expect(changed.fullScreen, isTrue);
    expect(changed.prepared, value.prepared);
    expect(changed.videoRenderStart, value.videoRenderStart);
    expect(changed.state, value.state);
    expect(changed.size, value.size);
    expect(changed.exception, value.exception);
  });

  test('FValue.toString includes the mutable fields', () {
    final value = const FValue.uninitialized().copyWith(
      state: FState.started,
      prepared: true,
      duration: const Duration(milliseconds: 250),
    );

    expect(value.toString(), contains('prepared:true'));
    expect(value.toString(), contains('state:FState.started'));
    expect(value.toString(), contains('duration:0:00:00.250000'));
  });

  test('FException equality compares code and message', () {
    expect(const FException(1), equals(const FException(1)));
    expect(const FException(1, 'a'), isNot(equals(const FException(1, 'b'))));
    expect(const FException(1), isNot(equals(const FException(2))));
    expect(const FException(1, 'a').hashCode, const FException(1, 'a').hashCode);
  });

  test('FException.fromPlatformException parses numeric codes', () {
    final known = FException.fromPlatformException(
      PlatformException(code: '${FException.noDecoder}', message: 'missing'),
    );
    expect(known.code, FException.noDecoder);
    expect(known.message, 'missing');

    final unknown = FException.fromPlatformException(
      PlatformException(code: 'not-a-number', message: 'boom'),
    );
    expect(unknown.code, FException.unknown);
    expect(unknown.message, 'boom');
  });

  test('FData stores, replaces and removes values', () {
    final data = FData();

    expect(data.contains('key'), isFalse);
    expect(data.getValue('key'), isNull);

    data.setValue('key', 1);
    expect(data.contains('key'), isTrue);
    expect(data.getValue('key'), 1);

    data.setValue('key', 'replaced');
    expect(data.getValue('key'), 'replaced');

    data.clearValue('key');
    expect(data.contains('key'), isFalse);
  });
}
