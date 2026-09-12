import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spikey/shared/themes/app_colors.dart';

class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final findings = _getSampleFindings();

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
                _SeverityBadge(count: findings.where((f) => f['severity'] == 'critical').length, label: 'Critical', color: AppColors.error),
                const SizedBox(width: 8),
                _SeverityBadge(count: findings.where((f) => f['severity'] == 'warning').length, label: 'Warnings', color: AppColors.warning),
                const SizedBox(width: 8),
                _SeverityBadge(count: findings.where((f) => f['severity'] == 'info').length, label: 'Info', color: AppColors.info),
              ],
            ),
          ),
          // Findings list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: findings.length,
              itemBuilder: (context, index) {
                final finding = findings[index];
                return _FindingCard(finding: finding);
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getSampleFindings() {
    return [
      {
        'id': '1',
        'severity': 'critical',
        'category': 'Security',
        'title': 'Hardcoded password',
        'description': 'Hardcoded credentials should never be committed to source control.',
        'location': 'index.js:9',
        'suggestion': 'Move credentials to environment variables.',
      },
      {
        'id': '2',
        'severity': 'warning',
        'category': 'Performance',
        'title': 'Missing error handling',
        'description': 'Async function without try-catch may crash on failure.',
        'location': 'api/users.ts:45',
        'suggestion': 'Add try-catch with proper error propagation.',
      },
      {
        'id': '3',
        'severity': 'info',
        'category': 'Style',
        'title': 'Consider type guards',
        'description': 'Adding type guards improves type safety.',
        'location': 'utils/helpers.ts:12',
        'suggestion': 'Use Zod or io-ts for runtime validation.',
      },
    ];
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
        color: color.withOpacity(0.15),
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
        border: Border.all(color: color.withOpacity(0.3)),
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
