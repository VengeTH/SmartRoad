import "package:flutter_test/flutter_test.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "package:smartroad/main.dart";

void main() {
  testWidgets("App boots to login after the splash screen", (tester) async {
    // * Pump the app inside a ProviderScope (required by Riverpod).
    await tester.pumpWidget(
      const ProviderScope(
        child: SmartRoadApp(),
      ),
    );

    // * Wait for the splash timeout (2s) + a small buffer.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // * In demo mode (no Supabase env vars), auth is null, so login is shown.
    expect(find.text("Sign in"), findsOneWidget);
    expect(find.text("Login"), findsOneWidget);
  });
}
