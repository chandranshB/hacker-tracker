import 'package:flutter_test/flutter_test.dart';
import 'package:hacker_tracker/main.dart';

void main() {
  testWidgets('HackerTrackerApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const HackerTrackerApp());
    expect(find.text('Hacker Tracker'), findsWidgets);
  });
}
