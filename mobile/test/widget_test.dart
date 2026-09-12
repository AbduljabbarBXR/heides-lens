import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spikey/core/app_shell.dart';

void main() {
  testWidgets('AppShell smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: const AppShell(),
        ),
      ),
    );
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
  });
}
