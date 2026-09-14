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
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE files (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_path TEXT,
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
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS calls (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              from_function TEXT,
              to_function TEXT,
              file_id INTEGER,
              line INTEGER,
              FOREIGN KEY(file_id) REFERENCES files(id)
            )
          ''');
        }
        if (oldVersion < 3) {
          // Add project scoping so files from different projects never mix.
          await db.execute('ALTER TABLE files ADD COLUMN project_path TEXT');
        }
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

  Future<int> insertCall(Map<String, dynamic> call) async {
    final db = await this.db;
    return await db.insert('calls', call);
  }

  Future<List<Map<String, dynamic>>> getFiles({String? projectPath}) async {
    final db = await this.db;
    if (projectPath != null) {
      return await db.query('files', where: 'project_path = ?', whereArgs: [projectPath], orderBy: 'path');
    }
    return await db.query('files', orderBy: 'path');
  }

  Future<Map<String, dynamic>?> getFileByPath(String path, {String? projectPath}) async {
    final db = await this.db;
    final List<Map<String, dynamic>> results;
    if (projectPath != null) {
      results = await db.query('files',
          where: 'path = ? AND project_path = ?', whereArgs: [path, projectPath], limit: 1);
    } else {
      results = await db.query('files', where: 'path = ?', whereArgs: [path], limit: 1);
    }
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getFindingsByFile(int fileId) async {
    final db = await this.db;
    return await db.query('findings', where: 'file_id = ?', whereArgs: [fileId]);
  }

  Future<List<Map<String, dynamic>>> getImportsByFile(int fileId) async {
    final db = await this.db;
    return await db.query('imports', where: 'from_file = ?', whereArgs: [fileId]);
  }

  Future<List<Map<String, dynamic>>> getCallsByFile(int fileId) async {
    final db = await this.db;
    return await db.query('calls', where: 'file_id = ?', whereArgs: [fileId]);
  }

  Future<int> updateFileHash(int fileId, String hash) async {
    final db = await this.db;
    return await db.update('files', {'hash': hash, 'last_indexed': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?', whereArgs: [fileId]);
  }

  Future<void> deleteFile(int fileId) async {
    final db = await this.db;
    await db.delete('calls', where: 'file_id = ?', whereArgs: [fileId]);
    await db.delete('imports', where: 'from_file = ?', whereArgs: [fileId]);
    await db.delete('symbols', where: 'file_id = ?', whereArgs: [fileId]);
    await db.delete('findings', where: 'file_id = ?', whereArgs: [fileId]);
    await db.delete('files', where: 'id = ?', whereArgs: [fileId]);
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
    final calls = <Map<String, dynamic>>[];

    final functionStack = <String>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      final funcMatch = RegExp(r'function\s+(\w+)\s*\(([^)]*)\)').firstMatch(trimmed);
      if (funcMatch != null) {
        final name = funcMatch.group(1)!;
        symbols.add({'name': name, 'type': 'function', 'line': i + 1, 'signature': funcMatch.group(0)});
        functionStack.add(name);
      }

      final classMatch = RegExp(r'class\s+(\w+)').firstMatch(trimmed);
      if (classMatch != null) {
        symbols.add({'name': classMatch.group(1)!, 'type': 'class', 'line': i + 1, 'signature': classMatch.group(0)});
      }

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

      final callMatch = RegExp(r'(\w+)\s*\(').firstMatch(trimmed);
      if (callMatch != null && functionStack.isNotEmpty) {
        final called = callMatch.group(1)!;
        if (called != functionStack.last) {
          calls.add({'from_function': functionStack.last, 'to_function': called, 'line': i + 1});
        }
      }

      if (trimmed.contains('{')) {
        functionStack.add('__block__');
      }
      if (trimmed.contains('}')) {
        if (functionStack.isNotEmpty) functionStack.removeLast();
      }
    }

    return {
      'language': language,
      'loc': lines.length,
      'symbols': symbols,
      'imports': imports,
      'calls': calls,
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

  Future<void> indexProject(String projectPath, {bool incremental = true, void Function(int current, int total)? onProgress}) async {
    final files = await FileScanner.scanDirectory(projectPath);
    if (!incremental) {
      await db.clear();
    }

    final total = files.length;
    for (var i = 0; i < total; i++) {
      await _indexFile(files[i], projectPath);
      onProgress?.call(i + 1, total);
    }

    await _removeDeletedFiles(projectPath, files);
  }

  Future<void> _indexFile(String filePath, String projectPath) async {
    try {
      final content = await File(filePath).readAsString();
      final hash = await FileScanner.computeHash(filePath);
      final relPath = p.relative(filePath, from: projectPath);
      final existing = await db.getFileByPath(relPath, projectPath: projectPath);

      if (existing != null && existing['hash'] == hash && existing['last_indexed'] != null) {
        await db.updateFileHash(existing['id'] as int, hash);
        return;
      }

      final analysis = await FileScanner.analyzeFile(filePath);
      final fileId = existing != null
          ? await db.updateFileHash(existing['id'] as int, hash)
          : await db.insertFile({
              'project_path': projectPath,
              'path': relPath,
              'hash': hash,
              'language': analysis['language'] as String,
              'loc': analysis['loc'] as int,
              'last_indexed': DateTime.now().millisecondsSinceEpoch,
            });

      // Delete old symbols/imports/calls/findings before re-inserting
      if (existing != null) {
        await db.db.then((d) async {
          await d.delete('calls', where: 'file_id = ?', whereArgs: [fileId]);
          await d.delete('imports', where: 'from_file = ?', whereArgs: [fileId]);
          await d.delete('symbols', where: 'file_id = ?', whereArgs: [fileId]);
          await d.delete('findings', where: 'file_id = ?', whereArgs: [fileId]);
        });
      }

      for (final symbol in analysis['symbols'] as List<Map<String, dynamic>>) {
        await db.insertSymbol({'file_id': fileId, ...symbol});
      }

      for (final import in analysis['imports'] as List<Map<String, dynamic>>) {
        await db.insertImport({'from_file': fileId, ...import});
      }

      for (final call in analysis['calls'] as List<Map<String, dynamic>>) {
        await db.insertCall({'file_id': fileId, ...call});
      }

      final findings = _scanSecurity(filePath, content);
      for (final finding in findings) {
        await db.insertFinding({'file_id': fileId, ...finding});
      }
    } catch (e) {
      // Skip files that can't be indexed
    }
  }

  List<Map<String, dynamic>> _scanSecurity(String filePath, String content) {
    final findings = <Map<String, dynamic>>[];
    final lines = content.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.contains("eval(")) {
        findings.add({'severity': 'critical', 'category': 'security', 'title': 'Use of eval()', 'description': 'eval() executes arbitrary code', 'line': i + 1, 'suggestion': 'Avoid eval()', 'source': 'static', 'plugin_id': 'com.spikey.security-scanner'});
      }
      if (line.contains("innerHTML")) {
        findings.add({'severity': 'warning', 'category': 'security', 'title': 'innerHTML assignment', 'description': 'Direct innerHTML can lead to XSS', 'line': i + 1, 'suggestion': 'Use textContent or sanitize HTML', 'source': 'static', 'plugin_id': 'com.spikey.security-scanner'});
      }
      final passwordPattern = RegExp("""password\s*=\s*['"]""");
      final passwordMatch = passwordPattern.firstMatch(line);
      if (passwordMatch != null) {
        findings.add({'severity': 'critical', 'category': 'security', 'title': 'Hardcoded password', 'description': 'Hardcoded credentials should not be committed', 'line': i + 1, 'suggestion': 'Move credentials to environment variables', 'source': 'static', 'plugin_id': 'com.spikey.security-scanner'});
      }
      if (line.contains("new Function(")) {
        findings.add({'severity': 'warning', 'category': 'security', 'title': 'Dynamic function creation', 'description': 'new Function() can execute arbitrary code', 'line': i + 1, 'suggestion': 'Avoid dynamic function creation', 'source': 'static', 'plugin_id': 'com.spikey.security-scanner'});
      }
    }
    return findings;
  }

  Future<void> _removeDeletedFiles(String projectPath, List<String> currentFiles) async {
    final allFiles = await db.getFiles(projectPath: projectPath);
    for (final file in allFiles) {
      final relPath = file['path'] as String;
      final normalizedDbPath = p.separator == '/' ? relPath : relPath.replaceAll('/', p.separator);
      final found = currentFiles.any((f) => p.relative(f, from: projectPath) == normalizedDbPath);
      if (!found) {
        await db.deleteFile(file['id'] as int);
      }
    }
  }

  Future<List<IndexedFile>> getIndexedFiles({String? projectPath}) async {
    final rows = await db.getFiles(projectPath: projectPath);
    return rows.map((row) => IndexedFile(
          id: row['id'] as int,
          path: row['path'] as String,
          hash: row['hash'] as String,
          language: row['language'] as String,
          loc: row['loc'] as int,
          lastIndexed: DateTime.fromMillisecondsSinceEpoch(row['last_indexed'] as int),
        )).toList();
  }

  Future<Map<String, dynamic>> getDependencies(String filePath, {String? projectPath}) async {
    final file = await db.getFileByPath(filePath, projectPath: projectPath);
    if (file == null) return {'imports': [], 'calls': []};

    final imports = await db.getImportsByFile(file['id'] as int);
    final calls = await db.getCallsByFile(file['id'] as int);

    return {
      'imports': imports,
      'calls': calls,
    };
  }
}
