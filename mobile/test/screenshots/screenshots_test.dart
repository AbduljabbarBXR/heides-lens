import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spikey/core/app_shell.dart';
import 'package:spikey/core/providers/findings_provider.dart';
import 'package:spikey/core/providers/heides_provider.dart';
import 'package:spikey/core/providers/indexing_provider.dart';
import 'package:spikey/core/providers/navigation_provider.dart';
import 'package:spikey/core/providers/project_provider.dart';
import 'package:spikey/core/providers/settings_provider.dart';
import 'package:spikey/data/services/indexing_engine.dart';
import 'package:spikey/shared/themes/app_theme.dart';
import 'package:spikey/features/plan/presentation/screens/plan_screen.dart';
import 'package:spikey/features/settings/presentation/screens/settings_screen.dart';
import 'package:spikey/features/welcome/presentation/screens/welcome_screen.dart';

/// Generates screenshots of each app section via golden tests.
/// Run: flutter test test/screenshots --update-goldens

const String projectPath = '/home/centinos/Spikey/mobile/lib';

class FakeEngine extends IndexingEngine {
  @override
  Future<List<IndexedFile>> getIndexedFiles() async => _sampleFiles();

  @override
  Future<Map<String, dynamic>> getDependencies(String filePath) async {
    return {'imports': [], 'calls': []};
  }
}

List<IndexedFile> _sampleFiles() {
  return [
    IndexedFile(id: 1, path: '$projectPath/main.dart', hash: 'a', language: 'dart', loc: 42, lastIndexed: DateTime.now()),
    IndexedFile(id: 2, path: '$projectPath/core/app_shell.dart', hash: 'b', language: 'dart', loc: 673, lastIndexed: DateTime.now()),
    IndexedFile(id: 3, path: '$projectPath/core/providers/settings_provider.dart', hash: 'c', language: 'dart', loc: 161, lastIndexed: DateTime.now()),
    IndexedFile(id: 4, path: '$projectPath/core/providers/project_provider.dart', hash: 'd', language: 'dart', loc: 116, lastIndexed: DateTime.now()),
    IndexedFile(id: 5, path: '$projectPath/core/services/llm_service.dart', hash: 'e', language: 'dart', loc: 192, lastIndexed: DateTime.now()),
    IndexedFile(id: 6, path: '$projectPath/data/services/indexing_engine.dart', hash: 'f', language: 'dart', loc: 454, lastIndexed: DateTime.now()),
    IndexedFile(id: 7, path: '$projectPath/features/workflow/presentation/screens/workflow_screen.dart', hash: 'g', language: 'dart', loc: 500, lastIndexed: DateTime.now()),
    IndexedFile(id: 8, path: '$projectPath/features/graph/presentation/screens/graph_screen.dart', hash: 'h', language: 'dart', loc: 1756, lastIndexed: DateTime.now()),
    IndexedFile(id: 9, path: '$projectPath/features/review/presentation/screens/review_screen.dart', hash: 'i', language: 'dart', loc: 431, lastIndexed: DateTime.now()),
    IndexedFile(id: 10, path: '$projectPath/shared/themes/app_colors.dart', hash: 'j', language: 'dart', loc: 89, lastIndexed: DateTime.now()),
    IndexedFile(id: 11, path: '$projectPath/shared/themes/app_theme.dart', hash: 'k', language: 'dart', loc: 74, lastIndexed: DateTime.now()),
    IndexedFile(id: 12, path: '$projectPath/features/settings/presentation/screens/settings_screen.dart', hash: 'l', language: 'dart', loc: 300, lastIndexed: DateTime.now()),
  ];
}

List<Map<String, dynamic>> _sampleEdges() {
  final f = _sampleFiles();
  final path = (int id) => f.firstWhere((e) => e.id == id).path;
  return [
    {'from': path(1), 'to': path(2), 'type': 'import', 'line': 1},
    {'from': path(2), 'to': path(3), 'type': 'import', 'line': 1},
    {'from': path(2), 'to': path(4), 'type': 'import', 'line': 1},
    {'from': path(2), 'to': path(6), 'type': 'import', 'line': 1},
    {'from': path(2), 'to': path(7), 'type': 'import', 'line': 1},
    {'from': path(2), 'to': path(8), 'type': 'import', 'line': 1},
    {'from': path(2), 'to': path(9), 'type': 'import', 'line': 1},
    {'from': path(3), 'to': path(10), 'type': 'import', 'line': 1},
    {'from': path(5), 'to': path(10), 'type': 'import', 'line': 1},
    {'from': path(7), 'to': path(5), 'type': 'import', 'line': 1},
    {'from': path(9), 'to': path(10), 'type': 'import', 'line': 1},
    {'from': path(12), 'to': path(3), 'type': 'import', 'line': 1},
    {'from': path(12), 'to': path(5), 'type': 'import', 'line': 1},
    {'from': path(11), 'to': path(10), 'type': 'import', 'line': 1},
  ];
}

