import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spikey/shared/themes/app_colors.dart';
import 'package:spikey/shared/logos.dart';
import 'package:spikey/core/services/heides_service.dart';

enum InstallState { checking, missing, installing, installed, failed }

class HeidesSetupScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const HeidesSetupScreen({super.key, required this.onComplete});

  @override
  State<HeidesSetupScreen> createState() => _HeidesSetupScreenState();
}

class _HeidesSetupScreenState extends State<HeidesSetupScreen> {
  InstallState _state = InstallState.checking;
  String _message = '';
  double _progress = 0;
  int _logoId = 1;
  bool _skipped = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() => _logoId = prefs.getInt('logo_choice') ?? 1);
      }
    });
    _check();
  }

  Future<void> _check() async {
    setState(() => _state = InstallState.checking);
    final binary = await HeidesService.findBinary();
    if (!mounted) return;
    if (binary != null) {
      setState(() {
        _state = InstallState.installed;
        _message = 'HEIDES $binary detected on this machine.';
      });
      _continue();
    } else {
      setState(() => _state = InstallState.missing);
    }
  }

  Future<void> _install() async {
    setState(() => _state = InstallState.installing);

    // Try npm global install first; fall back to the curl installer.
    final results = <String>[];
    for (final attempt in ['npm', 'curl']) {
      if (!mounted) return;
      try {
        final (success, output) = await _runInstall(attempt);
        results.add(output);
        if (success) {
          final binary = await HeidesService.findBinary();
          if (binary != null) {
            if (mounted) {
              setState(() {
                _state = InstallState.installed;
                _message = 'HEIDES installed successfully.';
              });
            }
            _continue();
            return;
          }
        }
      } catch (e) {
        results.add('$attempt failed: $e');
      }
    }

    if (mounted) {
      setState(() {
        _state = InstallState.failed;
        _message = results.join('\n');
      });
    }
  }

  Future<(bool, String)> _runInstall(String method) async {
    final cmd = method == 'npm'
        ? <String>['npm', 'install', '-g', 'heides']
        : <String>[
            'bash',
            '-c',
            'curl -fsSL https://raw.githubusercontent.com/AbduljabbarBXR/heides/main/scripts/install.sh | bash',
          ];

    final process = await Process.start(
      cmd.first,
      cmd.sublist(1),
      runInShell: true,
      mode: ProcessStartMode.normal,
    );
    final output = <String>[];
    process.stdout.transform(SystemEncoding().decoder).listen((l) {
      output.add(l);
      if (mounted) {
        setState(() {
          _progress = (_progress + 0.02).clamp(0.0, 0.9);
          _message = l.trim();
        });
      }
    });
    final exit = await process.exitCode.timeout(const Duration(minutes: 5));
    return (exit == 0, output.join('\n'));
  }

  void _continue() {
    if (_skipped) return;
    _skipped = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onComplete();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SpikeyLogoMark(id: _logoId, size: 72),
                const SizedBox(height: 20),
                const Text(
                  'Heides Lens',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The nervous system for your code, with eyes.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 15),
                ),
                const SizedBox(height: 48),
                _buildBody(),
                const SizedBox(height: 32),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case InstallState.checking:
        return const Column(
          children: [
            CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
            SizedBox(height: 16),
            Text('Checking for the HEIDES engine...',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ],
        );
      case InstallState.missing:
        return const Column(
          children: [
            Icon(Icons.memory_rounded, size: 48, color: AppColors.warning),
            SizedBox(height: 16),
            Text('The HEIDES engine is not installed yet.',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text(
              'HEIDES maps your codebase into a persistent graph and guards every change.\n'
              'It is one small local binary — no account, no cloud.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        );
      case InstallState.installing:
        return Column(
          children: [
            const CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
            const SizedBox(height: 16),
            const Text('Installing HEIDES engine...',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _message.isEmpty ? 'Contacting registry...' : _message,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      case InstallState.installed:
        return Column(
          children: [
            const Icon(Icons.check_circle_rounded, size: 48, color: AppColors.success),
            const SizedBox(height: 16),
            Text(_message,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        );
      case InstallState.failed:
        return Column(
          children: [
            const Icon(Icons.error_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            const Text('Installation failed',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(_message,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center),
          ],
        );
    }
  }

  Widget _buildActions() {
    switch (_state) {
      case InstallState.checking:
      case InstallState.installing:
        return const SizedBox.shrink();
      case InstallState.missing:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _install,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Install HEIDES'),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: _continue,
              child: const Text('Skip for now', style: TextStyle(color: AppColors.textMuted)),
            ),
          ],
        );
      case InstallState.installed:
        return const SizedBox.shrink();
      case InstallState.failed:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _install,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: _continue,
              child: const Text('Skip for now', style: TextStyle(color: AppColors.textMuted)),
            ),
          ],
        );
    }
  }
}