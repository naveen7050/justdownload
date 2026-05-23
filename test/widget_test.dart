// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:justdownload/main.dart';

void main() {
  testWidgets('App starts and displays splash screen logo', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our logo/title "justDownload" is found on the splash screen.
    expect(find.text('justDownload'), findsOneWidget);

    // Let the splash screen timer run and transition to HomeScreen
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
  });
}