List<Map<String, dynamic>> _sampleFindings() {
  return [
    {
      'id': '1', 'severity': 'critical', 'category': 'security',
      'title': 'Shell injection risk in diff runner',
      'description': 'The command builder concatenates user input into a shell string.',
      'location': 'packages/cli/src/analysis/diff.ts:14', 'suggestion': 'Use execFileSync with an argument array instead of shell strings.',
    },
    {
      'id': '2', 'severity': 'critical', 'category': 'security',
      'title': 'Hardcoded credentials committed',
      'description': 'A production API key is present in the source tree.',
      'location': 'mobile/lib/core/providers/settings_provider.dart:80', 'suggestion': 'Move credentials to environment variables or secure storage.',
    },
    {
      'id': '3', 'severity': 'warning', 'category': 'performance',
      'title': 'N+1 database queries in findings loader',
      'description': 'The provider runs one query per indexed file instead of a single JOIN.',
      'location': 'mobile/lib/core/providers/findings_provider.dart:10', 'suggestion': 'Use a single JOIN query filtered by project path.',
    },
    {
      'id': '4', 'severity': 'warning', 'category': 'architecture',
      'title': 'Hardcoded project metadata',
      'description': 'Pipeline metadata is hardcoded to a demo project name.',
      'location': 'packages/cli/src/analysis/pipeline.ts:45', 'suggestion': 'Derive metadata from the project path.',
    },
    {
      'id': '5', 'severity': 'info', 'category': 'style',
      'title': 'Prefer const constructors',
      'description': 'Several widgets can use const constructors for better performance.',
      'location': 'mobile/lib/core/app_shell.dart:197', 'suggestion': 'Add const to constructor invocations.',
    },
    {
      'id': '6', 'severity': 'info', 'category': 'style',
      'title': 'withOpacity is deprecated',
      'description': 'Use withValues(alpha:) to avoid precision loss.',
      'location': 'mobile/lib/core/app_shell.dart:609', 'suggestion': 'Replace withOpacity with withValues.',
    },
  ];
}

Future<ProviderContainer> _buildContainer() async {
  final files = _sampleFiles();
  final fakeEngine = FakeEngine();
  final container = ProviderContainer(overrides: [
    indexingEngineProvider.overrideWithValue(fakeEngine),
    indexedFilesProvider.overrideWith((ref) async => files),
    graphDataProvider.overrideWith((ref, path) async => {'files': files, 'edges': _sampleEdges()}),
    findingsProvider.overrideWith((ref, path) async => _sampleFindings()),
    // HEIDES is not exercised in screenshots
    heidesAvailableProvider.overrideWith((ref) async => false),
    heidesManifestProvider.overrideWith((ref, path) async => null),
    heidesFindingsProvider.overrideWith((ref, path) async => null),
    projectProvider.overrideWith((ref) => ProjectNotifier()..addProject(Project(
          id: '1', name: 'Spikey', path: projectPath, lastOpened: DateTime.now(),
        ))),
    settingsProvider.overrideWith((ref) => SettingsNotifier()..setApiKey('sk-or-********')),
  ]);
  return container;
}

Future<void> _pumpApp(WidgetTester tester, ProviderContainer container, {bool sized = true}) async {
  if (sized) {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
  }
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: AppShell(),
    ),
  ));
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'onboarding_completed': true,
      'heides_setup_done': true,
      'logo_choice': 1,
    });
  });

  testWidgets('01 - welcome', (tester) async {
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const WelcomeScreen(),
    ));
    await tester.pumpAndSettle();
    await expectLater(find.byType(WelcomeScreen), matchesGoldenFile('goldens/welcome.png'));
  });

  testWidgets('02 - explorer (file tree)', (tester) async {
    final container = await _buildContainer();
    await _pumpApp(tester, container);
    // Open the sidebar via the Explorer activity button
    await tester.tap(find.byTooltip('Explorer (Ctrl+1)'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(find.byType(AppShell), matchesGoldenFile('goldens/explorer.png'));
  });

  testWidgets('03 - plan', (tester) async {
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const PlanScreen(),
    ));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await expectLater(find.byType(PlanScreen), matchesGoldenFile('goldens/plan.png'));
  });

  testWidgets('04 - workflow (chat)', (tester) async {
    final container = await _buildContainer();
    await _pumpApp(tester, container);
    container.read(navigationProvider.notifier).setMode(AppMode.workflow);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    await expectLater(find.byType(AppShell), matchesGoldenFile('goldens/workflow.png'));
  });

  testWidgets('05 - graph (neural view)', (tester) async {
    final container = await _buildContainer();
    await _pumpApp(tester, container);
    container.read(navigationProvider.notifier).setMode(AppMode.graph);
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    await expectLater(find.byType(AppShell), matchesGoldenFile('goldens/graph.png'));
  });

  testWidgets('06 - review (findings)', (tester) async {
    final container = await _buildContainer();
    await _pumpApp(tester, container);
    container.read(navigationProvider.notifier).setMode(AppMode.review);
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    await expectLater(find.byType(AppShell), matchesGoldenFile('goldens/review.png'));
  });

  testWidgets('07 - plugins (marketplace)', (tester) async {
    final container = await _buildContainer();
    await _pumpApp(tester, container);
    container.read(navigationProvider.notifier).setMode(AppMode.plugins);
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    await expectLater(find.byType(AppShell), matchesGoldenFile('goldens/plugins.png'));
  });

  testWidgets('08 - settings', (tester) async {
    final container = await _buildContainer();
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const SettingsScreen(),
      ),
    ));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await expectLater(find.byType(SettingsScreen), matchesGoldenFile('goldens/settings.png'));
  });
}