import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spikey/shared/themes/app_colors.dart';
import 'package:spikey/core/providers/project_provider.dart';

class FileTreeViewer extends ConsumerWidget {
  final String projectPath;
  final Function(String filePath)? onFileTap;

  const FileTreeViewer({super.key, required this.projectPath, this.onFileTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectState = ref.watch(projectProvider);
    final activeProject = projectState.activeProject;

    if (activeProject == null) {
      return const Center(
        child: Text('No project selected', style: TextStyle(color: AppColors.textMuted)),
      );
    }

    return FutureBuilder<List<_FileNode>>(
      future: _scanDirectory(activeProject.path),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final files = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: files.length,
          itemBuilder: (context, index) {
            final file = files[index];
            return _FileTile(
              file: file,
              depth: 0,
              onTap: onFileTap != null ? () => onFileTap!(file.path) : null,
            );
          },
        );
      },
    );
  }

  Future<List<_FileNode>> _scanDirectory(String dirPath) async {
    final nodes = <_FileNode>[];
    await _scanRecursive(dirPath, 0, nodes);
    return nodes;
  }

  Future<void> _scanRecursive(String dirPath, int depth, List<_FileNode> nodes) async {
    try {
      final entries = await Directory(dirPath).list().toList();
      for (final entry in entries) {
        final name = entry.path.split(Platform.pathSeparator).last;
        if (name.startsWith('.') || name == 'node_modules' || name == 'build' || name == 'dist') continue;
        
        if (entry is Directory) {
          nodes.add(_FileNode(name: name, path: entry.path, isDirectory: true, depth: depth));
          await _scanRecursive(entry.path, depth + 1, nodes);
        } else if (entry is File) {
          final ext = name.split('.').last.toLowerCase();
          final isSupported = ['.dart', '.ts', '.js', '.py', '.go', '.rs', '.java', '.c', '.cpp'].any((s) => ext == s.replaceFirst('.', ''));
          if (isSupported) {
            nodes.add(_FileNode(name: name, path: entry.path, isDirectory: false, depth: depth));
          }
        }
      }
    } catch (e) {
      // Skip inaccessible directories
    }
  }
}

class _FileNode {
  final String name;
  final String path;
  final bool isDirectory;
  final int depth;

  _FileNode({required this.name, required this.path, required this.isDirectory, required this.depth});
}

class _FileTile extends StatelessWidget {
  final _FileNode file;
  final int depth;
  final VoidCallback? onTap;

  const _FileTile({required this.file, required this.depth, this.onTap});

  @override
  Widget build(BuildContext context) {
    final icon = file.isDirectory ? Icons.folder_rounded : _getFileIcon(file.name);
    final color = file.isDirectory ? AppColors.warning : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.only(left: depth * 16 + 8, right: 8, top: 4, bottom: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                file.name,
                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'dart': return Icons.code_rounded;
      case 'ts': case 'tsx': return Icons.data_object_rounded;
      case 'js': case 'jsx': return Icons.data_object_rounded;
      case 'py': return Icons.memory_rounded;
      case 'go': return Icons.memory_rounded;
      case 'rs': return Icons.memory_rounded;
      case 'java': return Icons.coffee_rounded;
      case 'json': return Icons.data_object_rounded;
      default: return Icons.description_rounded;
    }
  }
}
