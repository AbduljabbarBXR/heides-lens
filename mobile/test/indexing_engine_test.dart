import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:heides_lens/data/services/indexing_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;

  setUp(() {
    IndexDatabase().resetForTest();
    tempDir = Directory.systemTemp.createTempSync('spikey_test_');
    // Point the singleton at a temp DB so path_provider isn't needed
    IndexDatabase().overridePath = p.join(tempDir.path, 'test.db');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  void writeFile(String rel, String content) {
    final file = File(p.join(tempDir.path, rel));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  test('indexing + re-indexing with project scoping works', () async {
    final engine = IndexingEngine();

    // Project A: two files
    writeFile('a.dart', 'class A {}\n');
    writeFile('b.dart', 'class B {}\n');

    await engine.indexProject(tempDir.path);
    var files = await engine.getIndexedFiles(projectPath: tempDir.path);
    expect(files.length, 2);
    expect(files.every((f) => f.path.endsWith('.dart')), isTrue);

    // Re-index: same files should not duplicate (unique per project+path)
    await engine.indexProject(tempDir.path);
    files = await engine.getIndexedFiles(projectPath: tempDir.path);
    expect(files.length, 2, reason: 're-index must not duplicate files');

    // Project A files must NOT leak into another project
    writeFile('x.dart', 'class X {}\n');
    final otherProject = Directory.systemTemp.createTempSync('spikey_other_');
    File(p.join(otherProject.path, 'y.dart')).writeAsStringSync('class Y {}\n');
    await engine.indexProject(otherProject.path);
    final otherFiles = await engine.getIndexedFiles(projectPath: otherProject.path);
    expect(otherFiles.length, 1);
    expect(otherFiles.first.path, 'y.dart');

    // Scoped query returns only project A's files
    files = await engine.getIndexedFiles(projectPath: tempDir.path);
    expect(files.length, 2);
    expect(files.any((f) => f.path == 'y.dart'), isFalse);

    otherProject.deleteSync(recursive: true);
  });

  test('changed file is re-indexed under its own file_id', () async {
    final engine = IndexingEngine();
    writeFile('a.dart', 'class A {}\nclass F {}\n');

    await engine.indexProject(tempDir.path);
    final db = await engine.db.db;
    final beforeNames = (await db.query('symbols')).map((s) => s['name']).toSet();
    expect(beforeNames, containsAll(['A', 'F']));

    // Change the file: re-index
    writeFile('a.dart', 'class A2 {}\nclass G {}\nclass H {}\n');
    await engine.indexProject(tempDir.path);

    final afterRows = await db.query('symbols');
    final afterNames = afterRows.map((s) => s['name']).toSet();
    // Old symbols replaced, new ones present
    expect(afterNames, containsAll(['A2', 'G', 'H']));
    expect(afterNames.contains('A'), isFalse, reason: 'stale symbol A must be removed');

    // All symbols attach to the single project file, not file_id=1 collisions
    final fileIds = afterRows.map((s) => s['file_id']).toSet();
    expect(fileIds.length, 1);
  });

  test('language pack detects new languages and extracts symbols', () async {
    // Extension → language mapping for the added pack
    const expected = {
      '.swift': 'swift',
      '.kt': 'kotlin',
      '.cs': 'csharp',
      '.sh': 'shell',
      '.lua': 'lua',
      '.sql': 'sql',
      '.ex': 'elixir',
      '.scala': 'scala',
      '.zig': 'zig',
      '.ps1': 'powershell',
      '.hs': 'haskell',
      '.vue': 'vue',
    };
    expected.forEach((ext, lang) {
      expect(FileScanner.detectLanguage(ext), lang, reason: 'detectLanguage($ext)');
      expect(FileScanner.isSupported(ext), isTrue, reason: 'isSupported($ext)');
    });

    final engine = IndexingEngine();
    writeFile('main.swift', 'class App {}\nfunc greet() {\n  print("hi")\n}\n');
    writeFile('Main.kt', 'fun main() {\n  println("hi")\n}\n');
    writeFile('Program.cs', 'class Program {}\n');
    writeFile('deploy.sh', '#!/bin/bash\nfunction deploy() {\n  echo hi\n}\n');
    writeFile('lib.lua', 'function start()\n  print("x")\nend\n');
    writeFile('user.ex', 'defmodule User do\n  def name do\n  end\nend\n');

    await engine.indexProject(tempDir.path);
    final files = await engine.getIndexedFiles(projectPath: tempDir.path);
    expect(files.length, 6, reason: 'all six language-pack files must index');

    final db = await engine.db.db;
    final names = (await db.query('symbols')).map((s) => s['name']).toSet();
    expect(names, containsAll(['App', 'greet', 'main', 'Program', 'deploy', 'start', 'name']));
  });
}