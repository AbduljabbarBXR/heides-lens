import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spikey/shared/themes/app_colors.dart';
import 'package:spikey/core/providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Provider selection
          Text('AI Provider', style: AppTextStyles.h3),
          const SizedBox(height: 12),
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Provider', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _ProviderChip(
                      label: 'OpenRouter',
                      isSelected: config.provider == 'openrouter',
                      onTap: () => ref.read(settingsProvider.notifier).setProvider('openrouter'),
                    ),
                    _ProviderChip(
                      label: 'OpenAI',
                      isSelected: config.provider == 'openai',
                      onTap: () => ref.read(settingsProvider.notifier).setProvider('openai'),
                    ),
                    _ProviderChip(
                      label: 'Anthropic',
                      isSelected: config.provider == 'anthropic',
                      onTap: () => ref.read(settingsProvider.notifier).setProvider('anthropic'),
                    ),
                     _ProviderChip(
                       label: 'Gemini',
                       isSelected: config.provider == 'gemini',
                       onTap: () => ref.read(settingsProvider.notifier).setProvider('gemini'),
                     ),
                     _ProviderChip(
                       label: 'OpenCode',
                       isSelected: config.provider == 'opencode',
                       onTap: () => ref.read(settingsProvider.notifier).setProvider('opencode'),
                     ),
                     _ProviderChip(
                       label: 'Ollama',
                       isSelected: config.provider == 'ollama',
                       onTap: () => ref.read(settingsProvider.notifier).setProvider('ollama'),
                     ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Model selection
          Text('Model', style: AppTextStyles.h3),
          const SizedBox(height: 12),
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Model', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: config.model,
                    isExpanded: true,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    dropdownColor: AppColors.surface,
                    items: _getModelsForProvider(config.provider)
                        .map((model) => DropdownMenuItem(
                              value: model,
                              child: Text(model),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(settingsProvider.notifier).setModel(value);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // API Key
          Text('API Key', style: AppTextStyles.h3),
          const SizedBox(height: 12),
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Enter your API key', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                TextField(
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: config.apiKey.isEmpty ? 'sk-...' : '******',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    suffixIcon: config.apiKey.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => ref.read(settingsProvider.notifier).setApiKey(''),
                          )
                        : null,
                  ),
                  onChanged: (value) => ref.read(settingsProvider.notifier).setApiKey(value),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Status
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(
                  config.isValid ? Icons.check_circle_rounded : Icons.error_rounded,
                  color: config.isValid ? AppColors.success : AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  config.isValid ? 'Configuration valid' : 'API key required',
                  style: TextStyle(color: config.isValid ? AppColors.success : AppColors.error, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getModelsForProvider(String provider) {
    switch (provider) {
      case 'openai':
        return ['gpt-4o', 'gpt-4o-mini', 'gpt-4-turbo', 'gpt-3.5-turbo'];
      case 'anthropic':
        return ['claude-3-5-sonnet-20240620', 'claude-3-opus-20240229', 'claude-3-haiku-20240307'];
      case 'ollama':
        return ['llama-3.1', 'mistral', 'codellama', 'phi3'];
      case 'openrouter':
        return [
          'openai/gpt-4o',
          'openai/gpt-4o-mini',
          'anthropic/claude-3.5-sonnet',
          'anthropic/claude-3-opus',
          'google/gemini-pro',
          'deepseek/deepseek-chat',
          'kimi/kimi-chat',
          'minimax/minimax-chat',
          'meta-llama/llama-3.1-70b',
          'meta-llama/llama-3.1-405b',
        ];
      case 'gemini':
        return ['gemini-1.5-pro', 'gemini-1.5-flash', 'gemini-1.0-pro'];
      case 'opencode':
        return [
          'opencode-go/kimi-k3',
          'opencode-go/deepseek-v4-pro',
          'opencode-go/deepseek-v4-flash',
          'opencode-go/qwen3.7-max',
          'opencode-go/qwen3.7-plus',
          'opencode-go/glm-5.2',
          'opencode-go/minimax-m3',
          'opencode-go/mimo-v2.5-free',
          'opencode-go/nemotron-3-ultra-free',
          'opencode-go/nemotron-3.5-lightning-free',
        ];
      default:
        return ['default'];
    }
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;

  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _ProviderChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProviderChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceHover,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.background : AppColors.textPrimary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
