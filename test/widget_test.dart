import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:access_app/main.dart';

void main() {
  testWidgets('app shows login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Login Page'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}
