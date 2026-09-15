import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:heides_lens/shared/themes/app_colors.dart';
import 'package:heides_lens/shared/logos.dart';

class LogoPickerScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const LogoPickerScreen({super.key, required this.onComplete});

  @override
  State<LogoPickerScreen> createState() => _LogoPickerScreenState();
}

class _LogoPickerScreenState extends State<LogoPickerScreen> {
  int? _selectedId;

  Future<void> _select(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('logo_choice', id);
    if (mounted) {
      setState(() => _selectedId = id);
    }
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Heides Lens',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose a logo',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 16),
                ),
                const SizedBox(height: 48),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: heidesLogos.map((logo) {
                    final isSelected = _selectedId == logo.id;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _LogoOptionCard(
                        logo: logo,
                        isSelected: isSelected,
                        onTap: () => _select(logo.id),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 40),
                Text(
                  'Pick one — you can change it later from Help menu',
                  style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.6), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoOptionCard extends StatefulWidget {
  final HeidesLogo logo;
  final bool isSelected;
  final VoidCallback onTap;

  const _LogoOptionCard({
    required this.logo,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_LogoOptionCard> createState() => _LogoOptionCardState();
}

class _LogoOptionCardState extends State<_LogoOptionCard> {
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
          width: 132,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.logo.accent.withValues(alpha: 0.15)
                : _isHovered
                    ? AppColors.surfaceHover
                    : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isSelected
                  ? widget.logo.accent
                  : _isHovered
                      ? widget.logo.accent.withValues(alpha: 0.5)
                      : AppColors.border,
              width: widget.isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              // Number badge
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: widget.logo.accent.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: widget.logo.accent),
                ),
                child: Center(
                  child: Text(
                    '${widget.logo.id}',
                    style: TextStyle(
                      color: widget.logo.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Logo preview (mark + wordmark stacked)
              HeidesLogoMark(id: widget.logo.id, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Heides Lens',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.logo.name,
                style: TextStyle(
                  color: widget.logo.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}