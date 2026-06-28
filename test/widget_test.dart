import 'package:flutter_test/flutter_test.dart';
import 'package:revenue_dept_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RevenueDeptApp());
    expect(find.byType(RevenueDeptApp), findsOneWidget);
  });
}
