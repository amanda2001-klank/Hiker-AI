import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app_venture_flutter/main.dart';

void main() {
  testWidgets('AppVentureApp login screen and navigation test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: AppVentureApp()));

    // Verify that login screen is displayed.
    expect(find.text('APP Venture'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);

    // Tap signup button and navigate
    final signupFinder = find.text("Don't have an account? Sign up");
    await tester.ensureVisible(signupFinder);
    await tester.tap(signupFinder);
    await tester.pumpAndSettle();

    // Verify signup screen is displayed
    expect(find.text('Create Account'), findsOneWidget);
  });
}
