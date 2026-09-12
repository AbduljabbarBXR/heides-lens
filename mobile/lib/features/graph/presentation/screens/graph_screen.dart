import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spikey/shared/themes/app_colors.dart';

class GraphScreen extends ConsumerWidget {
  const GraphScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHover,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text('3 nodes • 3 edges', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ),
              ],
            ),
          ),
          // Graph view
          Expanded(
            child: Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: CustomPaint(
                  size: const Size(800, 600),
                  painter: NeuralGraphPainter(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NeuralGraphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final nodePaint = Paint()..color = AppColors.primary;
    final edgePaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Sample nodes
    final nodes = [
      _GraphNode('Client', const Offset(100, 300)),
      _GraphNode('API Gateway', const Offset(300, 200)),
      _GraphNode('User Service', const Offset(500, 100)),
      _GraphNode('Order Service', const Offset(500, 300)),
      _GraphNode('Database', const Offset(700, 200)),
    ];

    // Sample edges
    final edges = [
      _GraphEdge(nodes[0], nodes[1]),
      _GraphEdge(nodes[1], nodes[2]),
      _GraphEdge(nodes[1], nodes[3]),
      _GraphEdge(nodes[2], nodes[4]),
      _GraphEdge(nodes[3], nodes[4]),
    ];

    // Draw edges
    for (final edge in edges) {
      canvas.drawLine(edge.from.position, edge.to.position, edgePaint);
    }

    // Draw nodes
    for (final node in nodes) {
      canvas.drawCircle(node.position, 30, nodePaint);
      textPainter.text = TextSpan(text: node.label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600));
      textPainter.layout();
      textPainter.paint(canvas, node.position - Offset(textPainter.width / 2, 45));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GraphNode {
  final String label;
  final Offset position;

  _GraphNode(this.label, this.position);
}

class _GraphEdge {
  final _GraphNode from;
  final _GraphNode to;

  _GraphEdge(this.from, this.to);
}
