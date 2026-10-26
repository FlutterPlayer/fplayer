import 'package:flutter_test/flutter_test.dart';

import 'package:fplayer_example/main.dart';

void main() {
  testWidgets('renders the home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('FPlayer'), findsOneWidget);
    expect(find.text('Online Samples'), findsOneWidget);
  });
}
