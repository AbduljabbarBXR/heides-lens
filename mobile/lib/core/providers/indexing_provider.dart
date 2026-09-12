import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spikey/data/services/indexing_engine.dart';

final indexingEngineProvider = Provider<IndexingEngine>((ref) {
  return IndexingEngine();
});

final indexedFilesProvider = FutureProvider<List<IndexedFile>>((ref) async {
  final engine = ref.watch(indexingEngineProvider);
  return await engine.getIndexedFiles();
});
