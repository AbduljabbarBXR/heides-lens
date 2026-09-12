import 'package:flutter/material.dart';

class DiffViewerScreen extends StatelessWidget {
  final String projectPath;
  final String diffContent;

  const DiffViewerScreen({super.key, required this.projectPath, required this.diffContent});

  @override
  Widget build(BuildContext context) {
    final lines = diffContent.split('\n');
    return Scaffold(
      appBar: AppBar(title: Text('Diff: $projectPath')),
      body: ListView.builder(
        itemCount: lines.length,
        itemBuilder: (context, index) {
          final line = lines[index];
          Color? bg;
          if (line.startsWith('+') && !line.startsWith('+++')) {
            bg = const Color(0xFF0D3B1E);
          } else if (line.startsWith('-') && !line.startsWith('---')) {
            bg = const Color(0xFF3B0D0D);
          }
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            color: bg,
            child: Text(line, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          );
        },
      ),
    );
  }
}
