import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:heides_lens/shared/themes/app_colors.dart';
import 'package:heides_lens/shared/logos.dart';
import 'package:heides_lens/core/providers/project_provider.dart';
import 'package:heides_lens/features/docs/presentation/screens/docs_screen.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _dismissWelcome(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('welcome_dismissed', true);
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _openProject(BuildContext context, WidgetRef ref) async {
    final String? directoryPath = await getDirectoryPath();
    if (directoryPath == null) return;

    final projectName = p.basename(directoryPath);
    final project = Project(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: projectName,
      path: directoryPath,
      lastOpened: DateTime.now(),
    );

    ref.read(projectProvider.notifier).addProject(project);
    await _dismissWelcome(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _WelcomeLogo(),
              const SizedBox(height: 24),
              Text('The nervous system for your code, with eyes.', style: AppTextStyles.h3),
              const SizedBox(height: 8),
              Text('A read-only lens over the HEIDES graph — explore, query, and inspect your codebase.', style: AppTextStyles.body),
              const SizedBox(height: 24),
              Text('Quick Links', style: AppTextStyles.h3.copyWith(fontSize: 16)),
              const SizedBox(height: 12),
              _LinkRow(
                icon: Icons.description_rounded,
                label: 'Documentation',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DocumentationScreen()),
                  );
                },
              ),
              const SizedBox(height: 8),
              _LinkRow(
                icon: Icons.code_rounded,
                label: 'HEIDES on GitHub',
                onTap: () => _launchUrl('https://github.com/AbduljabbarBXR/heides'),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _openProject(context, ref),
                    icon: const Icon(Icons.folder_open_rounded, size: 18),
                    label: const Text('Open Project'),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: () => _dismissWelcome(context),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _LinkRow({required this.icon, required this.label, required this.onTap});

  @override
  State<_LinkRow> createState() => _LinkRowState();
}

class _LinkRowState extends State<_LinkRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surfaceHover,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _isHovered ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 12),
              Text(widget.label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
              const Spacer(),
              Icon(Icons.open_in_new_rounded, size: 14, color: _isHovered ? AppColors.primary : AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeLogo extends StatefulWidget {
  const _WelcomeLogo();

  @override
  State<_WelcomeLogo> createState() => _WelcomeLogoState();
}

class _WelcomeLogoState extends State<_WelcomeLogo> {
  int _logoId = 1;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() => _logoId = prefs.getInt('logo_choice') ?? 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return HeidesLogoFull(id: _logoId, markSize: 52, fontSize: 30);
  }
}
