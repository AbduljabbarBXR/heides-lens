import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:heides_lens/data/services/indexing_engine.dart';

final indexingEngineProvider = Provider<IndexingEngine>((ref) {
  return IndexingEngine();
});

/// Indexed files scoped to the active project. Family key = project path.
final indexedFilesProvider =
    FutureProvider.family<List<IndexedFile>, String>((ref, projectPath) async {
  final engine = ref.watch(indexingEngineProvider);
  return await engine.getIndexedFiles(projectPath: projectPath);
});

/// Precomputed graph edges — shared by the graph screen and background preload
/// so opening the graph after a project loads is instant. Scoped to project.
/// Built with one imports query + hash lookups (O(files + imports)), not the
/// previous per-file nested scan (O(files × imports)).
final graphDataProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, projectPath) async {
  final engine = ref.watch(indexingEngineProvider);
  final files = await ref.watch(indexedFilesProvider(projectPath).future);
  final edges = <Map<String, dynamic>>[];

  // basename -> candidate files, built once.
  final basenameMap = <String, List<IndexedFile>>{};
  for (final file in files) {
    final base = p.basenameWithoutExtension(file.path).toLowerCase();
    basenameMap.putIfAbsent(base, () => []).add(file);
  }

  final projectImports = await engine.db.getProjectImports(projectPath);
  for (final imp in projectImports) {
    final module = (imp['to_module'] as String).toLowerCase();
    final fromPath = imp['from_path'] as String;

    IndexedFile? target;
    final exact = basenameMap[module];
    if (exact != null && exact.isNotEmpty) {
      target = exact.first;
    } else {
      // Path-suffix matches (e.g. import 'services/user' → lib/services/user.dart)
      // are rare; fall back to a scan only when the exact map misses.
      for (final file in files) {
        final fpath = file.path.toLowerCase();
        if (fpath.contains(module) || module.contains(p.basenameWithoutExtension(fpath))) {
          target = file;
          break;
        }
      }
    }

    if (target != null) {
      edges.add({
        'from': fromPath,
        'to': target.path,
        'type': 'import',
        'line': imp['line'] as int,
      });
    }
  }

  return {'files': files, 'edges': edges};
});