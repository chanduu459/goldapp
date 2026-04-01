import 'package:flutter_test/flutter_test.dart';

import 'package:goldapp/views/sign_in_view.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('Sign in screen renders key controls', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SignInView(),
      ),
    );

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign In'), findsOneWidget);
  });
}
