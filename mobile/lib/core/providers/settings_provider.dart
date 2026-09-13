import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class AppConfig {
  final String provider;
  final String model;
  final String apiKey;

  const AppConfig({
    this.provider = 'openrouter',
    this.model = 'openai/gpt-4o',
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
  SettingsNotifier({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        super(const AppConfig()) {
    _loadAll();
  }

  final FlutterSecureStorage _secureStorage;

  static const _providerEnvKeys = <String, String>{
    'openai': 'OPENAI_API_KEY',
    'anthropic': 'ANTHROPIC_API_KEY',
    'ollama': 'OLLAMA_BASE_URL',
    'openrouter': 'OPENROUTER_API_KEY',
    'gemini': 'GEMINI_API_KEY',
    'deepseek': 'DEEPSEEK_API_KEY',
    'kimi': 'KIMI_API_KEY',
    'minimax': 'MINIMAX_API_KEY',
    'huggingface': 'HUGGINGFACE_API_KEY',
    'opencode': 'OPENCODE_API_KEY',
  };

  String? _envApiKey(String provider) {
    try {
      final envKey = _providerEnvKeys[provider];
      if (envKey != null) {
        final value = Platform.environment[envKey];
        if (value != null && value.isNotEmpty) return value;
      }
      final generic = Platform.environment['API_KEY'];
      if (generic != null && generic.isNotEmpty) return generic;
    } on Exception catch (_) {}
    return null;
  }

  Future<void> _loadAll() async {
    try {
      final stored = await _secureStorage.read(key: 'apiKey') ?? '';
      final prefs = await SharedPreferences.getInstance();
      final savedProvider = prefs.getString('settings_provider') ?? 'openrouter';
      final savedModel = prefs.getString('settings_model') ?? 'openai/gpt-4o';

      // Auto-set OpenRouter key from environment or use stored key
      String apiKey = stored;
      if (apiKey.isEmpty) {
        final envKey = _envApiKey(savedProvider);
        apiKey = envKey ?? '';
      }

      state = AppConfig(provider: savedProvider, model: savedModel, apiKey: apiKey);
    } on Exception catch (_) {}
  }

  Future<void> _persistSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('settings_provider', state.provider);
      await prefs.setString('settings_model', state.model);
    } on Exception catch (_) {}
  }

  void setProvider(String provider) {
    final models = _getModelsForProvider(provider);
    final envKey = _envApiKey(provider);
    state = state.copyWith(provider: provider, model: models.first, apiKey: envKey ?? state.apiKey);
    _persistSettings();
  }

  void setModel(String model) {
    state = state.copyWith(model: model);
    _persistSettings();
  }

  Future<void> setApiKey(String apiKey) async {
    state = state.copyWith(apiKey: apiKey);
    try {
      if (apiKey.isEmpty) {
        await _secureStorage.delete(key: 'apiKey');
      } else {
        await _secureStorage.write(key: 'apiKey', value: apiKey);
      }
    } on Exception catch (_) {}
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

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppConfig>((ref) {
  return SettingsNotifier();
});
