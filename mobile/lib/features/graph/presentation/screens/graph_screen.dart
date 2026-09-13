import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:spikey/shared/themes/app_colors.dart';
import 'package:spikey/core/providers/indexing_provider.dart';
import 'package:spikey/core/providers/project_provider.dart';
import 'package:spikey/data/services/indexing_engine.dart';

class GraphScreen extends ConsumerStatefulWidget {
  const GraphScreen({super.key});

  @override
  ConsumerState<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends ConsumerState<GraphScreen> {
  bool _indexing = false;
  double _indexProgress = 0.0;
  final Map<String, Offset> _nodePositions = {};
  final Map<String, Size> _nodeSizes = {};
  Offset? _dragStart;
  String? _draggingPath;

  @override
  Widget build(BuildContext context) {
    final projectState = ref.watch(projectProvider);
    final filesAsync = ref.watch(indexedFilesProvider);

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
                Icon(Icons.account_tree_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Text('Neural Graph', style: AppTextStyles.h3),
                const Spacer(),
                filesAsync.when(
                  data: (files) {
                    final edgeCount = files.length > 1 ? files.length - 1 : 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHover,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text('${files.length} nodes • $edgeCount edges', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    );
                  },
                  loading: () => const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                  error: (_, __) => const Icon(Icons.error_rounded, size: 16, color: AppColors.error),
                ),
              ],
            ),
          ),
          if (_indexing)
            LinearProgressIndicator(value: _indexProgress, backgroundColor: AppColors.surface, color: AppColors.primary),
          // Graph view
          Expanded(
            child: filesAsync.when(
              data: (files) {
                if (files.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open_rounded, size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 16),
                        Text('No indexed files. Select a project and tap Index Project.', style: AppTextStyles.body.copyWith(color: AppColors.textMuted)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () async {
                            if (projectState.activeProject != null) {
                              final engine = ref.read(indexingEngineProvider);
                              try {
                                setState(() {
                                  _indexing = true;
                                  _indexProgress = 0.0;
                                });
                                await engine.indexProject(
                                  projectState.activeProject!.path,
                                  onProgress: (current, total) {
                                    setState(() => _indexProgress = current / total);
                                  },
                                );
                                ref.invalidate(indexedFilesProvider);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Indexing failed: $e'),
                                      backgroundColor: AppColors.surface,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } finally {
                                setState(() => _indexing = false);
                              }
                            }
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Index Project'),
                        ),
                      ],
                    ),
                  );
                }
                return FutureBuilder<Map<String, dynamic>>(
                  future: _loadGraphData(ref, files, projectState.activeProject?.path ?? ''),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          children: [
                            Icon(Icons.error_rounded, size: 48, color: AppColors.error),
                            const SizedBox(height: 16),
                            Text('Error loading graph: ${snapshot.error}', style: AppTextStyles.body.copyWith(color: AppColors.textMuted)),
                          ],
                        ),
                      );
                    }
                    final graphData = snapshot.data;
                    if (graphData == null) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                    }
                    final filesList = graphData['files'] as List<IndexedFile>;
                    final edges = graphData['edges'] as List<Map<String, dynamic>>;
                    
                    // Initialize positions if not set
                    if (_nodePositions.isEmpty) {
                      final spacingX = 260.0;
                      final spacingY = 200.0;
                      final startX = 80.0;
                      final startY = 80.0;
                      for (var i = 0; i < filesList.length; i++) {
                        final col = i % 4;
                        final row = i ~/ 4;
                        _nodePositions[filesList[i].path] = Offset(startX + col * spacingX, startY + row * spacingY);
                      }
                    }

                    final width = (filesList.length > 4 ? 4 : filesList.length) * 260.0 + 200;
                    final height = ((filesList.length / 4).ceil()) * 200.0 + 200;

                    return InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4,
                      child: Container(
                        width: width,
                        height: height,
                        color: AppColors.background,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Edges layer (painted first, behind cards)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _GraphEdgePainter(
                                  files: filesList,
                                  edges: edges,
                                  nodePositions: _nodePositions,
                                  nodeSizes: _nodeSizes,
                                ),
                              ),
                            ),
                            // Cards layer (draggable, on top of edges)
                            ...filesList.map((file) {
                              final pos = _nodePositions[file.path] ?? Offset.zero;
                              final size = _nodeSizes[file.path] ?? const Size(220, 120);
                              return Positioned(
                                left: pos.dx,
                                top: pos.dy,
                                child: _DraggableNode(
                                  file: file,
                                  edges: edges,
                                  allFiles: filesList,
                                  onDragStart: (path, globalPos) {
                                    _draggingPath = path;
                                    _dragStart = globalPos;
                                  },
                                  onDragUpdate: (path, globalPos) {
                                    if (_dragStart != null && _draggingPath == path) {
                                      final delta = globalPos - _dragStart!;
                                      final currentPos = _nodePositions[path] ?? Offset.zero;
                                      setState(() {
                                        _nodePositions[path] = Offset(currentPos.dx + delta.dx, currentPos.dy + delta.dy);
                                        _dragStart = globalPos;
                                      });
                                    }
                                  },
                                  onDragEnd: () {
                                    _dragStart = null;
                                    _draggingPath = null;
                                  },
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (error, _) => Center(
                child: Column(
                  children: [
                    Icon(Icons.error_rounded, size: 48, color: AppColors.error),
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

  Future<Map<String, dynamic>> _loadGraphData(WidgetRef ref, List<IndexedFile> files, String projectPath) async {
    final engine = ref.read(indexingEngineProvider);
    final edges = <Map<String, dynamic>>[];
    final nodePositions = <String, Offset>{};

    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final x = 80.0 + (i % 4) * 260.0;
      final y = 80.0 + (i ~/ 4) * 200.0;
      nodePositions[file.path] = Offset(x, y);
    }

    for (final file in files) {
      final deps = await engine.getDependencies(file.path);
      for (final imp in deps['imports'] as List<Map<String, dynamic>>) {
        final module = imp['to_module'] as String;
        final target = files.firstWhereOrNull((f) {
          final base = p.basenameWithoutExtension(f.path);
          final full = f.path;
          return base == module || full.contains(module) || module.contains(base);
        });
        if (target != null && nodePositions[file.path] != null && nodePositions[target.path] != null) {
          edges.add({'from': file.path, 'to': target.path, 'type': 'import', 'line': imp['line'] as int});
        }
      }
    }

    return {'files': files, 'nodes': nodePositions, 'edges': edges};
  }
}

class _DraggableNode extends StatefulWidget {
  final IndexedFile file;
  final List<Map<String, dynamic>> edges;
  final List<IndexedFile> allFiles;
  final void Function(String path, Offset globalPos) onDragStart;
  final void Function(String path, Offset globalPos) onDragUpdate;
  final VoidCallback onDragEnd;

  const _DraggableNode({
    required this.file,
    required this.edges,
    required this.allFiles,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  State<_DraggableNode> createState() => _DraggableNodeState();
}

class _DraggableNodeState extends State<_DraggableNode> {
  @override
  Widget build(BuildContext context) {
    final fileName = p.basename(widget.file.path);
    final connectedFiles = <String>{};
    for (final edge in widget.edges) {
      if (edge['from'] == widget.file.path) {
        final toPath = edge['to'] as String;
        final toFile = widget.allFiles.firstWhereOrNull((f) => f.path == toPath);
        if (toFile != null) {
          connectedFiles.add(p.basename(toFile.path));
        }
      }
      if (edge['to'] == widget.file.path) {
        final fromPath = edge['from'] as String;
        final fromFile = widget.allFiles.firstWhereOrNull((f) => f.path == fromPath);
        if (fromFile != null) {
          connectedFiles.add(p.basename(fromFile.path));
        }
      }
    }

    return GestureDetector(
      onPanStart: (details) {
        widget.onDragStart(widget.file.path, details.globalPosition);
      },
      onPanUpdate: (details) {
        widget.onDragUpdate(widget.file.path, details.globalPosition);
      },
      onPanEnd: (details) {
        widget.onDragEnd();
      },
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: AppColors.surfaceHover,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
              ),
              child: Row(
                children: [
                  Icon(Icons.data_object_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fileName,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Connected files
            ...connectedFiles.take(4).map((name) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 8),
                    Expanded(child: Text(name, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _GraphEdgePainter extends CustomPainter {
  final List<IndexedFile> files;
  final List<Map<String, dynamic>> edges;
  final Map<String, Offset> nodePositions;
  final Map<String, Size> nodeSizes;

  _GraphEdgePainter({
    required this.files,
    required this.edges,
    required this.nodePositions,
    required this.nodeSizes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final edgePaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final edge in edges) {
      final fromPath = edge['from'] as String;
      final toPath = edge['to'] as String;
      final fromPos = nodePositions[fromPath];
      final toPos = nodePositions[toPath];
      if (fromPos == null || toPos == null) continue;

      final fromSize = nodeSizes[fromPath] ?? const Size(220, 120);
      final toSize = nodeSizes[toPath] ?? const Size(220, 120);

      // Connect right side of source to left side of target
      final start = Offset(fromPos.dx + fromSize.width, fromPos.dy + fromSize.height / 2);
      final end = Offset(toPos.dx, toPos.dy + toSize.height / 2);
      
      // Draw bezier curve
      final controlPoint1 = Offset(start.dx + (end.dx - start.dx) / 2, start.dy);
      final controlPoint2 = Offset(start.dx + (end.dx - start.dx) / 2, end.dy);
      
      final path = Path();
      path.moveTo(start.dx, start.dy);
      path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, end.dx, end.dy);
      canvas.drawPath(path, edgePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

extension IndexedFileListExtension on List<IndexedFile> {
  IndexedFile? firstWhereOrNull(bool Function(IndexedFile) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
