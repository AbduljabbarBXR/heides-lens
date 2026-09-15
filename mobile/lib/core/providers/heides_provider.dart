import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heides_lens/core/services/heides_service.dart';

/// Singleton HEIDES MCP client.
final heidesServiceProvider = Provider<HeidesService>((ref) {
  final service = HeidesService();
  ref.onDispose(() => service.stop());
  return service;
});

/// Whether the heides binary is available on this machine.
final heidesAvailableProvider = FutureProvider<bool>((ref) async {
  if (!HeidesService.platformSupported) return false;
  final binary = await HeidesService.findBinary();
  return binary != null;
});

/// Workspace manifest from `spine.describe` — compact overview of the
/// codebase (symbols, entrypoints, hubs, cycles) used as AI context.
final heidesManifestProvider =
    FutureProvider.family<String?, String>((ref, projectPath) async {
  if (!HeidesService.platformSupported) return null;
  final service = ref.watch(heidesServiceProvider);
  final started = await service.start(workingDirectory: projectPath);
  if (!started) return null;
  try {
    await service.scan(projectPath);
    final manifest = await service.describe(projectPath);
    return manifest;
  } catch (_) {
    return null;
  }
});

/// Structured findings from `harmony.report`.
final heidesReportProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, projectPath) async {
  if (!HeidesService.platformSupported) return null;
  final service = ref.watch(heidesServiceProvider);
  final started = await service.start(workingDirectory: projectPath);
  if (!started) return null;
  try {
    await service.scan(projectPath);
    final raw = await service.harmonyReport(projectPath);
    if (raw.trim().isEmpty) return null;
    try {
      return Map<String, dynamic>.from(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
    } catch (_) {
      return {'raw': raw};
    }
  } catch (_) {
    return null;
  }
});

/// HEIDES findings mapped to the Review screen format.
/// Returns null when HEIDES is unavailable so callers can fall back.
final heidesFindingsProvider =
    FutureProvider.family<List<Map<String, dynamic>>?, String>((ref, projectPath) async {
  final report = await ref.watch(heidesReportProvider(projectPath).future);
  if (report == null) return null;
  final rawFindings = report['findings'];
  if (rawFindings is! List) return null;

  String normalizeSeverity(String severity) {
    switch (severity) {
      case 'blocker':
      case 'critical':
        return 'critical';
      case 'warning':
        return 'warning';
      default:
        return 'info';
    }
  }

  return rawFindings.whereType<Map>().map((f) {
    final file = (f['file'] as String?) ?? '';
    final line = f['line'] ?? 0;
    final message = (f['message'] as String?) ?? '';
    final guard = (f['guard'] as String?) ?? 'harmony';
    final severity = normalizeSeverity((f['severity'] as String?) ?? 'info');

    return {
      'id': '$file:$line:$guard',
      'severity': severity,
      'category': guard,
      'title': message.isNotEmpty
          ? message[0].toUpperCase() + message.substring(1)
          : 'Finding',
      'description': message,
      'location': '$file:$line',
      'suggestion': null,
      'source': 'heides',
    };
  }).toList();
});