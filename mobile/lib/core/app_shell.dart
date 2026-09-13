import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spikey/shared/themes/app_colors.dart';
import 'package:spikey/core/providers/navigation_provider.dart';
import 'package:spikey/core/providers/project_provider.dart';
import 'package:spikey/core/providers/indexing_provider.dart';
import 'package:spikey/features/plan/presentation/screens/plan_screen.dart';
import 'package:spikey/features/workflow/presentation/screens/workflow_screen.dart';
import 'package:spikey/features/graph/presentation/screens/graph_screen.dart';
import 'package:spikey/features/review/presentation/screens/review_screen.dart';
import 'package:spikey/features/plugins/presentation/screens/plugins_screen.dart';
import 'package:spikey/features/file_tree/presentation/widgets/file_tree_viewer.dart';
import 'package:spikey/features/file_viewer/presentation/widgets/file_content_viewer.dart';
import 'package:spikey/features/settings/presentation/screens/settings_screen.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spikey/features/welcome/presentation/screens/welcome_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  String? _selectedFilePath;
  bool _welcomeDismissed = false;
  bool _welcomeShown = false;

  @override
  void initState() {
    super.initState();
    _checkWelcome();
  }

  Future<void> _checkWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool('welcome_dismissed') ?? false;
    if (mounted) {
      setState(() => _welcomeDismissed = dismissed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(navigationProvider);
    final projectState = ref.watch(projectProvider);
    final isExplorer = navState.currentMode == AppMode.explorer;

    if (!_welcomeDismissed && !_welcomeShown && projectState.activeProject == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _welcomeShown = true;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const WelcomeScreen(),
          );
        }
      });
    }

    return Scaffold(
      body: Column(
        children: [
          // Top menu bar
          Container(
            height: 36,
            color: AppColors.surface,
            child: Row(
              children: [
                const SizedBox(width: 16),
                // Logo
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
                // File menu
                _MenuButton(
                  label: 'File',
                  onTap: _showFileMenu,
                ),
                _MenuButton(
                  label: 'View',
                  onTap: _showViewMenu,
                ),
                _MenuButton(
                  label: 'Help',
                  onTap: () {},
                ),
                _MenuButton(
                  label: 'Settings',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SettingsScreen()),
                    );
                  },
                ),
                const Spacer(),
                // Project name
                if (projectState.activeProject != null)
                  Text(
                    projectState.activeProject!.name,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                const SizedBox(width: 16),
                // Window controls (desktop only)
                if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) ...[
                  _WindowControlButton(icon: Icons.minimize_rounded, onTap: () async {
                    final isMaximized = await windowManager.isMaximized();
                    if (isMaximized) {
                      await windowManager.restore();
                    }
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
                        isActive: isExplorer,
                        onTap: () => ref.read(navigationProvider.notifier).setMode(AppMode.explorer),
                      ),
                      const SizedBox(height: 4),
                      _ActivityIconButton(
                        icon: Icons.architecture_rounded,
                        isActive: navState.currentMode == AppMode.plan,
                        onTap: () => ref.read(navigationProvider.notifier).setMode(AppMode.plan),
                      ),
                      const SizedBox(height: 4),
                      _ActivityIconButton(
                        icon: Icons.terminal_rounded,
                        isActive: navState.currentMode == AppMode.workflow,
                        onTap: () => ref.read(navigationProvider.notifier).setMode(AppMode.workflow),
                      ),
                      const SizedBox(height: 4),
                      _ActivityIconButton(
                        icon: Icons.account_tree_rounded,
                        isActive: navState.currentMode == AppMode.graph,
                        onTap: () => ref.read(navigationProvider.notifier).setMode(AppMode.graph),
                      ),
                      const SizedBox(height: 4),
                      _ActivityIconButton(
                        icon: Icons.verified_rounded,
                        isActive: navState.currentMode == AppMode.review,
                        onTap: () => ref.read(navigationProvider.notifier).setMode(AppMode.review),
                      ),
                      const SizedBox(height: 4),
                      _ActivityIconButton(
                        icon: Icons.extension_rounded,
                        isActive: navState.currentMode == AppMode.plugins,
                        onTap: () => ref.read(navigationProvider.notifier).setMode(AppMode.plugins),
                      ),
                      const Spacer(),
                      // Bottom section: project selector
                      Column(
                        children: [
                          const Divider(height: 1, thickness: 1),
                          IconButton(
                            onPressed: _showProjectSelector,
                            icon: projectState.activeProject != null
                                ? Icon(Icons.folder_open_rounded, color: AppColors.primary, size: 20)
                                : Icon(Icons.add_rounded, color: AppColors.textMuted, size: 20),
                            tooltip: 'Open Project',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Side bar (file tree)
                if (projectState.activeProject != null)
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
                            ],
                          ),
                        ),
                        Expanded(
                          child: FileTreeViewer(
                            projectPath: projectState.activeProject!.path,
                            onFileTap: (path) {
                              if (path != null) {
                                setState(() => _selectedFilePath = path);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                // Divider
                if (projectState.activeProject != null)
                  Container(width: 1, color: AppColors.border),
                // Main content area
                Expanded(
                  child: _buildMainContent(navState.currentMode, projectState.activeProject),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeContent(AppMode mode, dynamic activeProject) {
    switch (mode) {
      case AppMode.explorer:
        if (activeProject == null) {
          return Center(
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
        return const SizedBox.shrink();
      case AppMode.plan:
        return const PlanScreen();
      case AppMode.workflow:
        return const WorkflowScreen();
      case AppMode.graph:
        return const GraphScreen();
      case AppMode.review:
        return const ReviewScreen();
      case AppMode.plugins:
        return const PluginsScreen();
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
      children: [
        // File viewer header with back button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 18, color: AppColors.textSecondary),
                onPressed: () => setState(() => _selectedFilePath = null),
                tooltip: 'Back to explorer',
              ),
              const SizedBox(width: 8),
              Icon(_getFileIcon(filePath), size: 16, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Text(
                filePath.split('/').last,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
        // File content
        Expanded(
          child: FileContentViewer(filePath: filePath),
        ),
      ],
    );
  }

  IconData _getFileIcon(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'dart': return Icons.code_rounded;
      case 'ts': case 'tsx': return Icons.data_object_rounded;
      case 'js': case 'jsx': return Icons.data_object_rounded;
      case 'py': return Icons.memory_rounded;
      case 'json': return Icons.data_object_rounded;
      default: return Icons.description_rounded;
    }
  }

  void _showFileMenu() {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(16, 36, 100, 0),
      items: [
        PopupMenuItem(
          onTap: _showProjectSelector,
          child: Text('Open Project', style: TextStyle(color: AppColors.textPrimary)),
        ),
        PopupMenuItem(
          onTap: () {},
          child: Text('Close Project', style: TextStyle(color: AppColors.textPrimary)),
        ),
        PopupMenuItem(
          onTap: () {},
          child: Text('Save Workspace', style: TextStyle(color: AppColors.textPrimary)),
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
          onTap: () {},
          child: Text('Reset Layout', style: TextStyle(color: AppColors.textPrimary)),
        ),
      ],
    );
  }

  Future<void> _showProjectSelector() async {
    final projectState = ref.read(projectProvider);
    
    // Show dialog to choose between existing projects or add new
    if (!mounted) return;
    
    await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Select Project', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (projectState.projects.isEmpty)
              const Text('No projects yet', style: TextStyle(color: AppColors.textSecondary))
            else
              ...projectState.projects.map(
                (p) => ListTile(
                  title: Text(p.name, style: const TextStyle(color: AppColors.textPrimary)),
                  subtitle: Text(p.path, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  onTap: () {
                    ref.read(projectProvider.notifier).setActiveProject(p);
                    ref.invalidate(indexedFilesProvider);
                    Navigator.pop(context, p.path);
                  },
                ),
              ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await _addNewProject();
              },
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Add Project'),
            ),
          ],
        ),
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

class _ActivityIconButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _ActivityIconButton({required this.icon, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isActive ? AppColors.surfaceHover : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: isActive ? AppColors.primary : AppColors.textMuted, size: 20),
      ),
    );
  }
}

class _WindowControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _WindowControlButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: AppColors.surfaceHover,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: AppColors.textSecondary),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _MenuButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceHover,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ),
    );
  }
}
