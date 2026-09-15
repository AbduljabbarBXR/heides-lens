import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:heides_lens/core/onboarding/heides_setup_screen.dart';
import 'package:heides_lens/shared/themes/app_theme.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'logo_choice': 2});
  });

  testWidgets('heides setup screen', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: HeidesSetupScreen(onComplete: () {}),
    ));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await expectLater(find.byType(HeidesSetupScreen), matchesGoldenFile('goldens/heides-setup.png'));
  });
}