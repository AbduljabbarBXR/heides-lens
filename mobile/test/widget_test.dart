import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:heides_lens/core/app_shell.dart';
import 'package:heides_lens/shared/logos.dart';

void main() {
  testWidgets('AppShell smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'logo_choice': 1,
      'onboarding_completed': true,
      'heides_setup_done': true,
    });
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: const AppShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HeidesLogoMark), findsWidgets);
  });
}