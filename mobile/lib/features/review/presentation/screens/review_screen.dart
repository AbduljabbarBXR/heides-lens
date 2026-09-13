import 'dart:io';
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
                    return _FindingCard(
                      finding: finding,
                      index: index,
                      projectPath: activeProject.path,
                    );
                  },
                );
              },
              loading: () => const _LoadingReviewState(),
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

class _LoadingReviewState extends StatelessWidget {
  const _LoadingReviewState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Loading findings...',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            'Querying the code index',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
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

class _FindingCard extends StatefulWidget {
  final Map<String, dynamic> finding;
  final int index;
  final String projectPath;

  const _FindingCard({required this.finding, required this.index, required this.projectPath});

  @override
  State<_FindingCard> createState() => _FindingCardState();
}

class _FindingCardState extends State<_FindingCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    // Staggered entrance
    Future.delayed(Duration(milliseconds: widget.index * 60), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openFile() {
    final location = widget.finding['location'] as String;
    final parts = location.split(':');
    if (parts.isEmpty) return;

    final filePath = parts[0];
    final fullPath = '${widget.projectPath}/$filePath';

    if (File(fullPath).existsSync()) {
      // Navigate to file - we need to communicate with AppShell
      // For now, open in a dialog
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: AppColors.surface,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.code_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(filePath, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary))),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _FilePreview(filePath: fullPath, line: parts.length > 1 ? int.tryParse(parts[1]) : null),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final severity = widget.finding['severity'] as String;
    final color = severity == 'critical' ? AppColors.error : severity == 'warning' ? AppColors.warning : AppColors.info;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _openFile,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isHovered ? AppColors.surfaceHover : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _isHovered ? color : color.withValues(alpha: 0.3)),
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
                      Text(widget.finding['category'] as String, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text(widget.finding['location'] as String, style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontFamily: 'JetBrainsMono')),
                      const SizedBox(width: 8),
                      Icon(Icons.open_in_new_rounded, size: 12, color: _isHovered ? AppColors.primary : AppColors.textMuted),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(widget.finding['title'] as String, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(widget.finding['description'] as String, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  if (widget.finding['suggestion'] != null) ...[
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
                            child: Text(widget.finding['suggestion'] as String, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilePreview extends StatefulWidget {
  final String filePath;
  final int? line;

  const _FilePreview({required this.filePath, this.line});

  @override
  State<_FilePreview> createState() => _FilePreviewState();
}

class _FilePreviewState extends State<_FilePreview> {
  String _content = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  Future<void> _loadFile() async {
    try {
      final file = File(widget.filePath);
      final content = await file.readAsString();
      if (mounted) {
        setState(() {
          _content = content;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _content = 'Error loading file: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    final lines = _content.split('\n');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: lines.length,
      itemBuilder: (context, index) {
        final lineNum = index + 1;
        final isTarget = widget.line != null && lineNum == widget.line;
        return Container(
          color: isTarget ? AppColors.primary.withValues(alpha: 0.15) : null,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 40,
                child: Text(
                  '$lineNum',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: isTarget ? AppColors.primary : AppColors.textMuted,
                    fontWeight: isTarget ? FontWeight.w600 : FontWeight.normal,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  lines[index],
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: isTarget ? AppColors.textPrimary : AppColors.textSecondary,
                    fontWeight: isTarget ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
