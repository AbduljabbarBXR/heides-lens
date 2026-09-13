import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spikey/shared/themes/app_colors.dart';
import 'package:spikey/core/providers/navigation_provider.dart';
import 'package:spikey/core/providers/project_provider.dart';
import 'package:spikey/core/providers/indexing_provider.dart';
import 'package:spikey/core/providers/findings_provider.dart';
import 'package:spikey/core/onboarding/onboarding_overlay.dart';
import 'package:spikey/features/plan/presentation/screens/plan_screen.dart';
import 'package:spikey/features/workflow/presentation/screens/workflow_screen.dart';
import 'package:spikey/features/graph/presentation/screens/graph_screen.dart';
import 'package:spikey/features/review/presentation/screens/review_screen.dart';
import 'package:spikey/features/plugins/presentation/screens/plugins_screen.dart';
import 'package:spikey/features/file_tree/presentation/widgets/file_tree_viewer.dart';
import 'package:spikey/features/file_viewer/presentation/widgets/file_content_viewer.dart';
import 'package:spikey/features/settings/presentation/screens/settings_screen.dart';
import 'package:spikey/features/docs/presentation/screens/docs_screen.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  String? _selectedFilePath;
  bool _isSidebarOpen = false;
  bool _onboardingChecked = false;
  bool _showOnboarding = false;
  bool _isIndexing = false;
  double _indexingProgress = 0;
  String _indexingStatus = '';

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool('onboarding_completed') ?? false;
    if (mounted) {
      setState(() {
        _onboardingChecked = true;
      });
      if (!completed) {
        setState(() => _showOnboarding = true);
      }
    }
  }

  /// Preload graph + review data in the background so the screens are
  /// instant when the user navigates to them.
  void _preloadData(String projectPath) {
    // Kick off the futures; providers cache the results.
    try {
      ref.read(indexedFilesProvider.future);
    } catch (_) {}
    try {
      ref.read(graphDataProvider(projectPath).future);
    } catch (_) {}
    try {
      ref.read(findingsProvider(projectPath).future);
    } catch (_) {}
  }

  Future<void> _startIndexing() async {
    final project = ref.read(projectProvider).activeProject;
    if (project == null) return;

    setState(() {
      _isIndexing = true;
      _indexingProgress = 0;
      _indexingStatus = 'Scanning files...';
    });

    try {
      final engine = ref.read(indexingEngineProvider);
      // Simulate progress while indexing happens
      for (int i = 0; i <= 90; i += 10) {
        await Future.delayed(const Duration(milliseconds: 150));
        if (mounted) {
          setState(() {
            _indexingProgress = i / 100;
            if (i < 30) _indexingStatus = 'Scanning files...';
            else if (i < 60) _indexingStatus = 'Indexing symbols...';
            else if (i < 90) _indexingStatus = 'Building dependencies...';
            else _indexingStatus = 'Almost done...';
          });
        }
      }
      // Actually index the project
      await engine.indexProject(project.path);
      if (mounted) {
        setState(() {
          _indexingProgress = 1.0;
          _indexingStatus = 'Complete!';
        });
        await Future.delayed(const Duration(milliseconds: 500));
        setState(() => _isIndexing = false);
      }
      // Preload graph + review data in the background
      _preloadData(project.path);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isIndexing = false;
          _indexingStatus = 'Error: $e';
        });
      }
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
    final isCtrl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    if (isCtrl) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.digit1:
          ref.read(navigationProvider.notifier).setMode(AppMode.explorer);
          setState(() => _isSidebarOpen = true);
        case LogicalKeyboardKey.digit2:
          ref.read(navigationProvider.notifier).setMode(AppMode.plan);
        case LogicalKeyboardKey.digit3:
          ref.read(navigationProvider.notifier).setMode(AppMode.workflow);
        case LogicalKeyboardKey.digit4:
          ref.read(navigationProvider.notifier).setMode(AppMode.graph);
        case LogicalKeyboardKey.digit5:
          ref.read(navigationProvider.notifier).setMode(AppMode.review);
        case LogicalKeyboardKey.digit6:
          ref.read(navigationProvider.notifier).setMode(AppMode.plugins);
        case LogicalKeyboardKey.keyP:
          _showProjectSelector();
        case LogicalKeyboardKey.comma:
          Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_selectedFilePath != null) {
        setState(() => _selectedFilePath = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(navigationProvider);
    final projectState = ref.watch(projectProvider);
    final isExplorer = navState.currentMode == AppMode.explorer;

    // Show onboarding overlay
    if (_showOnboarding && _onboardingChecked) {
      return OnboardingOverlay(
        onComplete: () {
          setState(() {
            _showOnboarding = false;
          });
          // After onboarding, show project selector
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showProjectSelector();
          });
        },
      );
    }

    // Show indexing progress overlay
    if (_isIndexing) {
      return _IndexingOverlay(
        progress: _indexingProgress,
        status: _indexingStatus,
        projectPath: ref.read(projectProvider).activeProject?.path ?? '',
      );
    }

    return Scaffold(
      body: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        autofocus: true,
        child: Column(
          children: [
            // Top menu bar
            Container(
              height: 36,
              color: AppColors.surface,
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.auto_awesome, color: AppColors.background, size: 14),
                  ),
                  const SizedBox(width: 16),
                  _MenuButton(label: 'File', onTap: _showFileMenu),
                  _MenuButton(label: 'View', onTap: _showViewMenu),
                  _MenuButton(label: 'Help', onTap: _showHelpMenu),
                  _MenuButton(
                    label: 'Settings',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                  ),
                  const Spacer(),
                  if (projectState.activeProject != null)
                    Text(
                      projectState.activeProject!.name,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  const SizedBox(width: 16),
                  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) ...[
                    _WindowControlButton(icon: Icons.minimize_rounded, onTap: () async {
                      final isMaximized = await windowManager.isMaximized();
                      if (isMaximized) await windowManager.restore();
                      await windowManager.minimize();
                    }),
                    _WindowControlButton(icon: Icons.check_box_outline_blank_rounded, onTap: () async => await windowManager.maximize()),
                    _WindowControlButton(icon: Icons.close_rounded, onTap: () async => await windowManager.close()),
                  ],
                ],
              ),
            ),
            // Body
            Expanded(
              child: Row(
                children: [
                  // Activity bar
                  Container(
                    width: 48,
                    color: AppColors.surface,
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        _ActivityIconButton(
                          icon: Icons.folder_rounded,
                          tooltip: 'Explorer (Ctrl+1)',
                          isActive: _isSidebarOpen && isExplorer,
                          onTap: () {
                            final notifier = ref.read(navigationProvider.notifier);
                            if (_isSidebarOpen && navState.currentMode == AppMode.explorer) {
                              setState(() => _isSidebarOpen = false);
                            } else {
                              notifier.setMode(AppMode.explorer);
                              setState(() => _isSidebarOpen = true);
                            }
                          },
                        ),
                        const SizedBox(height: 4),
                        _ActivityIconButton(
                          icon: Icons.architecture_rounded,
                          tooltip: 'Plan (Ctrl+2)',
                          isActive: navState.currentMode == AppMode.plan,
                          onTap: () => ref.read(navigationProvider.notifier).setMode(AppMode.plan),
                        ),
                        const SizedBox(height: 4),
                        _ActivityIconButton(
                          icon: Icons.terminal_rounded,
                          tooltip: 'Workflow (Ctrl+3)',
                          isActive: navState.currentMode == AppMode.workflow,
                          onTap: () => ref.read(navigationProvider.notifier).setMode(AppMode.workflow),
                        ),
                        const SizedBox(height: 4),
                        _ActivityIconButton(
                          icon: Icons.account_tree_rounded,
                          tooltip: 'Graph (Ctrl+4)',
                          isActive: navState.currentMode == AppMode.graph,
                          onTap: () => ref.read(navigationProvider.notifier).setMode(AppMode.graph),
                        ),
                        const SizedBox(height: 4),
                        _ActivityIconButton(
                          icon: Icons.verified_rounded,
                          tooltip: 'Review (Ctrl+5)',
                          isActive: navState.currentMode == AppMode.review,
                          onTap: () => ref.read(navigationProvider.notifier).setMode(AppMode.review),
                        ),
                        const SizedBox(height: 4),
                        _ActivityIconButton(
                          icon: Icons.extension_rounded,
                          tooltip: 'Plugins (Ctrl+6)',
                          isActive: navState.currentMode == AppMode.plugins,
                          onTap: () => ref.read(navigationProvider.notifier).setMode(AppMode.plugins),
                        ),
                        const Spacer(),
                        Column(
                          children: [
                            const Divider(height: 1, thickness: 1),
                            IconButton(
                              onPressed: _showProjectSelector,
                              icon: projectState.activeProject != null
                                  ? Icon(Icons.folder_open_rounded, color: AppColors.primary, size: 20)
                                  : Icon(Icons.add_rounded, color: AppColors.textMuted, size: 20),
                              tooltip: 'Open Project (Ctrl+P)',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Side bar (file tree) — only when opened via Explorer icon
                  if (_isSidebarOpen && projectState.activeProject != null)
                    Container(
                      width: 220,
                      color: AppColors.surface,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: AppColors.border)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.folder_rounded, size: 16, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text('Explorer', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                                const Spacer(),
                                MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () => setState(() => _isSidebarOpen = false),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2),
                                      child: Icon(Icons.close_rounded, size: 14, color: AppColors.textMuted),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: FileTreeViewer(
                              projectPath: projectState.activeProject!.path,
                              selectedFilePath: _selectedFilePath,
                              onFileTap: (path) {
                                setState(() {
                                  _selectedFilePath = path;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_isSidebarOpen && projectState.activeProject != null)
                    Container(width: 1, color: AppColors.border),
                  // Main content area
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                      child: _buildMainContent(navState.currentMode, projectState.activeProject),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeContent(AppMode mode, dynamic activeProject) {
    switch (mode) {
      case AppMode.explorer:
        if (activeProject == null) {
          return Center(
            key: const ValueKey('explorer-empty'),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open_rounded, size: 64, color: AppColors.textMuted),
                const SizedBox(height: 16),
                Text('Select a project to start', style: AppTextStyles.body.copyWith(color: AppColors.textMuted)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _showProjectSelector,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Open Project'),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink(key: ValueKey('explorer-empty-tree'));
      case AppMode.plan:
        return const PlanScreen(key: ValueKey('plan'));
      case AppMode.workflow:
        return const WorkflowScreen(key: ValueKey('workflow'));
      case AppMode.graph:
        return const GraphScreen(key: ValueKey('graph'));
      case AppMode.review:
        return const ReviewScreen(key: ValueKey('review'));
      case AppMode.plugins:
        return const PluginsScreen(key: ValueKey('plugins'));
    }
  }

  Widget _buildMainContent(AppMode mode, dynamic activeProject) {
    if (_selectedFilePath != null) {
      return _buildFileViewerWithBack(_selectedFilePath!);
    }
    return _buildModeContent(mode, activeProject);
  }

  Widget _buildFileViewerWithBack(String filePath) {
    return Column(
      key: const ValueKey('file-viewer'),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 18, color: AppColors.textSecondary),
                onPressed: () => setState(() => _selectedFilePath = null),
                tooltip: 'Back (Esc)',
              ),
              const SizedBox(width: 4),
              Icon(Icons.folder_rounded, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              ..._buildBreadcrumbs(filePath),
            ],
          ),
        ),
        Expanded(
          child: FileContentViewer(filePath: filePath),
        ),
      ],
    );
  }

  List<Widget> _buildBreadcrumbs(String filePath) {
    final parts = filePath.split('/');
    final widgets = <Widget>[];
    final displayParts = parts.length > 3 ? parts.sublist(parts.length - 3) : parts;

    for (var i = 0; i < displayParts.length; i++) {
      if (i > 0) {
        widgets.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.chevron_right_rounded, size: 14, color: AppColors.textMuted),
        ));
      }
      final isLast = i == displayParts.length - 1;
      widgets.add(
        Text(
          displayParts[i],
          style: TextStyle(
            fontSize: 12,
            color: isLast ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: isLast ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      );
    }
    return widgets;
  }

  void _showFileMenu() {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(16, 36, 100, 0),
      items: [
        PopupMenuItem(onTap: _showProjectSelector, child: const Text('Open Project')),
        PopupMenuItem(
          onTap: ref.read(projectProvider).activeProject != null
              ? () => ref.read(projectProvider.notifier).removeProject(ref.read(projectProvider).activeProject!.id)
              : null,
          child: const Text('Close Project'),
        ),
      ],
    );
  }

  void _showViewMenu() {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(70, 36, 154, 0),
      items: [
        PopupMenuItem(
          onTap: () {
            ref.read(navigationProvider.notifier).setMode(AppMode.explorer);
            setState(() => _isSidebarOpen = true);
          },
          child: const Text('Reset Layout'),
        ),
      ],
    );
  }

  void _showHelpMenu() {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(110, 36, 200, 0),
      items: [
        PopupMenuItem(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DocumentationScreen()),
          ),
          child: const Text('Documentation'),
        ),
        PopupMenuItem(
          onTap: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('onboarding_completed', false);
            setState(() {
              _showOnboarding = true;
            });
          },
          child: const Text('Show Welcome'),
        ),
        PopupMenuItem(
          onTap: () {},
          child: const Text('Keyboard Shortcuts'),
        ),
      ],
    );
  }

  Future<void> _showProjectSelector() async {
    final projectState = ref.read(projectProvider);
    if (!mounted) return;

    await showDialog<String>(
      context: context,
      builder: (context) => _ProjectSelectorDialog(
        projects: projectState.projects,
        onSelectProject: (project) {
          ref.read(projectProvider.notifier).setActiveProject(project);
          ref.invalidate(indexedFilesProvider);
          Navigator.pop(context, project.path);
          // Preload graph + review data in the background
          _preloadData(project.path);
          // Start indexing after selecting project
          _startIndexing();
        },
        onAddProject: () async {
          Navigator.pop(context);
          await _addNewProject();
        },
        onRemoveProject: (project) {
          ref.read(projectProvider.notifier).removeProject(project.id);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _addNewProject() async {
    final String? directoryPath = await getDirectoryPath();
    if (directoryPath == null) return;

    final projectName = p.basename(directoryPath);
    final project = Project(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: projectName,
      path: directoryPath,
      lastOpened: DateTime.now(),
    );

    ref.read(projectProvider.notifier).addProject(project);
    _startIndexing();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Project "$projectName" added'),
          backgroundColor: AppColors.surface,
        ),
      );
    }
  }
}

