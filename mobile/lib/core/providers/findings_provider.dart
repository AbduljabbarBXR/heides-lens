import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spikey/core/providers/indexing_provider.dart';

final findingsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, projectPath) async {
  final engine = ref.read(indexingEngineProvider);
  final files = await engine.getIndexedFiles();
  final db = await engine.db.db;
  final findings = <Map<String, dynamic>>[];
  
  for (final file in files) {
    if (file.id == null) continue;
    final fileFindings = await db.query('findings', where: 'file_id = ?', whereArgs: [file.id]);
    for (final finding in fileFindings) {
      findings.add({
        'id': '${file.path}:${finding['line']}:${finding['title']}',
        'severity': finding['severity'],
        'category': finding['category'],
        'title': finding['title'],
        'description': finding['description'],
        'location': '${file.path}:${finding['line']}',
        'suggestion': finding['suggestion'],
      });
    }
  }
  
  return findings;
});
