import 'package:flutter_test/flutter_test.dart';

import 'package:ha_movers/main.dart';

void main() {
  testWidgets('HA Movers app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const HAMoversApp());

    await tester.pump();

    expect(find.text('HA Movers'), findsWidgets);
    expect(find.text('Moving made simple.'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2800));
  });
}
