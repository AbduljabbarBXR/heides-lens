import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:spikey/data/services/indexing_engine.dart';

final indexingEngineProvider = Provider<IndexingEngine>((ref) {
  return IndexingEngine();
});

final indexedFilesProvider = FutureProvider<List<IndexedFile>>((ref) async {
  final engine = ref.watch(indexingEngineProvider);
  return await engine.getIndexedFiles();
});

/// Precomputed graph edges — shared by the graph screen and background preload
/// so opening the graph after a project loads is instant.
final graphDataProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, projectPath) async {
  final engine = ref.watch(indexingEngineProvider);
  final files = await ref.watch(indexedFilesProvider.future);
  final edges = <Map<String, dynamic>>[];

  for (final file in files) {
    final deps = await engine.getDependencies(file.path);
    for (final imp in deps['imports'] as List<Map<String, dynamic>>) {
      final module = imp['to_module'] as String;
      final target = files.firstWhereOrNull((f) {
        final base = p.basenameWithoutExtension(f.path);
        return base == module || f.path.contains(module) || module.contains(base);
      });
      if (target != null) {
        edges.add({
          'from': file.path,
          'to': target.path,
          'type': 'import',
          'line': imp['line'] as int,
        });
      }
    }
  }

  return {'files': files, 'edges': edges};
});

extension IndexedFileList on List<IndexedFile> {
  IndexedFile? firstWhereOrNull(bool Function(IndexedFile) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}