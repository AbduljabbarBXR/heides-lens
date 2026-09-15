import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heides_lens/core/providers/project_provider.dart';
import 'package:heides_lens/core/providers/navigation_provider.dart';
import 'package:heides_lens/core/providers/indexing_provider.dart';
import 'package:heides_lens/features/welcome/presentation/screens/welcome_screen.dart';
import 'package:heides_lens/features/graph/presentation/screens/graph_screen.dart';
import 'package:heides_lens/features/review/presentation/screens/review_screen.dart';
import 'package:heides_lens/features/workflow/presentation/screens/workflow_screen.dart';
import 'package:heides_lens/features/settings/presentation/screens/settings_screen.dart';

void main() {
  group('ProjectProvider Tests', () {
    test('initial state has empty projects and null activeProject', () {
      final container = ProviderContainer();
      final state = container.read(projectProvider);
      expect(state.projects, isEmpty);
      expect(state.activeProject, isNull);
    });

    test('addProject adds project and sets it as active', () async {
      final container = ProviderContainer();
      final notifier = container.read(projectProvider.notifier);
      
      final project = Project(
        id: '1',
        name: 'Test Project',
        path: '/test/path',
        lastOpened: DateTime.now(),
      );
      
      await notifier.addProject(project);
      
      final state = container.read(projectProvider);
      expect(state.projects.length, 1);
      expect(state.projects.first.name, 'Test Project');
      expect(state.activeProject?.name, 'Test Project');
    });

    test('setActiveProject changes active project', () async {
      final container = ProviderContainer();
      final notifier = container.read(projectProvider.notifier);
      
      final project1 = Project(id: '1', name: 'Project 1', path: '/path1', lastOpened: DateTime.now());
      final project2 = Project(id: '2', name: 'Project 2', path: '/path2', lastOpened: DateTime.now());
      
      await notifier.addProject(project1);
      await notifier.setActiveProject(project2);
      
      final state = container.read(projectProvider);
      expect(state.activeProject?.name, 'Project 2');
      expect(state.projects.length, 1);
    });

    test('updateProject updates project in list', () async {
      final container = ProviderContainer();
      final notifier = container.read(projectProvider.notifier);
      
      final project = Project(id: '1', name: 'Original', path: '/path', lastOpened: DateTime.now());
      await notifier.addProject(project);
      
      final updated = Project(id: '1', name: 'Updated', path: '/path', lastOpened: DateTime.now());
      await notifier.updateProject(updated);
      
      final state = container.read(projectProvider);
      expect(state.projects.first.name, 'Updated');
      expect(state.activeProject?.name, 'Updated');
    });

    test('removeProject removes project from list', () async {
      final container = ProviderContainer();
      final notifier = container.read(projectProvider.notifier);
      
      final project1 = Project(id: '1', name: 'Project 1', path: '/path1', lastOpened: DateTime.now());
      final project2 = Project(id: '2', name: 'Project 2', path: '/path2', lastOpened: DateTime.now());
      
      await notifier.addProject(project1);
      await notifier.addProject(project2);
      await notifier.removeProject('1');
      
      final state = container.read(projectProvider);
      expect(state.projects.length, 1);
      expect(state.projects.first.name, 'Project 2');
    });
  });

  group('NavigationProvider Tests', () {
    test('initial state is home mode', () {
      final container = ProviderContainer();
      final state = container.read(navigationProvider);
      expect(state.currentMode, AppMode.home);
      expect(state.selectedIndex, 0);
    });

    test('setMode changes mode and index', () {
      final container = ProviderContainer();
      final notifier = container.read(navigationProvider.notifier);
      
      notifier.setMode(AppMode.graph);
      
      final state = container.read(navigationProvider);
      expect(state.currentMode, AppMode.graph);
      expect(state.selectedIndex, AppMode.values.indexOf(AppMode.graph));
    });

    test('setIndex changes mode and index', () {
      final container = ProviderContainer();
      final notifier = container.read(navigationProvider.notifier);
      
      notifier.setIndex(3);
      
      final state = container.read(navigationProvider);
      expect(state.currentMode, AppMode.graph);
      expect(state.selectedIndex, 3);
    });

    test('setIndex ignores invalid index', () {
      final container = ProviderContainer();
      final notifier = container.read(navigationProvider.notifier);
      
      notifier.setIndex(99);
      
      final state = container.read(navigationProvider);
      expect(state.currentMode, AppMode.home);
      expect(state.selectedIndex, 0);
    });
  });

  group('WelcomeScreen Widget Tests', () {
    testWidgets('WelcomeScreen shows content in dialog', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: WelcomeScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 1));
      
      expect(find.text('Heides Lens'), findsOneWidget);
      expect(find.text('The nervous system for your code, with eyes.'), findsOneWidget);
      expect(find.text('Open Project'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });
  });

  group('GraphScreen Widget Tests', () {
    testWidgets('GraphScreen shows header', (tester) async {
      final overrides = <Override>[
        indexedFilesProvider.overrideWith((ref, path) => Future.value([])),
      ];
      
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(
            home: Scaffold(
              body: GraphScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));
      
      expect(find.text('Neural Graph'), findsOneWidget);
    });
  });

  group('ReviewScreen Widget Tests', () {
    testWidgets('ReviewScreen shows empty state when no project', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ReviewScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 1));
      
      expect(find.text('Select a project to view findings'), findsOneWidget);
    });
  });

  group('WorkflowScreen Widget Tests', () {
    testWidgets('WorkflowScreen shows header', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: WorkflowScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 1));
      
      expect(find.text('Workflow'), findsOneWidget);
    });
  });

  group('SettingsScreen Widget Tests', () {
    testWidgets('SettingsScreen shows settings UI', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SettingsScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 1));
      
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('AI Provider'), findsOneWidget);
    });
  });
}
