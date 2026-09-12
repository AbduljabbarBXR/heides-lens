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
import 'package:spikey/features/file_tree/presentation/widgets/file_tree_viewer.dart';
import 'package:spikey/features/file_viewer/presentation/widgets/file_content_viewer.dart';
import 'package:spikey/features/settings/presentation/screens/settings_screen.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  double _sidebarWidth = 200;
  double _sidebarMinWidth = 72;
  double _sidebarMaxWidth = 320;
  String? _selectedFilePath;

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(navigationProvider);
    final projectState = ref.watch(projectProvider);
    final isCompact = _sidebarWidth <= 100;

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
              ],
            ),
          ),
          // Body
          Expanded(
            child: Row(
              children: [
                // Sidebar
                Container(
                  width: _sidebarWidth,
                  color: AppColors.surface,
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      // Nav items - left-aligned in compact mode
                      if (isCompact)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              _NavIconButton(
                                icon: Icons.architecture_rounded,
                                isActive: navState.currentMode == AppMode.plan,
                                onTap: () => ref.read(navigationProvider.notifier).setMode(AppMode.plan),
                              ),
                              const SizedBox(height: 6),
                              _NavIconButton(
                                icon: Icons.terminal_rounded,
                                isActive: navState.currentMode == AppMode.workflow,
                                onTap: () => ref.read(navigationProvider.notifier).setMode(AppMode.workflow),
                              ),
                              const SizedBox(height: 6),
                              _NavIconButton(
                                icon: Icons.account_tree_rounded,
                                isActive: navState.currentMode == AppMode.graph,
                                onTap: () => ref.read(navigationProvider.notifier).setMode(AppMode.graph),
                              ),
                              const SizedBox(height: 6),
                              _NavIconButton(
                                icon: Icons.verified_rounded,
                                isActive: navState.currentMode == AppMode.review,
                                onTap: () => ref.read(navigationProvider.notifier).setMode(AppMode.review),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        )
                      else
                        Expanded(
                          child: Column(
                            children: [
                              _NavItem(
                                icon: Icons.architecture_rounded,
                                label: 'Plan',
                                isActive: navState.currentMode == AppMode.plan,
                                onTap: () => ref.read(navigationProvider.notifier).setMode(AppMode.plan),
                              ),
                              _NavItem(
                                icon: Icons.terminal_rounded,
                                label: 'Workflow',
                                isActive: navState.currentMode == AppMode.workflow,
                                onTap: () => ref.read(navigationProvider.notifier).setMode(AppMode.workflow),
                              ),
                              _NavItem(
                                icon: Icons.account_tree_rounded,
                                label: 'Graph',
                                isActive: navState.currentMode == AppMode.graph,
                                onTap: () => ref.read(navigationProvider.notifier).setMode(AppMode.graph),
                              ),
                              _NavItem(
                                icon: Icons.verified_rounded,
                                label: 'Review',
                                isActive: navState.currentMode == AppMode.review,
                                onTap: () => ref.read(navigationProvider.notifier).setMode(AppMode.review),
                              ),
                            ],
                          ),
                        ),
                      // Bottom section: project selector + resize handle
                      Column(
                        children: [
                          const Divider(height: 1, thickness: 1),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: GestureDetector(
                              onTap: _showProjectSelector,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceHover,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: projectState.activeProject != null
                                    ? Icon(Icons.folder_open_rounded, color: AppColors.primary, size: 24)
                                    : Icon(Icons.add_rounded, color: AppColors.textMuted, size: 24),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Resize handle
                GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _sidebarWidth += details.delta.dx;
                      _sidebarWidth = _sidebarWidth.clamp(_sidebarMinWidth, _sidebarMaxWidth);
                    });
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeColumn,
                    child: Container(
                      width: 4,
                      color: AppColors.border,
                    ),
                  ),
                ),
                // Main content area with file tree and viewer
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
      case AppMode.plan:
        return const PlanScreen();
      case AppMode.workflow:
        return const WorkflowScreen();
      case AppMode.graph:
        return const GraphScreen();
      case AppMode.review:
        return const ReviewScreen();
    }
  }

  Widget _buildMainContent(AppMode mode, dynamic activeProject) {
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

    return Row(
      children: [
        // File tree
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
                  projectPath: activeProject.path,
                  onFileTap: (path) => setState(() => _selectedFilePath = path),
                ),
              ),
            ],
          ),
        ),
        // Divider
        Container(width: 1, color: AppColors.border),
        // File viewer or mode content
        if (_selectedFilePath != null)
          Expanded(
            child: FileContentViewer(filePath: _selectedFilePath!),
          )
        else
          Expanded(child: _buildModeContent(mode, activeProject)),
      ],
    );
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
    final isCompact = _sidebarWidth <= 100;
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(70, 36, 154, 0),
      items: [
        PopupMenuItem(
          onTap: () {
            setState(() => _sidebarWidth = isCompact ? 200 : 72);
          },
          child: Text(isCompact ? 'Expand Sidebar' : 'Compact Sidebar', style: TextStyle(color: AppColors.textPrimary)),
        ),
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

class _NavIconButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _NavIconButton({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isActive ? AppColors.surfaceHover : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive ? Border.all(color: AppColors.primary, width: 1) : null,
        ),
        child: Icon(icon, color: isActive ? AppColors.primary : AppColors.textMuted, size: 18),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.surfaceHover : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive ? Border.all(color: AppColors.primary, width: 1) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: isActive ? AppColors.primary : AppColors.textMuted, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isActive ? AppColors.primary : AppColors.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
