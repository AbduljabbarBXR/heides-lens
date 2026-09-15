import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import 'package:heides_lens/shared/themes/app_colors.dart';

/// Read-only source viewer. Heides Lens is a lens, not an editor — the user
/// applies changes in their own editor; this widget only displays content.
class FileContentViewer extends StatefulWidget {
  final String filePath;
  final String? diffContent;

  const FileContentViewer({super.key, required this.filePath, this.diffContent});

  @override
  State<FileContentViewer> createState() => _FileContentViewerState();
}

class _FileContentViewerState extends State<FileContentViewer> {
  String _content = '';
  bool _isLoading = true;

  @override
  void didUpdateWidget(covariant FileContentViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath || oldWidget.diffContent != widget.diffContent) {
      _loadContent();
    }
  }

  Future<void> _loadContent() async {
    setState(() => _isLoading = true);
    try {
      if (widget.diffContent != null) {
        setState(() {
          _content = widget.diffContent!;
          _isLoading = false;
        });
      } else {
        final file = File(widget.filePath);
        final content = await file.readAsString();
        setState(() {
          _content = content;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _content = 'Error loading file: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = _content.split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Icon(_getFileIcon(widget.filePath), size: 16, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.filePath.split('/').last,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${lines.length} lines',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const SizedBox(width: 8),
              const Tooltip(
                message: 'Read-only — edit in your own editor',
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
        // Language bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Text(
                _getLanguage(widget.filePath).toUpperCase(),
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
              const SizedBox(width: 16),
              const Text(
                'UTF-8',
                style: TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
              const Spacer(),
              const Text(
                'read-only',
                style: TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        // File content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: HighlightView(
                    _content,
                    language: _getLanguage(widget.filePath),
                    theme: vs2015Theme,
                    padding: EdgeInsets.zero,
                    textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
        ),
      ],
    );
  }

  String _getLanguage(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'dart': return 'dart';
      case 'ts': case 'tsx': return 'typescript';
      case 'js': case 'jsx': return 'javascript';
      case 'py': return 'python';
      case 'go': return 'go';
      case 'rs': return 'rust';
      case 'java': return 'java';
      case 'json': return 'json';
      case 'yaml': case 'yml': return 'yaml';
      case 'css': return 'css';
      case 'html': return 'html';
      case 'md': return 'markdown';
      default: return 'plaintext';
    }
  }

  IconData _getFileIcon(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'dart': return Icons.code_rounded;
      case 'ts': case 'tsx': return Icons.data_object_rounded;
      case 'js': case 'jsx': return Icons.data_object_rounded;
      case 'py': return Icons.memory_rounded;
      case 'json': return Icons.data_object_rounded;
      case 'yaml': case 'yml': return Icons.settings_rounded;
      case 'css': return Icons.palette_rounded;
      case 'html': return Icons.language_rounded;
      case 'md': return Icons.description_rounded;
      default: return Icons.description_rounded;
    }
  }
}
