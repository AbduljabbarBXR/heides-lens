import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import 'package:spikey/shared/themes/app_colors.dart';

class FileContentViewer extends StatefulWidget {
  final String filePath;
  final String? diffContent;

  const FileContentViewer({super.key, required this.filePath, this.diffContent});

  @override
  State<FileContentViewer> createState() => _FileContentViewerState();
}

class _FileContentViewerState extends State<FileContentViewer> {
  bool _isEditing = false;
  late TextEditingController _controller;
  String _content = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _loadContent();
  }

  @override
  void didUpdateWidget(covariant FileContentViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _loadContent();
    }
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _isEditing = false;
    });
    try {
      if (widget.diffContent != null) {
        setState(() {
          _content = widget.diffContent!;
          _controller.text = _content;
          _isLoading = false;
        });
      } else {
        final file = File(widget.filePath);
        final content = await file.readAsString();
        setState(() {
          _content = content;
          _controller.text = content;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _content = 'Error loading file: $e';
        _controller.text = _content;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveFile() async {
    try {
      final file = File(widget.filePath);
      await file.writeAsString(_controller.text);
      setState(() {
        _content = _controller.text;
        _isEditing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved ${widget.filePath.split('/').last}'),
            backgroundColor: AppColors.surface,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: AppColors.surface,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = _content.split('\n');

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
              Icon(_getFileIcon(widget.filePath), size: 16, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.filePath.split('/').last,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${lines.length} lines',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const SizedBox(width: 8),
              if (!_isEditing)
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 16, color: AppColors.textSecondary),
                  onPressed: () => setState(() => _isEditing = true),
                  tooltip: 'Edit',
                )
              else ...[
                IconButton(
                  icon: const Icon(Icons.save_rounded, size: 16, color: AppColors.success),
                  onPressed: _saveFile,
                  tooltip: 'Save',
                ),
                IconButton(
                  icon: const Icon(Icons.cancel_rounded, size: 16, color: AppColors.error),
                  onPressed: () {
                    setState(() {
                      _isEditing = false;
                      _controller.text = _content;
                    });
                  },
                  tooltip: 'Cancel',
                ),
              ],
            ],
          ),
        ),
        // File content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _isEditing
                  ? TextField(
                      controller: _controller,
                      maxLines: null,
                      expands: true,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                      keyboardType: TextInputType.multiline,
                    )
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
      default: return Icons.description_rounded;
    }
  }
}
