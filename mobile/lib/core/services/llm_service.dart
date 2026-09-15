import 'dart:convert';
import 'package:http/http.dart' as http;

class LLMService {
  static Future<String> chat({
    required String provider,
    required String model,
    required String apiKey,
    required List<Map<String, String>> messages,
  }) async {
    if (apiKey.isEmpty) return 'No API key configured. Please set your API key in Settings.';

    try {
      switch (provider) {
        case 'openai':
          return await _openaiChat(model: model, apiKey: apiKey, messages: messages);
        case 'anthropic':
          return await _anthropicChat(model: model, apiKey: apiKey, messages: messages);
        case 'openrouter':
          return await _openrouterChat(model: model, apiKey: apiKey, messages: messages);
        case 'gemini':
          return await _geminiChat(model: model, apiKey: apiKey, messages: messages);
        case 'ollama':
          return await _ollamaChat(model: model, messages: messages);
        default:
          return 'Unsupported provider: $provider';
      }
    } catch (e) {
      return 'Error: ${e.toString()}';
    }
  }

  static Future<String> _openaiChat({
    required String model,
    required String apiKey,
    required List<Map<String, String>> messages,
  }) async {
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'messages': messages,
        'max_tokens': 2048,
      }),
    );
    return _parseResponse(response);
  }

  static Future<String> _anthropicChat({
    required String model,
    required String apiKey,
    required List<Map<String, String>> messages,
  }) async {
    final systemMsg = messages.where((m) => m['role'] == 'system').map((m) => m['content'] ?? '').join('\n');
    final chatMessages = messages.where((m) => m['role'] != 'system').toList();

    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': model,
        'max_tokens': 2048,
        if (systemMsg.isNotEmpty) 'system': systemMsg,
        'messages': chatMessages,
      }),
    );
    return _parseAnthropicResponse(response);
  }

  static Future<String> _openrouterChat({
    required String model,
    required String apiKey,
    required List<Map<String, String>> messages,
  }) async {
    final response = await http.post(
      Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
        'HTTP-Referer': 'https://github.com/AbduljabbarBXR/heides',
        'X-Title': 'Heides Lens',
      },
      body: jsonEncode({
        'model': model,
        'messages': messages,
        'max_tokens': 2048,
      }),
    );
    return _parseResponse(response);
  }

  static Future<String> _geminiChat({
    required String model,
    required String apiKey,
    required List<Map<String, String>> messages,
  }) async {
    final contents = messages
        .where((m) => m['role'] != 'system')
        .map((m) => {
              'role': m['role'] == 'assistant' ? 'model' : 'user',
              'parts': [{'text': m['content'] ?? ''}],
            })
        .toList();

    final response = await http.post(
      Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': contents,
        'generationConfig': {'maxOutputTokens': 2048},
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? 'No response';
    }
    return 'API error ${response.statusCode}: ${response.body}';
  }

  static Future<String> _ollamaChat({
    required String model,
    required List<Map<String, String>> messages,
  }) async {
    final response = await http.post(
      Uri.parse('http://localhost:11434/api/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': model,
        'messages': messages,
        'stream': false,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['message']?['content'] ?? 'No response';
    }
    return 'Ollama error ${response.statusCode}: ${response.body}';
  }

  static Future<String> testConnection({
    required String provider,
    required String model,
    required String apiKey,
  }) async {
    try {
      final result = await chat(
        provider: provider,
        model: model,
        apiKey: apiKey,
        messages: [
          {'role': 'user', 'content': 'Say "Connection successful" in exactly 2 words.'},
        ],
      );
      if (result.startsWith('Error') || result.startsWith('API error')) {
        return result;
      }
      return 'Connection successful';
    } catch (e) {
      return 'Connection failed: ${e.toString()}';
    }
  }

  static String _parseResponse(http.Response response) {
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices']?[0]?['message']?['content'] ?? 'No response';
    }
    return 'API error ${response.statusCode}: ${response.body}';
  }

  static String _parseAnthropicResponse(http.Response response) {
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['content'];
      if (content is List && content.isNotEmpty) {
        return content[0]['text'] ?? 'No response';
      }
      return 'No response';
    }
    return 'API error ${response.statusCode}: ${response.body}';
  }
}
