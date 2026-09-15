import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// HEIDES MCP client — spawns `heides mcp` and speaks JSON-RPC over stdio.
///
/// HEIDES (github.com/AbduljabbarBXR/heides) is the deterministic code
/// nervous system: Spine (graph), Harmony (guards), Grounding (plans).
/// It runs locally, needs no model, and exposes 11 MCP tools.
class HeidesService {
  Process? _process;
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};
  final StringBuffer _stdoutBuffer = StringBuffer();
  int _nextId = 1;
  bool _ready = false;
  String? _lastError;

  bool get isReady => _ready;
  String? get lastError => _lastError;

  /// HEIDES deep-parses Rust, JS, TS, Python, PHP, Go, Java, C#,
  /// plus HTML/CSS as web surface.
  static const supportedExtensions = {
    'rs', 'js', 'jsx', 'ts', 'tsx', 'py', 'php', 'go', 'java', 'cs',
    'html', 'htm', 'css',
  };

  /// Whether HEIDES can run on this platform at all.
  static bool get platformSupported =>
      Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  /// Find the heides binary on PATH (or common install locations).
  static Future<String?> findBinary() async {
    if (!platformSupported) return null;
    final candidates = <String>[
      'heides',
      if (Platform.isLinux || Platform.isMacOS) ...[
        '${Platform.environment['HOME']}/.local/bin/heides',
        '/usr/local/bin/heides',
        '/usr/bin/heides',
      ],
      if (Platform.isWindows) ...[
        '${Platform.environment['USERPROFILE']}\\heides.exe',
      ],
    ];

    for (final candidate in candidates) {
      try {
        final result = await Process.run(candidate, ['version'], runInShell: true)
            .timeout(const Duration(seconds: 5));
        if (result.exitCode == 0) return candidate;
      } catch (_) {
        // try next
      }
    }
    return null;
  }

  /// Start the MCP server and complete the initialize handshake.
  Future<bool> start({String? workingDirectory}) async {
    if (_ready) return true;
    if (!platformSupported) {
      _lastError = 'HEIDES is only available on desktop platforms';
      return false;
    }

    final binary = await findBinary();
    if (binary == null) {
      _lastError = 'heides binary not found on PATH';
      return false;
    }

    try {
      _process = await Process.start(
        binary,
        ['mcp'],
        workingDirectory: workingDirectory,
        runInShell: true,
      );
    } catch (e) {
      _lastError = 'Failed to start heides mcp: $e';
      return false;
    }

    _process!.stdout.transform(utf8.decoder).listen(_onStdout);
    _process!.stderr.transform(utf8.decoder).listen((data) {
      // stderr is diagnostics only
    });
    _process!.exitCode.then((code) {
      _ready = false;
      _lastError = 'heides mcp exited ($code)';
      for (final pending in _pending.values) {
        if (!pending.isCompleted) {
          pending.completeError(StateError('heides mcp exited'));
        }
      }
      _pending.clear();
    });

    try {
      await _request('initialize', {
        'protocolVersion': '2024-11-05',
        'capabilities': <String, dynamic>{},
        'clientInfo': {'name': 'heides-lens', 'version': '1.0.0'},
      });
      _notify('notifications/initialized', {});
      _ready = true;
      _lastError = null;
      return true;
    } catch (e) {
      _lastError = 'MCP initialize failed: $e';
      await stop();
      return false;
    }
  }

  void _onStdout(String chunk) {
    _stdoutBuffer.write(chunk);
    final content = _stdoutBuffer.toString();
    final lines = content.split('\n');
    // Keep the last (possibly partial) line in the buffer
    _stdoutBuffer
      ..clear()
      ..write(lines.removeLast());

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final message = jsonDecode(trimmed) as Map<String, dynamic>;
        final id = message['id'];
        if (id is int && _pending.containsKey(id)) {
          final completer = _pending.remove(id)!;
          if (message.containsKey('error')) {
            completer.completeError(StateError(message['error'].toString()));
          } else {
            completer.complete(message['result'] as Map<String, dynamic>? ?? {});
          }
        }
      } catch (_) {
        // ignore non-JSON lines
      }
    }
  }

  void _send(Map<String, dynamic> message) {
    final process = _process;
    if (process == null) throw StateError('heides mcp is not running');
    process.stdin.writeln(jsonEncode(message));
  }

  void _notify(String method, Map<String, dynamic> params) {
    _send({'jsonrpc': '2.0', 'method': method, 'params': params});
  }

  Future<Map<String, dynamic>> _request(String method, Map<String, dynamic> params) {
    final id = _nextId++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    _send({'jsonrpc': '2.0', 'id': id, 'method': method, 'params': params});
    return completer.future.timeout(const Duration(seconds: 120), onTimeout: () {
      _pending.remove(id);
      throw TimeoutException('heides request timed out: $method');
    });
  }

  /// Call an MCP tool and return the text content of the first result block.
  Future<String> callTool(String name, Map<String, dynamic> arguments) async {
    if (!_ready) {
      final started = await start();
      if (!started) throw StateError(_lastError ?? 'heides is not available');
    }
    final result = await _request('tools/call', {
      'name': name,
      'arguments': arguments,
    });
    final content = result['content'];
    if (content is List && content.isNotEmpty) {
      final first = content.first;
      if (first is Map<String, dynamic>) {
        return (first['text'] as String?) ?? '';
      }
    }
    return '';
  }

  // ---------------------------------------------------------------------------
  // Typed tool wrappers
  // ---------------------------------------------------------------------------

  Future<String> scan(String root) => callTool('spine.scan', {'root': root});

  Future<String> describe(String root) => callTool('spine.describe', {'root': root});

  /// kind: callers | imports | definition | calls | search
  Future<String> query(String kind, String name) =>
      callTool('spine.query', {'kind': kind, 'name': name});

  Future<String> neighbors(String name) =>
      callTool('spine.neighbors', {'name': name});

  Future<String> harmonyCheck(String root) =>
      callTool('harmony.check', {'root': root});

  /// Structured JSON findings with severity counts.
  Future<String> harmonyReport(String root) =>
      callTool('harmony.report', {'root': root});

  /// Check a unified diff before applying.
  Future<String> harmonyStaged(String patch, {String? root}) =>
      callTool('harmony.staged', {'patch': patch, if (root != null) 'root': root});

  Future<String> groundingPlan(String plan) =>
      callTool('grounding.plan', {'plan': plan});

  Future<String> depsCheck(String root) =>
      callTool('deps.check', {'root': root});

  Future<void> stop() async {
    _ready = false;
    _process?.kill();
    _process = null;
  }
}