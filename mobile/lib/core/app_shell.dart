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

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  double _sidebarWidth = 200;
  double _sidebarMinWidth = 80;
  double _sidebarMaxWidth = 320;

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(navigationProvider);
    final projectState = ref.watch(projectProvider);
    final isCompact = _sidebarWidth < 140;

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
                  onTap: () => _showProjectSelector(context, ref),
                ),
                _MenuButton(
                  label: 'View',
                  onTap: () {
                    if (isCompact) {
                      setState(() => _sidebarWidth = 200);
                    } else {
                      setState(() => _sidebarWidth = 80);
                    }
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
                      // Nav items
                      _NavItem(
                        icon: Icons.architecture_rounded,
                        label: 'Plan',
                        isActive: navState.currentMode == AppMode.plan,
                        isCompact: isCompact,
                        onTap: () => ref.read(navigationProvider.notifier).setMode(AppMode.plan),
                      ),
                      _NavItem(
                        icon: Icons.terminal_rounded,
                        label: 'Workflow',
                        isActive: navState.currentMode == AppMode.workflow,
                        isCompact: isCompact,
                        onTap: () => ref.read(navigationProvider.notifier).setMode(AppMode.workflow),
                      ),
                      _NavItem(
                        icon: Icons.account_tree_rounded,
                        label: 'Graph',
                        isActive: navState.currentMode == AppMode.graph,
                        isCompact: isCompact,
                        onTap: () => ref.read(navigationProvider.notifier).setMode(AppMode.graph),
                      ),
                      _NavItem(
                        icon: Icons.verified_rounded,
                        label: 'Review',
                        isActive: navState.currentMode == AppMode.review,
                        isCompact: isCompact,
                        onTap: () => ref.read(navigationProvider.notifier).setMode(AppMode.review),
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
                // Main content
                Expanded(
                  child: _buildModeContent(navState.currentMode, projectState.activeProject),
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

  void _showProjectSelector(BuildContext context, WidgetRef ref) {
    final projectState = ref.read(projectProvider);
    showDialog(
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
                    Navigator.pop(context);
                  },
                ),
              ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () async {
                // TODO: implement folder picker
                Navigator.pop(context);
              },
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Add Project'),
            ),
          ],
        ),
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

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isCompact;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.isCompact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: isCompact ? 8 : 12,
          vertical: 4,
        ),
        padding: EdgeInsets.symmetric(
          vertical: 12,
          horizontal: isCompact ? 8 : 12,
        ),
        decoration: BoxDecoration(
          color: isActive ? AppColors.surfaceHover : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isActive ? Border.all(color: AppColors.primary, width: 1) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: isActive ? AppColors.primary : AppColors.textMuted, size: 22),
            if (!isCompact) ...[
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: isActive ? AppColors.primary : AppColors.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
