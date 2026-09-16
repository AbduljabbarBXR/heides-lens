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
    tempDir = Directory.systemTemp.createTempSync('heides_lens_test_');
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
    final otherProject = Directory.systemTemp.createTempSync('heides_lens_other_');
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
    // Extension → language mapping for the added packs (code languages only)
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
      '.r': 'r',
      '.f90': 'fortran',
      '.jl': 'julia',
      '.erl': 'erlang',
      '.ml': 'ocaml',
      '.fs': 'fsharp',
      '.nim': 'nim',
      '.cr': 'crystal',
      '.gd': 'gdscript',
      '.sol': 'solidity',
      '.astro': 'astro',
      '.coffee': 'coffeescript',
      '.elm': 'elm',
      '.hx': 'haxe',
      '.lisp': 'lisp',
      '.scm': 'scheme',
      '.tcl': 'tcl',
      '.vb': 'vb',
      '.pas': 'pascal',
      '.ada': 'ada',
      '.v': 'verilog',
      '.vhd': 'vhdl',
      '.sv': 'systemverilog',
      '.cob': 'cobol',
      '.ahk': 'autohotkey',
      '.purs': 'purescript',
      '.res': 'rescript',
      '.qml': 'qml',
      '.gleam': 'gleam',
      '.asm': 'assembly',
    };
    expected.forEach((ext, lang) {
      expect(FileScanner.detectLanguage(ext), lang, reason: 'detectLanguage($ext)');
      expect(FileScanner.isSupported(ext), isTrue, reason: 'isSupported($ext)');
    });

    // Document/config extensions are still detected (already-indexed files
    // render correctly) but deliberately NOT auto-indexed (file-count noise).
    const docExts = {
      '.md': 'markdown',
      '.json': 'json',
      '.yaml': 'yaml',
      '.toml': 'toml',
      '.css': 'css',
      '.html': 'html',
      '.xml': 'xml',
      '.tex': 'latex',
      '.mk': 'make',
      '.cmake': 'cmake',
      '.bat': 'batch',
    };
    docExts.forEach((ext, lang) {
      expect(FileScanner.detectLanguage(ext), lang, reason: 'detectLanguage($ext)');
      expect(FileScanner.isSupported(ext), isFalse, reason: 'doc ext $ext must not be indexed');
    });

    final engine = IndexingEngine();
    writeFile('main.swift', 'class App {}\nfunc greet() {\n  print("hi")\n}\n');
    writeFile('Main.kt', 'fun main() {\n  println("hi")\n}\n');
    writeFile('Program.cs', 'class Program {}\n');
    writeFile('deploy.sh', '#!/bin/bash\nfunction deploy() {\n  echo hi\n}\n');
    writeFile('lib.lua', 'function start()\n  print("x")\nend\n');
    writeFile('user.ex', 'defmodule User do\n  def name do\n  end\nend\n');
    writeFile('worker.erl', 'handle_call(Msg) ->\n  ok.\n');
    writeFile('app.jl', 'function train()\n  println("x")\nend\n');
    writeFile('trait.sol', 'contract Token {}\nfunction balanceOf() public {}\n');
    writeFile('pages.astro', '---\nconst title = "Home";\n---\n<html>hi</html>\n');
    writeFile('main.scm', '(define (fib n)\n  (if (< n 2) n (+ (fib (- n 1)) (fib (- n 2)))))\n');
    writeFile('util.vb', 'Public Sub Save()\nEnd Sub\nFunction Load() As Integer\nEnd Function\n');
    writeFile('app.gleam', 'pub fn main() {\n  io.println("hi")\n}\n');
    writeFile('model.elm', 'module Model exposing (..)\ntype alias User = { name : String }\n');
    writeFile('calc.tcl', r'proc add {a b} {' + '\n' + r'  return [expr {$a + $b}]' + '\n}\n');
    writeFile('top.vhd', 'entity top is\nend entity;\narchitecture rtl of top is\nend rtl;\n');

    await engine.indexProject(tempDir.path);
    final files = await engine.getIndexedFiles(projectPath: tempDir.path);
    expect(files.length, 16, reason: 'all language-pack files must index');

    final db = await engine.db.db;
    final names = (await db.query('symbols')).map((s) => s['name']).toSet();
    expect(names, containsAll([
      'App', 'greet', 'main', 'Program', 'deploy', 'start', 'name',
      'handle_call', 'train', 'balanceOf', 'fib', 'Save', 'Load', 'add',
    ]));
  });

  test('stress: large multi-language tree indexes without duplicates', () async {
    final engine = IndexingEngine();
    // Cycle over every supported extension — the engine must handle them all.
    final exts = FileScanner.supportedExtensions.toList();
    var expectedFiles = 0;
    for (var i = 0; i < 240; i++) {
      final ext = exts[i % exts.length];
      writeFile('src/lib_$i$ext', '// file $i\nclass Klass$i {}\nfunction helper$i() {}\n');
      expectedFiles++;
    }
    // A few nested dirs + ignored dirs must be skipped
    writeFile('node_modules/pkg/x.js', 'class Ignored {}\n');
    writeFile('.hidden/y.dart', 'class Hidden {}\n');
    // Document/config files must NOT be picked up by the scanner
    writeFile('docs/README.md', '# docs\n');
    writeFile('config.json', '{"a": 1}\n');
    writeFile('build/out.html', '<html></html>\n');

    await engine.indexProject(tempDir.path);
    final files = await engine.getIndexedFiles(projectPath: tempDir.path);
    expect(files.length, expectedFiles, reason: 'every supported file indexed once');
    expect(files.any((f) => f.path.contains('node_modules')), isFalse,
        reason: 'node_modules must be excluded');
    expect(files.any((f) => f.path.contains('.hidden')), isFalse,
        reason: 'hidden dirs must be excluded');

    final db = await engine.db.db;
    final symbolRows = await db.query('symbols');
    expect(symbolRows.length, expectedFiles * 2, reason: 'class + function per file');
    final fileIds = symbolRows.map((s) => s['file_id']).toSet();
    expect(fileIds.length, expectedFiles, reason: 'one file_id per file');

    // Re-index is idempotent (hash cache)
    await engine.indexProject(tempDir.path);
    final again = await engine.getIndexedFiles(projectPath: tempDir.path);
    expect(again.length, expectedFiles, reason: 're-index must not duplicate');
  });
}