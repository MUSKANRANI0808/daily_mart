import 'package:flutter_test/flutter_test.dart';
import 'package:daily_mart/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DailyMartApp());
    expect(find.byType(DailyMartApp), findsOneWidget);
  });
}
