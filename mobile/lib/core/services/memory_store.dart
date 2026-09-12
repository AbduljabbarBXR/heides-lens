import 'dart:convert';
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
    final memoryId = await db.insert('memories', {
      'workspace_id': workspaceId,
      'content': content,
      'embedding': _encodeEmbedding(embedding),
      'metadata': metadata != null ? jsonEncode(metadata) : null,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    await db.insert('memory_index', {
      'memory_id': memoryId,
      'vector': _encodeEmbedding(embedding),
    });
  }

  Future<List<Map<String, dynamic>>> searchMemories(String workspaceId, List<double> queryEmbedding, {int limit = 10}) async {
    final db = await this.db;
    final memories = await db.query(
      'memories',
      where: 'workspace_id = ?',
      whereArgs: [workspaceId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return memories;
  }

  Future<void> clearWorkspace(String workspaceId) async {
    final db = await this.db;
    final memories = await db.query('memories', where: 'workspace_id = ?', whereArgs: [workspaceId]);
    for (final memory in memories) {
      await db.delete('memory_index', where: 'memory_id = ?', whereArgs: [memory['id']]);
    }
    await db.delete('memories', where: 'workspace_id = ?', whereArgs: [workspaceId]);
  }

  List<double> _encodeEmbedding(List<double> embedding) {
    return embedding.map((e) => e.clamp(-1.0, 1.0)).toList();
  }
}
