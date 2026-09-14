import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:spikey/data/services/indexing_engine.dart';

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
}