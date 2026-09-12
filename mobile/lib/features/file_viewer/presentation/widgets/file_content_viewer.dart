import 'dart:io';
import 'package:flutter/material.dart';
import 'package:spikey/shared/themes/app_colors.dart';

class FileContentViewer extends StatelessWidget {
  final String filePath;
  final String? diffContent;

  const FileContentViewer({super.key, required this.filePath, this.diffContent});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _loadContent(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final content = snapshot.data!;
        final lines = content.split('\n');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Icon(_getFileIcon(filePath), size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Text(
                    filePath.split('/').last,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  Text(
                    '${lines.length} lines',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            // File content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: diffContent != null
                    ? _buildDiffViewer(diffContent!)
                    : _buildCodeViewer(content),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCodeViewer(String content) {
    final lines = content.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontFamily: 'monospace'),
                  ),
                ),
                Expanded(
                  child: Text(
                    lines[i],
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDiffViewer(String diff) {
    final lines = diff.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines.length; i++)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            color: _getDiffLineColor(lines[i]),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    lines[i].startsWith('@@') ? '' : '${i + 1}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontFamily: 'monospace'),
                  ),
                ),
                Expanded(
                  child: Text(
                    lines[i],
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Color _getDiffLineColor(String line) {
    if (line.startsWith('+') && !line.startsWith('+++')) return AppColors.primary.withValues(alpha: 0.1);
    if (line.startsWith('-') && !line.startsWith('---')) return AppColors.error.withValues(alpha: 0.1);
    if (line.startsWith('@@')) return AppColors.surfaceHover;
    return Colors.transparent;
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

  Future<String> _loadContent() async {
    if (diffContent != null) return diffContent!;
    return File(filePath).readAsString();
  }
}
