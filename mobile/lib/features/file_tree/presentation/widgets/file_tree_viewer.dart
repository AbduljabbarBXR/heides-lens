import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
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

    return FutureBuilder<_FileNode>(
      future: _buildTree(activeProject.path),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final root = snapshot.data!;
        return _TreeView(
          root: root,
          depth: 0,
          onFileTap: onFileTap,
        );
      },
    );
  }

  Future<_FileNode> _buildTree(String dirPath) async {
    final root = _FileNode(name: p.basename(dirPath), path: dirPath, isDirectory: true, depth: 0);
    await _populateDirectory(dirPath, root, 0);
    return root;
  }

  Future<void> _populateDirectory(String dirPath, _FileNode parent, int depth) async {
    try {
      final entries = await Directory(dirPath).list().toList();
      entries.sort((a, b) {
        final aName = a.path.split(Platform.pathSeparator).last;
        final bName = b.path.split(Platform.pathSeparator).last;
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        return aName.compareTo(bName);
      });

      for (final entry in entries) {
        final name = entry.path.split(Platform.pathSeparator).last;
        if (name.startsWith('.') || name == 'node_modules' || name == 'build' || name == 'dist') continue;

        if (entry is Directory) {
          final node = _FileNode(name: name, path: entry.path, isDirectory: true, depth: depth + 1);
          parent.children.add(node);
          await _populateDirectory(entry.path, node, depth + 1);
        } else if (entry is File) {
          final ext = name.split('.').last.toLowerCase();
          final isSupported = ['.dart', '.ts', '.js', '.py', '.go', '.rs', '.java', '.c', '.cpp', '.jsx', '.tsx', '.h', '.rb', '.php'].any((s) => ext == s.replaceFirst('.', ''));
          if (isSupported) {
            parent.children.add(_FileNode(name: name, path: entry.path, isDirectory: false, depth: depth + 1));
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
  final List<_FileNode> children;
  bool isExpanded;

  _FileNode({required this.name, required this.path, required this.isDirectory, required this.depth, List<_FileNode>? children})
      : children = children != null ? List.from(children) : <_FileNode>[],
        isExpanded = false;
}

class _TreeView extends StatefulWidget {
  final _FileNode root;
  final int depth;
  final Function(String filePath)? onFileTap;

  const _TreeView({required this.root, required this.depth, this.onFileTap});

  @override
  State<_TreeView> createState() => _TreeViewState();
}

class _TreeViewState extends State<_TreeView> {
  @override
  Widget build(BuildContext context) {
    return _FileTile(
      file: widget.root,
      depth: widget.depth,
      onTap: widget.root.isDirectory ? () {
        setState(() {
          widget.root.isExpanded = !widget.root.isExpanded;
        });
      } : widget.onFileTap != null ? () => widget.onFileTap!(widget.root.path) : null,
      child: widget.root.isExpanded && widget.root.children.isNotEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.root.children.map((child) => _TreeView(
                root: child,
                depth: widget.depth + 1,
                onFileTap: widget.onFileTap,
              )).toList(),
            )
          : null,
    );
  }
}

class _FileTile extends StatelessWidget {
  final _FileNode file;
  final int depth;
  final VoidCallback? onTap;
  final Widget? child;

  const _FileTile({required this.file, required this.depth, this.onTap, this.child});

  @override
  Widget build(BuildContext context) {
    final icon = file.isDirectory
        ? (file.isExpanded ? Icons.folder_open_rounded : Icons.folder_rounded)
        : _getFileIcon(file.name);
    final color = file.isDirectory ? AppColors.warning : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.only(left: depth * 16 + 8, right: 8, top: 4, bottom: 4),
            decoration: BoxDecoration(
              color: onTap != null && file.isDirectory ? AppColors.surfaceHover : Colors.transparent,
            ),
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
                if (file.isDirectory && file.children.isNotEmpty)
                  Icon(
                    file.isExpanded ? Icons.expand_more_rounded : Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
              ],
            ),
          ),
        ),
        if (child != null) child!,
      ],
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
