import 'dart:convert';
import 'package:http/http.dart' as http;

class PluginMarketplace {
  static const String registryUrl = 'https://registry.spikey.dev';
  
  Future<List<Map<String, dynamic>>> searchPlugins(String query) async {
    try {
      final response = await http.get(Uri.parse('$registryUrl/api/plugins?q=$query'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      // Offline mode - return local plugins
    }
    return _getLocalPlugins();
  }

  Future<List<Map<String, dynamic>>> listCategories() async {
    try {
      final response = await http.get(Uri.parse('$registryUrl/api/categories'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      // Return default categories
    }
    return [
      {'id': 'security', 'name': 'Security'},
      {'id': 'analysis', 'name': 'Analysis'},
      {'id': 'style', 'name': 'Style'},
      {'id': 'performance', 'name': 'Performance'},
      {'id': 'architecture', 'name': 'Architecture'},
    ];
  }

  Future<Map<String, dynamic>?> getPluginDetails(String pluginId) async {
    try {
      final response = await http.get(Uri.parse('$registryUrl/api/plugins/$pluginId'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      // Check local plugins
      final local = _getLocalPlugins().firstWhere(
        (p) => p['id'] == pluginId,
        orElse: () => {},
      );
      if (local.isNotEmpty) return local;
    }
    return null;
  }

  Future<bool> installPlugin(String pluginId) async {
    try {
      final response = await http.get(Uri.parse('$registryUrl/api/plugins/$pluginId/download'));
      if (response.statusCode == 200) {
        // Save plugin to local plugins directory
        // In real app, extract .vcp file and load manifest
        return true;
      }
    } catch (e) {
      // Simulate installation for demo
      return true;
    }
    return false;
  }

  List<Map<String, dynamic>> _getLocalPlugins() {
    return [
      {
        'id': 'com.spikey.security-scanner',
        'name': 'Security Scanner',
        'version': '1.0.0',
        'description': 'Detects common security vulnerabilities',
        'author': 'spikey-official',
        'category': ['security'],
        'downloads': 15420,
        'rating': 4.8,
      },
      {
        'id': 'com.spikey.performance-analyzer',
        'name': 'Performance Analyzer',
        'version': '1.0.0',
        'description': 'Identifies performance bottlenecks',
        'author': 'spikey-official',
        'category': ['performance'],
        'downloads': 8930,
        'rating': 4.5,
      },
      {
        'id': 'com.spikey.architecture-checker',
        'name': 'Architecture Checker',
        'version': '1.0.0',
        'description': 'Validates architecture patterns',
        'author': 'spikey-official',
        'category': ['architecture'],
        'downloads': 5620,
        'rating': 4.6,
      },
    ];
  }
}
