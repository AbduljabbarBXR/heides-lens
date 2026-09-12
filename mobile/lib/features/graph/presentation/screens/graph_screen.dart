import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:spikey/shared/themes/app_colors.dart';
import 'package:spikey/core/providers/indexing_provider.dart';
import 'package:spikey/core/providers/project_provider.dart';
import 'package:spikey/data/services/indexing_engine.dart';

class GraphScreen extends ConsumerWidget {
  const GraphScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                        Text('No indexed files. Select a project to index.', style: AppTextStyles.body.copyWith(color: AppColors.textMuted)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () async {
                            if (projectState.activeProject != null) {
                              final engine = ref.read(indexingEngineProvider);
                              await engine.indexProject(projectState.activeProject!.path);
                              ref.invalidate(indexedFilesProvider);
                            }
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Index Project'),
                        ),
                      ],
                    ),
                  );
                }
                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4,
                  child: CustomPaint(
                    size: Size(files.length * 120.0 + 200, 600),
                    painter: IndexedGraphPainter(files: files),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (error, _) => Center(
                child: Column(
                  children: [
                    const Icon(Icons.error_rounded, size: 48, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text('Error loading graph: $error', style: AppTextStyles.body.copyWith(color: AppColors.textMuted)),
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

class IndexedGraphPainter extends CustomPainter {
  final List<IndexedFile> files;

  IndexedGraphPainter({required this.files});

  @override
  void paint(Canvas canvas, Size size) {
    final nodePaint = Paint()..color = AppColors.primary;
    final edgePaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final nodePositions = <String, Offset>{};
    final spacing = 120.0;
    final startX = 100.0;
    final startY = 100.0;

    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final x = startX + (i % 5) * spacing;
      final y = startY + (i ~/ 5) * spacing;
      final pos = Offset(x, y);
      nodePositions[file.path] = pos;

      canvas.drawCircle(pos, 20, nodePaint);
      final label = p.basename(file.path);
      textPainter.text = TextSpan(text: label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 10, fontWeight: FontWeight.w600));
      textPainter.layout();
      textPainter.paint(canvas, pos - Offset(textPainter.width / 2, 35));
    }

    // Draw edges between sequential files for visual effect
    for (var i = 0; i < files.length - 1; i++) {
      final from = nodePositions[files[i].path]!;
      final to = nodePositions[files[i + 1].path]!;
      canvas.drawLine(from, to, edgePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
