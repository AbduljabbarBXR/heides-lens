import 'package:flutter/material.dart';

class GraphNode {
  final String id;
  final String label;
  final Offset position;
  final double radius;

  GraphNode({required this.id, required this.label, required this.position, this.radius = 20});
}

class GraphEdge {
  final String from;
  final String to;
  final double weight;

  GraphEdge({required this.from, required this.to, this.weight = 0.5});
}

class GraphViewScreen extends StatelessWidget {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;

  const GraphViewScreen({super.key, required this.nodes, required this.edges});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Neural Graph')),
      body: InteractiveViewer(
        minScale: 0.1,
        maxScale: 4,
        child: CustomPaint(
          size: Size(nodes.length * 120.0, 600),
          painter: GraphPainter(nodes: nodes, edges: edges),
        ),
      ),
    );
  }
}

class GraphPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;

  GraphPainter({required this.nodes, required this.edges});

  @override
  void paint(Canvas canvas, Size size) {
    final nodeMap = {for (final n in nodes) n.id: n};
    final edgePaint = Paint()..color = const Color(0xFF333344)..strokeWidth = 2;
    final nodePaint = Paint()..color = const Color(0xFF00CCFF);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (final edge in edges) {
      final from = nodeMap[edge.from];
      final to = nodeMap[edge.to];
      if (from != null && to != null) {
        canvas.drawLine(from.position, to.position, edgePaint);
      }
    }

    for (final node in nodes) {
      canvas.drawCircle(node.position, node.radius, nodePaint);
      textPainter.text = TextSpan(text: node.label, style: const TextStyle(color: Colors.white, fontSize: 10));
      textPainter.layout();
      textPainter.paint(canvas, node.position - Offset(textPainter.width / 2, node.radius + 4));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
