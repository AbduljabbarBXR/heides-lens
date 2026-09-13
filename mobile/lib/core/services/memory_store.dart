import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class MemoryStore {
  static final MemoryStore _instance = MemoryStore._internal();
  factory MemoryStore() => _instance;
  MemoryStore._internal();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, 'spikey_memory.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE memories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            workspace_id TEXT,
            content TEXT,
            embedding BLOB,
            metadata TEXT,
            created_at INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE memory_index (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            memory_id INTEGER,
            vector BLOB,
            FOREIGN KEY(memory_id) REFERENCES memories(id)
          )
        ''');
      },
    );
  }

  Future<void> storeMemory({
    required String workspaceId,
    required String content,
    required List<double> embedding,
    Map<String, dynamic>? metadata,
  }) async {
    final db = await this.db;
    final encoded = _encodeEmbedding(embedding);
    final memoryId = await db.insert('memories', {
      'workspace_id': workspaceId,
      'content': content,
      'embedding': encoded,
      'metadata': metadata != null ? jsonEncode(metadata) : null,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    await db.insert('memory_index', {
      'memory_id': memoryId,
      'vector': encoded,
    });
  }

  Future<List<Map<String, dynamic>>> searchMemories(String workspaceId, List<double> queryEmbedding, {int limit = 10}) async {
    final db = await this.db;
    final memories = await db.query(
      'memories',
      where: 'workspace_id = ?',
      whereArgs: [workspaceId],
    );

    final scored = <Map<String, dynamic>>[];
    for (final memory in memories) {
      final stored = _decodeEmbedding(memory['embedding'] as Uint8List);
      final score = _cosineSimilarity(queryEmbedding, stored);
      scored.add({...memory, 'score': score});
    }

    scored.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    return scored.take(limit).toList();
  }

  Future<void> clearWorkspace(String workspaceId) async {
    final db = await this.db;
    final memories = await db.query('memories', where: 'workspace_id = ?', whereArgs: [workspaceId]);
    for (final memory in memories) {
      await db.delete('memory_index', where: 'memory_id = ?', whereArgs: [memory['id']]);
    }
    await db.delete('memories', where: 'workspace_id = ?', whereArgs: [workspaceId]);
  }

  Uint8List _encodeEmbedding(List<double> embedding) {
    final buffer = Uint8List(embedding.length * 8);
    final view = ByteData.view(buffer.buffer);
    for (var i = 0; i < embedding.length; i++) {
      view.setFloat64(i * 8, embedding[i].clamp(-1.0, 1.0));
    }
    return buffer;
  }

  List<double> _decodeEmbedding(Uint8List data) {
    final view = ByteData.view(data.buffer);
    final embedding = <double>[];
    for (var i = 0; i < data.length; i += 8) {
      embedding.add(view.getFloat64(i));
    }
    return embedding;
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    final denom = sqrt(normA * normB);
    if (denom == 0) return 0.0;
    return dot / denom;
  }
}