// --- Indexing Overlay ---
class _IndexingOverlay extends StatefulWidget {
  final double progress;
  final String status;
  final String projectPath;

  const _IndexingOverlay({
    required this.progress,
    required this.status,
    required this.projectPath,
  });

  @override
  State<_IndexingOverlay> createState() => _IndexingOverlayState();
}

class _IndexingOverlayState extends State<_IndexingOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black87,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated icon
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Icon(Icons.auto_awesome, color: AppColors.primary, size: 40),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Indexing Your Codebase',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                p.basename(widget.projectPath),
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              // Progress bar
              Container(
                width: 300,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: widget.progress,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.status,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(widget.progress * 100).toInt()}%',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Project Selector Dialog ---
class _ProjectSelectorDialog extends StatelessWidget {
  final List<Project> projects;
  final Function(Project) onSelectProject;
  final VoidCallback onAddProject;
  final Function(Project) onRemoveProject;

  const _ProjectSelectorDialog({
    required this.projects,
    required this.onSelectProject,
    required this.onAddProject,
    required this.onRemoveProject,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.folder_open_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Project',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Choose a project to analyze',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Project list
              if (projects.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.folder_off_rounded, size: 40, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text(
                        'No projects yet',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Open a folder to get started',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: projects.length,
                    itemBuilder: (context, index) {
                      final project = projects[index];
                      return _ProjectTile(
                        project: project,
                        onSelect: () => onSelectProject(project),
                        onRemove: () => onRemoveProject(project),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),

              // Add project button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onAddProject,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Open New Project'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectTile extends StatefulWidget {
  final Project project;
  final VoidCallback onSelect;
  final VoidCallback onRemove;

  const _ProjectTile({
    required this.project,
    required this.onSelect,
    required this.onRemove,
  });

  @override
  State<_ProjectTile> createState() => _ProjectTileState();
}

class _ProjectTileState extends State<_ProjectTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _isHovered ? AppColors.primary.withOpacity(0.08) : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _isHovered ? AppColors.primary.withOpacity(0.3) : AppColors.border,
          ),
        ),
        child: ListTile(
          onTap: widget.onSelect,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.folder_rounded, color: AppColors.primary, size: 20),
          ),
          title: Text(
            widget.project.name,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            widget.project.path,
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: _isHovered ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: widget.onRemove,
                icon: Icon(Icons.close_rounded, size: 14, color: AppColors.textMuted),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Remove',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityIconButton extends StatefulWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final String? tooltip;

  const _ActivityIconButton({required this.icon, required this.isActive, required this.onTap, this.tooltip});

  @override
  State<_ActivityIconButton> createState() => _ActivityIconButtonState();
}

class _ActivityIconButtonState extends State<_ActivityIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip ?? '',
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: widget.isActive
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : _isHovered
                      ? AppColors.surfaceHover
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                if (widget.isActive)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    left: 0,
                    top: 12,
                    bottom: 12,
                    width: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(2),
                          bottomRight: Radius.circular(2),
                        ),
                      ),
                    ),
                  ),
                Center(
                  child: Icon(
                    widget.icon,
                    color: widget.isActive
                        ? AppColors.primary
                        : _isHovered
                            ? AppColors.textSecondary
                            : AppColors.textMuted,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WindowControlButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _WindowControlButton({required this.icon, required this.onTap});

  @override
  State<_WindowControlButton> createState() => _WindowControlButtonState();
}

class _WindowControlButtonState extends State<_WindowControlButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 36,
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.surfaceHover : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(widget.icon, size: 16, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _MenuButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _MenuButton({required this.label, required this.onTap});

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.surfaceHover : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(widget.label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ),
      ),
    );
  }
}
