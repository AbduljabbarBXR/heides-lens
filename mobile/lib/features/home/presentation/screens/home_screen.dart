import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heides_lens/shared/themes/app_colors.dart';
import 'package:heides_lens/shared/logos.dart';
import 'package:heides_lens/core/providers/project_provider.dart';
import 'package:heides_lens/core/providers/findings_provider.dart';
import 'package:heides_lens/core/providers/heides_provider.dart';
import 'package:heides_lens/core/providers/indexing_provider.dart';
import 'package:heides_lens/core/providers/navigation_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final projectState = ref.watch(projectProvider);
    final project = projectState.activeProject;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Icon(Icons.space_dashboard_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Text('Home', style: AppTextStyles.h3),
                const Spacer(),
                if (project != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHover,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder_rounded, size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(project.name,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: project == null ? _buildEmptyState() : _buildDashboard(project),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HeidesLogoMark(id: 2, size: 72),
          const SizedBox(height: 20),
          const Text(
            'The nervous system for your code, with eyes.',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Open a folder and HEIDES maps every file, symbol, and call into a living mesh.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _ActionButton(
            icon: Icons.folder_open_rounded,
            label: 'Open Folder',
            onTap: () => ref.read(navigationProvider.notifier).setMode(AppMode.explorer),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(Project project) {
    final findingsAsync = ref.watch(findingsProvider(project.path));
    final heidesAsync = ref.watch(heidesAvailableProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Hero row
        Row(
          children: [
            Expanded(
              child: _buildProjectCard(project),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildFindingsCard(findingsAsync),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Action tiles
        Row(
          children: [
            Expanded(child: _ActionCard(
              icon: Icons.account_tree_rounded,
              title: 'Neural Mesh',
              subtitle: 'See every file, symbol, and call',
              color: AppColors.primary,
              onTap: () => ref.read(navigationProvider.notifier).setMode(AppMode.graph),
            )),
            const SizedBox(width: 12),
            Expanded(child: _ActionCard(
              icon: Icons.verified_rounded,
              title: 'Review',
              subtitle: 'Findings with file:line evidence',
              color: const Color(0xFFF59E0B),
              onTap: () => ref.read(navigationProvider.notifier).setMode(AppMode.review),
            )),
          ],
        ),
        const SizedBox(height: 16),
        _buildHeidesCard(heidesAsync, project),
      ],
    );
  }

  /// Compact integer formatting for LOC (1.2k, 34k).
  String _formatLoc(int loc) {
    if (loc >= 1000000) return '${(loc / 1000000).toStringAsFixed(1)}M';
    if (loc >= 1000) return '${(loc / 1000).toStringAsFixed(1)}k';
    return '$loc';
  }

  Widget _buildProjectCard(Project project) {
    final filesAsync = ref.watch(indexedFilesProvider(project.path));    return _DashboardCard(
      title: 'Project',
      subtitle: project.path,
      child: filesAsync.when(
        data: (files) {
          // Total LOC — a real second metric, not a duplicate of the file count.
          final loc = files.fold<int>(0, (sum, f) => sum + f.loc);
          return Row(
            children: [
              _Stat(label: '${files.length}', caption: 'files'),
              const SizedBox(width: 24),
              _Stat(label: _formatLoc(loc), caption: 'lines'),
            ],
          );
        },
        loading: () => const Center(
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))),
        error: (_, __) => const Text('Index error', style: TextStyle(color: AppColors.error)),
      ),
    );
  }

  Widget _buildFindingsCard(AsyncValue<List<Map<String, dynamic>>> findingsAsync) {
    return _DashboardCard(
      title: 'Health',
      subtitle: 'Findings in this project',
      child: findingsAsync.when(
        data: (findings) {
          final critical = findings.where((f) => f['severity'] == 'critical').length;
          final warning = findings.where((f) => f['severity'] == 'warning').length;
          final info = findings.where((f) => f['severity'] == 'info').length;
          return Row(
            children: [
              _Stat(label: '$critical', caption: 'critical', color: AppColors.error),
              const SizedBox(width: 24),
              _Stat(label: '$warning', caption: 'warnings', color: AppColors.warning),
              const SizedBox(width: 24),
              _Stat(label: '$info', caption: 'info', color: AppColors.info),
            ],
          );
        },
        loading: () => const Center(
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))),
        error: (_, __) => const Text('No findings', style: TextStyle(color: AppColors.textMuted)),
      ),
    );
  }

  Widget _buildHeidesCard(AsyncValue<bool> heidesAsync, Project project) {
    return heidesAsync.when(
      data: (available) => _DashboardCard(
        title: 'HEIDES Engine',
        subtitle: available ? 'Attached — workspace mapped' : 'Not detected',
        child: Row(
          children: [
            Icon(
              available ? Icons.check_circle_rounded : Icons.error_rounded,
              color: available ? AppColors.success : AppColors.error,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                available
                    ? 'The code nervous system is indexing ${project.name} into a persistent graph.'
                    : 'Install HEIDES to map your codebase into a graph you can see and query.',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      ),
      loading: () => const _DashboardCard(title: 'HEIDES Engine', subtitle: 'Checking...', child: SizedBox()),
      error: (_, __) => const _DashboardCard(title: 'HEIDES Engine', subtitle: 'Unavailable', child: SizedBox()),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _DashboardCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String caption;
  final Color color;

  const _Stat({required this.label, required this.caption, this.color = AppColors.textPrimary});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: color, fontSize: 22, fontWeight: FontWeight.w700)),
        Text(caption,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ],
    );
  }
}

class _ActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
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
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.surfaceHover : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _isHovered ? widget.color.withValues(alpha: 0.5) : AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, color: widget.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(widget.subtitle,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded,
                  size: 16, color: _isHovered ? widget.color : AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
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
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.primary.withValues(alpha: 0.15) : AppColors.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 18, color: AppColors.background),
              const SizedBox(width: 8),
              Text(widget.label,
                  style: const TextStyle(
                      color: AppColors.background, fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}