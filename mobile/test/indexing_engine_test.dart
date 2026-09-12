import 'package:flutter_test/flutter_test.dart';
import 'package:spikey/data/services/indexing_engine.dart';

void main() {
  group('FileScanner', () {
    test('detects language from extension', () {
      expect(FileScanner.detectLanguage('.dart'), 'dart');
      expect(FileScanner.detectLanguage('.ts'), 'typescript');
      expect(FileScanner.detectLanguage('.py'), 'python');
      expect(FileScanner.detectLanguage('.unknown'), 'unknown');
    });

    test('isSupported returns true for known extensions', () {
      expect(FileScanner.isSupported('.dart'), true);
      expect(FileScanner.isSupported('.ts'), true);
      expect(FileScanner.isSupported('.txt'), false);
    });
  });
}
