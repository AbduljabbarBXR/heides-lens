import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vybecode_mobile/core/project_store.dart';
import 'package:vybecode_mobile/features/projects/projects_screen.dart';

void main() {
  testWidgets('ProjectsScreen shows empty state when no projects', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ProjectStore(),
        child: const MaterialApp(home: ProjectsScreen()),
      ),
    );
    expect(find.text('No projects. Add one to start.'), findsOneWidget);
  });
}
