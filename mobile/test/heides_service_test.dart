import 'package:flutter_test/flutter_test.dart';
import 'package:spikey/core/services/heides_service.dart';

void main() {
  test('HeidesService finds the binary and speaks MCP', () async {
    final binary = await HeidesService.findBinary();
    if (binary == null) {
      // HEIDES not installed on this machine — skip
      return;
    }

    final service = HeidesService();
    final started = await service.start();
    expect(started, isTrue, reason: service.lastError);

    // describe the spikey workspace (this repo)
    final manifest = await service.describe('/home/centinos/Spikey');
    expect(manifest, isNotEmpty);
    expect(manifest, contains('files'));

    await service.stop();
  }, timeout: const Timeout(Duration(minutes: 3)));
}