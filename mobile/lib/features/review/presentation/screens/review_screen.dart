import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spikey/shared/themes/app_colors.dart';
import 'package:spikey/core/providers/findings_provider.dart';
import 'package:spikey/core/providers/project_provider.dart';

class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectState = ref.watch(projectProvider);
    final activeProject = projectState.activeProject;

    if (activeProject == null) {
      return const Center(
        child: Text('Select a project to view findings', style: TextStyle(color: AppColors.textMuted)),
      );
    }

    final findingsAsync = ref.watch(findingsProvider(activeProject.path));

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
                Icon(Icons.verified_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Text('Review', style: AppTextStyles.h3),
                const Spacer(),
                findingsAsync.when(
                  data: (findings) {
                    final criticalCount = findings.where((f) => f['severity'] == 'critical').length;
                    final warningCount = findings.where((f) => f['severity'] == 'warning').length;
                    final infoCount = findings.where((f) => f['severity'] == 'info').length;
                    return Row(
                      children: [
                        _SeverityBadge(count: criticalCount, label: 'Critical', color: AppColors.error),
                        const SizedBox(width: 8),
                        _SeverityBadge(count: warningCount, label: 'Warnings', color: AppColors.warning),
                        const SizedBox(width: 8),
                        _SeverityBadge(count: infoCount, label: 'Info', color: AppColors.info),
                      ],
                    );
                  },
                  loading: () => const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                  error: (_, __) => const Icon(Icons.error_rounded, size: 16, color: AppColors.error),
                ),
              ],
            ),
          ),
          // Findings list
          Expanded(
            child: findingsAsync.when(
              data: (findings) {
                if (findings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 48, color: AppColors.success),
                        const SizedBox(height: 16),
                        Text('No findings found', style: AppTextStyles.body.copyWith(color: AppColors.textMuted)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: findings.length,
                  itemBuilder: (context, index) {
                    final finding = findings[index];
                    return _FindingCard(finding: finding);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (error, _) => Center(
                child: Column(
                  children: [
                    const Icon(Icons.error_rounded, size: 48, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text('Error: $error', style: AppTextStyles.body.copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _SeverityBadge({required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Text('$count ', style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

class _FindingCard extends StatelessWidget {
  final Map<String, dynamic> finding;

  const _FindingCard({required this.finding});

  @override
  Widget build(BuildContext context) {
    final severity = finding['severity'] as String;
    final color = severity == 'critical' ? AppColors.error : severity == 'warning' ? AppColors.warning : AppColors.info;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(finding['category'] as String, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(finding['location'] as String, style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontFamily: 'JetBrainsMono')),
            ],
          ),
          const SizedBox(height: 8),
          Text(finding['title'] as String, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14)),
          const SizedBox(height: 4),
          Text(finding['description'] as String, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          if (finding['suggestion'] != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceHover,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_rounded, size: 14, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(finding['suggestion'] as String, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
