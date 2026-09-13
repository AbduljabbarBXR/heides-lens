import 'package:flutter/material.dart';
import 'package:spikey/shared/themes/app_colors.dart';

class DocsSection {
  final String title;
  final String subtitle;
  final String image;
  final List<String> bullets;

  const DocsSection({
    required this.title,
    required this.subtitle,
    required this.image,
    required this.bullets,
  });
}

const List<DocsSection> docsSections = [
  DocsSection(
    title: 'Welcome & Onboarding',
    subtitle: 'First launch experience',
    image: 'assets/images/screens/welcome.png',
    bullets: [
      'Interactive tour of the four core capabilities',
      'Quick links to documentation, repository, and marketplace',
      'Open a project to start analyzing your codebase',
    ],
  ),
  DocsSection(
    title: 'Explorer',
    subtitle: 'Browse your project files',
    image: 'assets/images/screens/explorer.png',
    bullets: [
      'Language-aware file tree with colored icons',
      'Open any file to view it with breadcrumb navigation',
      'Open/close with the Explorer icon or Ctrl+1',
    ],
  ),
  DocsSection(
    title: 'Plan',
    subtitle: 'Architecture scaffolding',
    image: 'assets/images/screens/plan.png',
    bullets: [
      'Describe a feature and generate an architecture scaffold',
      'Covers edge cases, error handling, and design patterns',
      'Creates real project files from the scaffold',
    ],
  ),
  DocsSection(
    title: 'Workflow',
    subtitle: 'Chat with your codebase',
    image: 'assets/images/screens/workflow.png',
    bullets: [
      'AI assistant with full project context (file tree, dependencies, findings)',
      'Markdown rendering with syntax-highlighted code blocks',
      'Works with OpenRouter, OpenAI, Anthropic, Gemini, and Ollama',
    ],
  ),
  DocsSection(
    title: 'Neural Graph',
    subtitle: 'Visualize your architecture',
    image: 'assets/images/screens/graph.png',
    bullets: [
      'Layered dependency layout with orthogonal connections',
      'Filter by node type via the dropdown, search files',
      'Double-click to zoom, drag to pan, buttons for stepped zoom',
      'Grid view for a card-based overview',
    ],
  ),
  DocsSection(
    title: 'Review',
    subtitle: 'Automated code findings',
    image: 'assets/images/screens/review.png',
    bullets: [
      'Critical, warning, and info findings from static analysis',
      'Click a finding to preview the exact file and line',
      'Suggestions inline with every finding',
    ],
  ),
  DocsSection(
    title: 'Plugins',
    subtitle: 'Extend Spikey',
    image: 'assets/images/screens/plugins.png',
    bullets: [
      'Browse the marketplace with live search and categories',
      'Install plugins with one click',
      'Sandboxed execution model with permissions',
    ],
  ),
  DocsSection(
    title: 'Settings',
    subtitle: 'Configure your AI provider',
    image: 'assets/images/screens/settings.png',
    bullets: [
      'Provider selection (OpenRouter, OpenAI, Anthropic, Gemini, Ollama)',
      'Model dropdown per provider',
      'API keys stored in secure storage, test connection button',
    ],
  ),
];

class DocumentationScreen extends StatelessWidget {
  const DocumentationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, size: 18, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Back',
                ),
                const SizedBox(width: 8),
                Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Text('Documentation', style: AppTextStyles.h3),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHover,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    '${docsSections.length} sections',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: docsSections.length,
              itemBuilder: (context, index) => _DocsCard(section: docsSections[index], index: index),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocsCard extends StatefulWidget {
  final DocsSection section;
  final int index;

  const _DocsCard({required this.section, required this.index});

  @override
  State<_DocsCard> createState() => _DocsCardState();
}

class _DocsCardState extends State<_DocsCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isHovered ? AppColors.surfaceHover : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _isHovered ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${widget.index + 1}. ${widget.section.title}',
                    style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                Text(
                  widget.section.subtitle,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Screenshot
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Image.asset(
                    widget.section.image,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stack) => Container(
                      color: AppColors.background,
                      alignment: Alignment.center,
                      child: Text(
                        'Screenshot: ${widget.section.image}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...widget.section.bullets.map((b) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(b, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}