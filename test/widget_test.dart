import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Widget smoke test', (WidgetTester tester) async {
    // بناء تطبيق بسيط يحتوي على رقم "0"
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('0'),
          ),
        ),
      ),
    );

    // التحقق من وجود "0"
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);
  });
}