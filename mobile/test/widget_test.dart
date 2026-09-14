import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spikey/core/app_shell.dart';
import 'package:spikey/shared/logos.dart';

void main() {
  testWidgets('AppShell smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'logo_choice': 1,
      'onboarding_completed': true,
    });
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: const AppShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SpikeyLogoMark), findsWidgets);
  });
}