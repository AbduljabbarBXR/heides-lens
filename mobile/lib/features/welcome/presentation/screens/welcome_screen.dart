import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:spikey/shared/themes/app_colors.dart';
import 'package:spikey/core/providers/project_provider.dart';
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
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.auto_awesome, color: AppColors.background, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Text('Spikey', style: AppTextStyles.h2.copyWith(color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 24),
              Text('Plugin-first AI coding platform', style: AppTextStyles.h3),
              const SizedBox(height: 8),
              Text('Predicts what will break before you deploy.', style: AppTextStyles.body),
              const SizedBox(height: 24),
              Text('Quick Links', style: AppTextStyles.h3.copyWith(fontSize: 16)),
              const SizedBox(height: 12),
              _LinkRow(
                icon: Icons.description_rounded,
                label: 'Documentation',
                onTap: () => _launchUrl('https://github.com/AbduljabbarBXR/spikey'),
              ),
              const SizedBox(height: 8),
              _LinkRow(
                icon: Icons.code_rounded,
                label: 'GitHub Repository',
                onTap: () => _launchUrl('https://github.com/AbduljabbarBXR/spikey'),
              ),
              const SizedBox(height: 8),
              _LinkRow(
                icon: Icons.extension_rounded,
                label: 'Plugin Marketplace',
                onTap: () => _launchUrl('https://github.com/AbduljabbarBXR/spikey'),
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

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _LinkRow({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceHover,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            const Spacer(),
            Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
