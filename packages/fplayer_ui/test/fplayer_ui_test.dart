import 'package:fplayer_ui/fplayer_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exports the rich panel model', () {
    final item = VideoItem(url: 'https://example.com/a.mp4', title: 'A', subTitle: 'B');
    expect(item.url, 'https://example.com/a.mp4');
    expect(item.title, 'A');
    expect(item.subTitle, 'B');
  });

  testWidgets('FSlider reports taps as a value in its range', (WidgetTester tester) async {
    final values = <double>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              height: 20,
              child: FSlider(
                value: 0.5,
                onTapDown: values.add,
                onChanged: values.add,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(tester.getCenter(find.byType(FSlider)));

    expect(values, hasLength(1));
    expect(values.single, closeTo(0.5, 0.02));
  });

  testWidgets('FSlider clamps drag values to min and max', (WidgetTester tester) async {
    final changes = <double>[];
    final starts = <double>[];
    final ends = <double>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              height: 20,
              child: FSlider(
                value: 0.5,
                min: -1.0,
                max: 1.0,
                onChanged: changes.add,
                onChangeStart: starts.add,
                onChangeEnd: ends.add,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(FSlider), const Offset(500, 0));

    expect(starts, <double>[0.5]);
    expect(changes, isNotEmpty);
    expect(changes.last, 1.0);
    expect(ends, <double>[1.0]);
  });

  testWidgets('FSlider rejects values outside min/max', (WidgetTester tester) async {
    expect(
      () => FSlider(value: 2.0, max: 1.0, onChanged: (_) {}),
      throwsAssertionError,
    );
  });
}
