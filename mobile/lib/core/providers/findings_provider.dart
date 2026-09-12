import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spikey/data/services/indexing_engine.dart';

final findingsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, projectPath) async {
  final engine = IndexingEngine();
  await engine.indexProject(projectPath);
  final files = await engine.getIndexedFiles();
  final findings = <Map<String, dynamic>>[];
  
  final db = await engine.db.db;
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
