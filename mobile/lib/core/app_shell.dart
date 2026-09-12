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
  double _sidebarMinWidth = 120;
  double _sidebarMaxWidth = 320;

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(navigationProvider);
    final projectState = ref.watch(projectProvider);

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: _sidebarWidth,
            color: AppColors.surface,
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Logo
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome, color: AppColors.background, size: 24),
                ),
                const SizedBox(height: 24),
                const Divider(height: 1, thickness: 1),
                const SizedBox(height: 16),
                // Nav items
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
                const Spacer(),
                // Project selector
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: GestureDetector(
                    onTap: () => _showProjectSelector(context, ref),
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

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.surfaceHover : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isActive ? Border.all(color: AppColors.primary, width: 1) : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: isActive ? AppColors.primary : AppColors.textMuted, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, color: isActive ? AppColors.primary : AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
