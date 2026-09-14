import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spikey/core/providers/indexing_provider.dart';

final findingsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, projectPath) async {
  final engine = ref.read(indexingEngineProvider);
  final db = await engine.db.db;

  // Single JOIN query instead of N sequential queries per file.
  // Filter to the active project only.
  final rows = await db.rawQuery('''
    SELECT findings.*, files.path
    FROM findings
    JOIN files ON findings.file_id = files.id
    WHERE files.project_path = ?
    ORDER BY
      CASE findings.severity
        WHEN 'critical' THEN 0
        WHEN 'warning' THEN 1
        ELSE 2
      END,
      files.path,
      findings.line
  ''', [projectPath]);

  return rows.map((finding) {
    return {
      'id': '${finding['path']}:${finding['line']}:${finding['title']}',
      'severity': finding['severity'],
      'category': finding['category'],
      'title': finding['title'],
      'description': finding['description'],
      'location': '${finding['path']}:${finding['line']}',
      'suggestion': finding['suggestion'],
    };
  }).toList();
});