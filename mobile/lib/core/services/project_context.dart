import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:spikey/data/services/indexing_engine.dart';

class ProjectContext {
  /// Build a context string from the project that the AI can understand
  static Future<String> buildContext({
    required String projectPath,
    required IndexingEngine engine,
    String? currentFilePath,
    int maxContextLength = 8000,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('=== PROJECT CONTEXT ===');
    buffer.writeln('Project: ${p.basename(projectPath)}');
    buffer.writeln('Path: $projectPath');
    buffer.writeln();

    // 1. File tree structure
    buffer.writeln('--- FILE TREE ---');
    final fileTree = await _buildFileTree(projectPath, maxDepth: 3);
    buffer.writeln(fileTree);
    buffer.writeln();

    // 2. Indexed files summary
    final indexedFiles = await engine.getIndexedFiles(projectPath: projectPath);
    if (indexedFiles.isNotEmpty) {
      buffer.writeln('--- INDEXED FILES (${indexedFiles.length}) ---');
      for (final file in indexedFiles.take(50)) {
        buffer.writeln('  ${file.path} (${file.language}, ${file.loc} lines)');
      }
      buffer.writeln();
    }

    // 3. Dependencies/imports
    buffer.writeln('--- DEPENDENCIES ---');
    final depCount = <String, int>{};
    for (final file in indexedFiles.take(30)) {
      try {
        final deps = await engine.getDependencies(file.path, projectPath: projectPath);
        final imports = deps['imports'] as List<Map<String, dynamic>>;
        for (final imp in imports) {
          final module = imp['to_module'] as String;
          depCount[module] = (depCount[module] ?? 0) + 1;
        }
      } catch (_) {}
    }
    // Show most-imported modules
    final sortedDeps = depCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in sortedDeps.take(20)) {
      buffer.writeln('  ${entry.key} (imported ${entry.value}x)');
    }
    buffer.writeln();

    // 4. Key config files
    buffer.writeln('--- KEY FILES ---');
    final keyFiles = ['pubspec.yaml', 'analysis_options.yaml', 'README.md', 'package.json', 'tsconfig.json', 'Cargo.toml', 'pyproject.toml'];
    for (final fileName in keyFiles) {
      final file = File(p.join(projectPath, fileName));
      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          final lines = content.split('\n').take(50).join('\n');
          buffer.writeln('[$fileName]');
          buffer.writeln(lines);
          if (content.split('\n').length > 50) buffer.writeln('...');
          buffer.writeln();
        } catch (_) {}
      }
    }

    // 5. Read main entry point
    final entryFiles = ['lib/main.dart', 'src/main.ts', 'index.js', 'app.py', 'main.py'];
    for (final entry in entryFiles) {
      final file = File(p.join(projectPath, entry));
      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          final lines = content.split('\n').take(80).join('\n');
          buffer.writeln('--- ENTRY POINT: $entry ---');
          buffer.writeln(lines);
          buffer.writeln();
        } catch (_) {}
        break;
      }
    }

    // 6. Findings/Issues
    final findings = await _getFindings(engine, projectPath);
    if (findings.isNotEmpty) {
      buffer.writeln('--- FINDINGS (${findings.length}) ---');
      for (final finding in findings.take(20)) {
        buffer.writeln('  [${finding['severity']}] ${finding['title']} @ ${finding['location']}');
      }
      buffer.writeln();
    }

    // 7. Current file content (if provided)
    if (currentFilePath != null) {
      buffer.writeln('--- CURRENT FILE: ${p.basename(currentFilePath)} ---');
      try {
        final content = await File(currentFilePath).readAsString();
        final lines = content.split('\n');
        // Send first 200 lines to stay within context limits
        final preview = lines.take(200).join('\n');
        buffer.writeln('```');
        buffer.writeln(preview);
        if (lines.length > 200) {
          buffer.writeln('... (${lines.length - 200} more lines)');
        }
        buffer.writeln('```');
      } catch (e) {
        buffer.writeln('(Could not read file: $e)');
      }
      buffer.writeln();
    }

    buffer.writeln('=== END CONTEXT ===');

    final result = buffer.toString();
    // Truncate if too long
    if (result.length > maxContextLength) {
      return result.substring(0, maxContextLength) + '\n... (context truncated)';
    }
    return result;
  }

  static Future<String> _buildFileTree(String dirPath, {int maxDepth = 3, int currentDepth = 0}) async {
    if (currentDepth >= maxDepth) return '';
    final buffer = StringBuffer();
    try {
      final entries = await Directory(dirPath).list().toList();
      entries.sort((a, b) {
        final aName = p.basename(a.path);
        final bName = p.basename(b.path);
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        return aName.compareTo(bName);
      });

      for (final entry in entries) {
        final name = p.basename(entry.path);
        if (name.startsWith('.') || name == 'node_modules' || name == 'build' || name == 'dist' || name == '.git') continue;

        final indent = '  ' * currentDepth;
        if (entry is Directory) {
          buffer.writeln('$indent📁 $name/');
          final subtree = await _buildFileTree(entry.path, maxDepth: maxDepth, currentDepth: currentDepth + 1);
          buffer.write(subtree);
        } else if (entry is File) {
          final ext = p.extension(name).replaceFirst('.', '');
          final icon = _getFileIcon(ext);
          buffer.writeln('$indent$icon $name');
        }
      }
    } catch (_) {}
    return buffer.toString();
  }

  static String _getFileIcon(String ext) {
    switch (ext) {
      case 'dart': return '🔹';
      case 'ts': case 'tsx': return '🔷';
      case 'js': case 'jsx': return '🟡';
      case 'py': return '🐍';
      case 'json': return '📋';
      case 'yaml': case 'yml': return '⚙️';
      case 'md': return '📝';
      case 'css': return '🎨';
      case 'html': return '🌐';
      default: return '📄';
    }
  }

  static Future<List<Map<String, dynamic>>> _getFindings(IndexingEngine engine, String projectPath) async {
    try {
      final files = await engine.getIndexedFiles(projectPath: projectPath);
      final db = await engine.db.db;
      final findings = <Map<String, dynamic>>[];

      for (final file in files) {
        if (file.id == null) continue;
        final fileFindings = await db.query('findings', where: 'file_id = ?', whereArgs: [file.id]);
        for (final finding in fileFindings) {
          findings.add({
            'severity': finding['severity'],
            'title': finding['title'],
            'location': '${file.path}:${finding['line']}',
          });
        }
      }
      return findings;
    } catch (_) {
      return [];
    }
  }
}
