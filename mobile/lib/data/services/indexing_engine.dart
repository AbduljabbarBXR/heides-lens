import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class IndexDatabase {
  static final IndexDatabase _instance = IndexDatabase._internal();
  factory IndexDatabase() => _instance;
  IndexDatabase._internal();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, 'spikey_index.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE files (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            path TEXT UNIQUE,
            hash TEXT,
            language TEXT,
            loc INTEGER,
            last_indexed INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE symbols (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            file_id INTEGER,
            name TEXT,
            type TEXT,
            line INTEGER,
            signature TEXT,
            FOREIGN KEY(file_id) REFERENCES files(id)
          )
        ''');
        await db.execute('''
          CREATE TABLE imports (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            from_file INTEGER,
            to_module TEXT,
            line INTEGER,
            FOREIGN KEY(from_file) REFERENCES files(id)
          )
        ''');
        await db.execute('''
          CREATE TABLE calls (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            from_function TEXT,
            to_function TEXT,
            file_id INTEGER,
            line INTEGER,
            FOREIGN KEY(file_id) REFERENCES files(id)
          )
        ''');
        await db.execute('''
          CREATE TABLE findings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            file_id INTEGER,
            severity TEXT,
            category TEXT,
            title TEXT,
            description TEXT,
            line INTEGER,
            suggestion TEXT,
            source TEXT,
            plugin_id TEXT,
            FOREIGN KEY(file_id) REFERENCES files(id)
          )
        ''');
      },
    );
  }

  Future<void> clear() async {
    final db = await this.db;
    await db.delete('findings');
    await db.delete('calls');
    await db.delete('imports');
    await db.delete('symbols');
    await db.delete('files');
  }

  Future<int> insertFile(Map<String, dynamic> file) async {
    final db = await this.db;
    return await db.insert('files', file);
  }

  Future<int> insertSymbol(Map<String, dynamic> symbol) async {
    final db = await this.db;
    return await db.insert('symbols', symbol);
  }

  Future<int> insertImport(Map<String, dynamic> import) async {
    final db = await this.db;
    return await db.insert('imports', import);
  }

  Future<int> insertFinding(Map<String, dynamic> finding) async {
    final db = await this.db;
    return await db.insert('findings', finding);
  }

  Future<List<Map<String, dynamic>>> getFiles() async {
    final db = await this.db;
    return await db.query('files', orderBy: 'path');
  }

  Future<List<Map<String, dynamic>>> getFindingsByFile(int fileId) async {
    final db = await this.db;
    return await db.query('findings', where: 'file_id = ?', whereArgs: [fileId]);
  }

  Future<List<Map<String, dynamic>>> getImportsByFile(int fileId) async {
    final db = await this.db;
    return await db.query('imports', where: 'from_file = ?', whereArgs: [fileId]);
  }
}

class IndexedFile {
  final int? id;
  final String path;
  final String hash;
  final String language;
  final int loc;
  final DateTime lastIndexed;

  IndexedFile({this.id, required this.path, required this.hash, required this.language, required this.loc, required this.lastIndexed});

  Map<String, dynamic> toMap() {
    return {'path': path, 'hash': hash, 'language': language, 'loc': loc, 'last_indexed': lastIndexed.millisecondsSinceEpoch};
  }
}

class FileScanner {
  static Future<List<String>> scanDirectory(String directory, {int maxDepth = 10}) async {
    final files = <String>[];
    await _scanRecursive(directory, 0, maxDepth, files);
    return files;
  }

  static Future<void> _scanRecursive(String dir, int depth, int maxDepth, List<String> files) async {
    if (depth > maxDepth) return;
    try {
      final entries = await Directory(dir).list().toList();
      for (final entry in entries) {
        if (entry is File) {
          final path = entry.path;
          final ext = p.extension(path).toLowerCase();
          if (isSupported(ext)) {
            files.add(path);
          }
        } else if (entry is Directory) {
          final name = p.basename(entry.path);
          if (name.startsWith('.') || name == 'node_modules' || name == 'build' || name == 'dist') continue;
          await _scanRecursive(entry.path, depth + 1, maxDepth, files);
        }
      }
    } catch (e) {
      // Skip inaccessible directories
    }
  }

  static bool isSupported(String ext) {
    return ['.js', '.ts', '.jsx', '.tsx', '.py', '.go', '.rs', '.java', '.c', '.cpp', '.h', '.rb', '.php', '.dart'].contains(ext);
  }

  static Future<String> computeHash(String path) async {
    final bytes = await File(path).readAsBytes();
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  static Future<Map<String, dynamic>> analyzeFile(String path) async {
    final content = await File(path).readAsString();
    final lines = content.split('\n');
      final language = detectLanguage(p.extension(path).toLowerCase());
    final symbols = <Map<String, dynamic>>[];
    final imports = <Map<String, dynamic>>[];

    // Simple regex-based extraction (Tree-sitter integration would go here)
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      // Function declarations
      final funcMatch = RegExp(r'function\s+(\w+)\s*\(([^)]*)\)').firstMatch(trimmed);
      if (funcMatch != null) {
        symbols.add({'name': funcMatch.group(1), 'type': 'function', 'line': i + 1, 'signature': funcMatch.group(0)});
      }

      // Class declarations
      final classMatch = RegExp(r'class\s+(\w+)').firstMatch(trimmed);
      if (classMatch != null) {
        symbols.add({'name': classMatch.group(1), 'type': 'class', 'line': i + 1, 'signature': classMatch.group(0)});
      }

      // Import statements
      if (trimmed.startsWith('import ') || trimmed.startsWith('from ')) {
        final fromIndex = trimmed.indexOf('from ');
        if (fromIndex != -1) {
          final afterFrom = trimmed.substring(fromIndex + 5).trim();
          final firstQuote = afterFrom.indexOf("'");
          final secondQuote = afterFrom.indexOf('"');
          int startQuote = -1;
          int endQuote = -1;
          if (firstQuote != -1 && (secondQuote == -1 || firstQuote < secondQuote)) {
            startQuote = firstQuote;
            endQuote = afterFrom.indexOf("'", startQuote + 1);
          } else if (secondQuote != -1) {
            startQuote = secondQuote;
            endQuote = afterFrom.indexOf('"', startQuote + 1);
          }
          if (startQuote != -1 && endQuote != -1) {
            final module = afterFrom.substring(startQuote + 1, endQuote);
            imports.add({'to_module': module, 'line': i + 1});
          }
        }
      }
    }

    return {
      'language': language,
      'loc': lines.length,
      'symbols': symbols,
      'imports': imports,
    };
  }

  static String detectLanguage(String ext) {
    const map = {
      '.js': 'javascript',
      '.ts': 'typescript',
      '.jsx': 'javascript',
      '.tsx': 'typescript',
      '.py': 'python',
      '.go': 'go',
      '.rs': 'rust',
      '.java': 'java',
      '.c': 'c',
      '.cpp': 'cpp',
      '.h': 'c',
      '.rb': 'ruby',
      '.php': 'php',
      '.dart': 'dart',
    };
    return map[ext] ?? 'unknown';
  }
}

class IndexingEngine {
  final IndexDatabase db = IndexDatabase();

  Future<void> indexProject(String projectPath) async {
    await db.clear();
    final files = await FileScanner.scanDirectory(projectPath);
    for (final filePath in files) {
      await _indexFile(filePath, projectPath);
    }
  }

  Future<void> _indexFile(String filePath, String projectPath) async {
    try {
      final hash = await FileScanner.computeHash(filePath);
      final analysis = await FileScanner.analyzeFile(filePath);
      final relPath = p.relative(filePath, from: projectPath);

      final fileId = await db.insertFile({
        'path': relPath,
        'hash': hash,
        'language': analysis['language'],
        'loc': analysis['loc'],
        'last_indexed': DateTime.now().millisecondsSinceEpoch,
      });

      for (final symbol in analysis['symbols']) {
        await db.insertSymbol({'file_id': fileId, ...symbol});
      }

      for (final import in analysis['imports']) {
        await db.insertImport({'from_file': fileId, ...import});
      }
    } catch (e) {
      // Skip files that can't be indexed
    }
  }

  Future<List<IndexedFile>> getIndexedFiles() async {
    final rows = await db.getFiles();
    return rows.map((row) => IndexedFile(
          id: row['id'] as int,
          path: row['path'] as String,
          hash: row['hash'] as String,
          language: row['language'] as String,
          loc: row['loc'] as int,
          lastIndexed: DateTime.fromMillisecondsSinceEpoch(row['last_indexed'] as int),
        )).toList();
  }
}
