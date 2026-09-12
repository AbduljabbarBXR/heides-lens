import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppConfig {
  final String provider;
  final String model;
  final String apiKey;

  const AppConfig({
    this.provider = 'openai',
    this.model = 'gpt-4o',
    this.apiKey = '',
  });

  AppConfig copyWith({String? provider, String? model, String? apiKey}) {
    return AppConfig(
      provider: provider ?? this.provider,
      model: model ?? this.model,
      apiKey: apiKey ?? this.apiKey,
    );
  }

  bool get isValid => apiKey.isNotEmpty;
}

class SettingsNotifier extends StateNotifier<AppConfig> {
  SettingsNotifier() : super(const AppConfig());

  void setProvider(String provider) {
    final models = _getModelsForProvider(provider);
    state = state.copyWith(provider: provider, model: models.first);
  }

  void setModel(String model) {
    state = state.copyWith(model: model);
  }

  void setApiKey(String apiKey) {
    state = state.copyWith(apiKey: apiKey);
  }

  List<String> _getModelsForProvider(String provider) {
    switch (provider) {
      case 'openai':
        return ['gpt-4o', 'gpt-4o-mini', 'gpt-4-turbo', 'gpt-3.5-turbo'];
      case 'anthropic':
        return ['claude-3-5-sonnet', 'claude-3-opus', 'claude-3-haiku'];
      case 'ollama':
        return ['llama-3.1', 'mistral', 'codellama', 'phi3'];
      default:
        return ['default'];
    }
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppConfig>((ref) {
  return SettingsNotifier();
});
