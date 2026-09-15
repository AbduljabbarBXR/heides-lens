import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:heides_lens/core/onboarding/logo_picker_screen.dart';
import 'package:heides_lens/shared/themes/app_theme.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('logo picker preview', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: LogoPickerScreen(onComplete: () {}),
    ));
    await tester.pumpAndSettle();
    await expectLater(find.byType(LogoPickerScreen), matchesGoldenFile('goldens/logo-picker.png'));
  });
}