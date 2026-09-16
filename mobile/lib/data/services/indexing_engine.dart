import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class IndexDatabase {
  static final IndexDatabase _instance = IndexDatabase._internal();
  factory IndexDatabase() => _instance;
  IndexDatabase._internal();

  /// Overridable DB location (tests point this at a temp dir).
  String? overridePath;

  Database? _db;

  /// Reset the singleton (used by tests).
  @visibleForTesting
  void resetForTest() {
    _db = null;
    overridePath = null;
  }

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final String path;
    if (overridePath != null) {
      path = overridePath!;
    } else {
      final dir = await getApplicationSupportDirectory();
      path = p.join(dir.path, 'heides_index.db');
    }
    return await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE files (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_path TEXT,
            path TEXT,
            hash TEXT,
            language TEXT,
            loc INTEGER,
            last_indexed INTEGER,
            UNIQUE(project_path, path)
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
          try {
            await db.execute('ALTER TABLE files ADD COLUMN project_path TEXT');
          } catch (_) {
            // column may already exist
          }
        }
        if (oldVersion < 4) {
          // v3 made path globally UNIQUE, which breaks multi-project indexing.
          // Rebuild the files table so uniqueness is per (project_path, path),
          // and drop legacy rows that have no project (they cannot be scoped).
          await db.execute('''
            CREATE TABLE files_new (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              project_path TEXT,
              path TEXT,
              hash TEXT,
              language TEXT,
              loc INTEGER,
              last_indexed INTEGER,
              UNIQUE(project_path, path)
            )
          ''');
          await db.execute('''
            INSERT INTO files_new (id, project_path, path, hash, language, loc, last_indexed)
            SELECT id, project_path, path, hash, language, loc, last_indexed
            FROM files WHERE project_path IS NOT NULL
          ''');
          await db.execute('DROP TABLE files');
          await db.execute('ALTER TABLE files_new RENAME TO files');
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

  static const Set<String> supportedExtensions = {
    '.js', '.mjs', '.cjs', '.ts', '.jsx', '.tsx', '.py', '.go', '.rs',
    '.java', '.c', '.cpp', '.h', '.hpp', '.rb', '.php', '.dart',
    // Language pack 1 (Tier 1-3)
    '.swift', '.kt', '.kts', '.cs', '.sh', '.bash', '.zsh', '.lua',
    '.sql', '.ex', '.exs', '.scala', '.pl', '.pm', '.m', '.mm',
    '.vue', '.svelte', '.ps1', '.hs', '.clj', '.cljs', '.zig', '.groovy',
    // Language pack 2 (Tier 4-5)
    '.r', '.f90', '.f95', '.f', '.jl', '.erl', '.hrl', '.ml', '.mli',
    '.fs', '.fsx', '.nim', '.cr', '.d', '.gd', '.sol', '.astro',
    '.md', '.markdown', '.json', '.yaml', '.yml', '.toml',
    '.css', '.scss', '.less', '.html', '.htm', '.xml', '.tex',
    '.mk', '.cmake',
    // Language pack 3 (Tier 6)
    '.coffee', '.litcoffee', '.elm', '.hx', '.lisp', '.lsp', '.scm',
    '.tcl', '.vb', '.pas', '.ada', '.pro', '.v', '.vhd', '.vhdl',
    '.sv', '.cob', '.cbl', '.ahk', '.purs', '.res', '.qml',
    '.bat', '.cmd', '.gleam', '.asm', '.s',
  };

  static bool isSupported(String ext) {
    return supportedExtensions.contains(ext);
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

      // Function-like declarations across languages: JS/TS `function`,
      // Swift/Go `func`, Kotlin/Scala `fun`/`def`, Rust `fn`, Python/Ruby
      // `def`, Perl/Tcl `sub`/`proc`, Fortran/Pascal/Ada `subroutine`/
      // `procedure`, VB `Sub`/`Function` (case-insensitive keywords).
      final funcMatch = RegExp(r'\b(?:function|func|fun|fn|def|sub|proc|subroutine|procedure)\s+(\w+)',
          caseSensitive: false).firstMatch(trimmed);
      if (funcMatch != null) {
        final name = funcMatch.group(1)!;
        symbols.add({'name': name, 'type': 'function', 'line': i + 1, 'signature': funcMatch.group(0)});
        functionStack.add(name);
      }

      // Lisp/Scheme: (define (name args) ...)
      final defineMatch = RegExp(r'\(define\s*\(\s*(\w+)').firstMatch(trimmed);
      if (defineMatch != null) {
        final name = defineMatch.group(1)!;
        symbols.add({'name': name, 'type': 'function', 'line': i + 1, 'signature': defineMatch.group(0)});
        functionStack.add(name);
      }

      // Erlang-style: foo() -> ... | foo() when ...
      final erlangMatch = RegExp(r'^(\w+)\s*\([^)]*\)\s*(?:->|when)').firstMatch(trimmed);
      if (erlangMatch != null) {
        final name = erlangMatch.group(1)!;
        symbols.add({'name': name, 'type': 'function', 'line': i + 1, 'signature': erlangMatch.group(0)});
        functionStack.add(name);
      }

      // Type declarations: class, struct, interface, trait, protocol, enum,
      // record (Swift/Kotlin/C#/Rust/Scala/…).
      final typeMatch = RegExp(r'\b(class|struct|interface|trait|protocol|enum|record)\s+(\w+)')
          .firstMatch(trimmed);
      if (typeMatch != null) {
        symbols.add({
          'name': typeMatch.group(2)!,
          'type': typeMatch.group(1)!,
          'line': i + 1,
          'signature': typeMatch.group(0),
        });
      }

      // Imports across languages:
      //   JS/TS  import ... from 'x'
      //   Python from x import y / import x
      //   Go     import "x"
      //   C/C++  #include <x> / #include "x"
      //   ObjC   #import "x"
      //   Rust   use foo::bar;
      //   PHP    use Foo\Bar;
      //   Ruby   require 'x'
      //   Lua    require("x")
      String? importedModule;
      if (trimmed.startsWith('import ') || trimmed.startsWith('from ')) {
        final fromIndex = trimmed.indexOf('from ');
        final afterFrom = fromIndex != -1 ? trimmed.substring(fromIndex + 5).trim() : null;
        if (afterFrom != null) {
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
            importedModule = afterFrom.substring(startQuote + 1, endQuote);
          } else if (trimmed.startsWith('from ')) {
            // Python: `from x import y` — module is the token after `from`
            importedModule = trimmed.substring(5).split(RegExp(r'\s+')).first;
          }
        } else if (trimmed.startsWith('import ')) {
          // Go: `import "x"` / bare `import x`
          final rest = trimmed.substring(7).trim();
          final quote = rest.startsWith('"') ? '"' : (rest.startsWith("'") ? "'" : null);
          if (quote != null) {
            final end = rest.indexOf(quote, 1);
            if (end > 0) importedModule = rest.substring(1, end);
          } else if (rest.isNotEmpty) {
            importedModule = rest.split(RegExp(r'\s+')).first;
          }
        }
      } else if (trimmed.startsWith('#include') || trimmed.startsWith('#import')) {
        final open = trimmed.indexOf(RegExp(r'[<"]'));
        if (open != -1) {
          final closer = trimmed[open] == '<' ? '>' : '"';
          final close = trimmed.indexOf(closer, open + 1);
          if (close > open) importedModule = trimmed.substring(open + 1, close);
        }
      } else if (trimmed.startsWith('use ')) {
        // Rust `use foo::bar;` / PHP `use Foo\Bar;`
        importedModule = trimmed
            .substring(4)
            .replaceAll(';', '')
            .trim()
            .split(RegExp(r'[\\:]'))
            .first
            .trim();
      } else if (trimmed.startsWith('require')) {
        // Ruby `require 'x'` / Lua `require("x")`
        final quote = trimmed.indexOf(RegExp(r'''["']'''));
        final end = quote != -1 ? trimmed.indexOf(trimmed[quote], quote + 1) : -1;
        if (quote != -1 && end > quote) importedModule = trimmed.substring(quote + 1, end);
      }
      if (importedModule != null && importedModule.isNotEmpty) {
        imports.add({'to_module': importedModule, 'line': i + 1});
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
      '.mjs': 'javascript',
      '.cjs': 'javascript',
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
      '.hpp': 'cpp',
      '.rb': 'ruby',
      '.php': 'php',
      '.dart': 'dart',
      '.swift': 'swift',
      '.kt': 'kotlin',
      '.kts': 'kotlin',
      '.cs': 'csharp',
      '.sh': 'shell',
      '.bash': 'shell',
      '.zsh': 'shell',
      '.lua': 'lua',
      '.sql': 'sql',
      '.ex': 'elixir',
      '.exs': 'elixir',
      '.scala': 'scala',
      '.pl': 'perl',
      '.pm': 'perl',
      '.m': 'objective-c',
      '.mm': 'objective-c',
      '.vue': 'vue',
      '.svelte': 'svelte',
      '.ps1': 'powershell',
      '.hs': 'haskell',
      '.clj': 'clojure',
      '.cljs': 'clojure',
      '.zig': 'zig',
      '.groovy': 'groovy',
      '.r': 'r',
      '.f90': 'fortran',
      '.f95': 'fortran',
      '.f': 'fortran',
      '.jl': 'julia',
      '.erl': 'erlang',
      '.hrl': 'erlang',
      '.ml': 'ocaml',
      '.mli': 'ocaml',
      '.fs': 'fsharp',
      '.fsx': 'fsharp',
      '.nim': 'nim',
      '.cr': 'crystal',
      '.d': 'd',
      '.gd': 'gdscript',
      '.sol': 'solidity',
      '.astro': 'astro',
      '.md': 'markdown',
      '.markdown': 'markdown',
      '.json': 'json',
      '.yaml': 'yaml',
      '.yml': 'yaml',
      '.toml': 'toml',
      '.css': 'css',
      '.scss': 'css',
      '.less': 'css',
      '.html': 'html',
      '.htm': 'html',
      '.xml': 'xml',
      '.tex': 'latex',
      '.mk': 'make',
      '.cmake': 'cmake',
      '.coffee': 'coffeescript',
      '.litcoffee': 'coffeescript',
      '.elm': 'elm',
      '.hx': 'haxe',
      '.lisp': 'lisp',
      '.lsp': 'lisp',
      '.scm': 'scheme',
      '.tcl': 'tcl',
      '.vb': 'vb',
      '.pas': 'pascal',
      '.ada': 'ada',
      '.pro': 'prolog',
      '.v': 'verilog',
      '.vhd': 'vhdl',
      '.vhdl': 'vhdl',
      '.sv': 'systemverilog',
      '.cob': 'cobol',
      '.cbl': 'cobol',
      '.ahk': 'autohotkey',
      '.purs': 'purescript',
      '.res': 'rescript',
      '.qml': 'qml',
      '.bat': 'batch',
      '.cmd': 'batch',
      '.gleam': 'gleam',
      '.asm': 'assembly',
      '.s': 'assembly',
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
      final int fileId;
      if (existing != null) {
        fileId = existing['id'] as int;
        await db.updateFileHash(fileId, hash);
      } else {
        fileId = await db.insertFile({
          'project_path': projectPath,
          'path': relPath,
          'hash': hash,
          'language': analysis['language'] as String,
          'loc': analysis['loc'] as int,
          'last_indexed': DateTime.now().millisecondsSinceEpoch,
        });
      }

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
        findings.add({'severity': 'critical', 'category': 'security', 'title': 'Use of eval()', 'description': 'eval() executes arbitrary code', 'line': i + 1, 'suggestion': 'Avoid eval()', 'source': 'static', 'plugin_id': 'com.heides.security-scanner'});
      }
      if (line.contains("innerHTML")) {
        findings.add({'severity': 'warning', 'category': 'security', 'title': 'innerHTML assignment', 'description': 'Direct innerHTML can lead to XSS', 'line': i + 1, 'suggestion': 'Use textContent or sanitize HTML', 'source': 'static', 'plugin_id': 'com.heides.security-scanner'});
      }
      final passwordPattern = RegExp("""password\s*=\s*['"]""");
      final passwordMatch = passwordPattern.firstMatch(line);
      if (passwordMatch != null) {
        findings.add({'severity': 'critical', 'category': 'security', 'title': 'Hardcoded password', 'description': 'Hardcoded credentials should not be committed', 'line': i + 1, 'suggestion': 'Move credentials to environment variables', 'source': 'static', 'plugin_id': 'com.heides.security-scanner'});
      }
      if (line.contains("new Function(")) {
        findings.add({'severity': 'warning', 'category': 'security', 'title': 'Dynamic function creation', 'description': 'new Function() can execute arbitrary code', 'line': i + 1, 'suggestion': 'Avoid dynamic function creation', 'source': 'static', 'plugin_id': 'com.heides.security-scanner'});
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
