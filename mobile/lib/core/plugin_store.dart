import 'package:flutter/foundation.dart';

class PluginManifest {
  final String id;
  final String name;
  final String version;
  final List<String> permissions;
  final List<String> hooks;

  PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.permissions,
    required this.hooks,
  });

  factory PluginManifest.fromJson(Map<String, dynamic> json) {
    return PluginManifest(
      id: json['id'] as String,
      name: json['name'] as String,
      version: json['version'] as String,
      permissions: List<String>.from(json['permissions'] ?? []),
      hooks: List<String>.from(json['hooks'] ?? []),
    );
  }
}

class PluginStore extends ChangeNotifier {
  final List<PluginManifest> _plugins = [];

  List<PluginManifest> get plugins => List.unmodifiable(_plugins);

  void loadPlugins(List<PluginManifest> plugins) {
    _plugins.clear();
    _plugins.addAll(plugins);
    notifyListeners();
  }

  void addPlugin(PluginManifest plugin) {
    _plugins.add(plugin);
    notifyListeners();
  }

  void removePlugin(String id) {
    _plugins.removeWhere((p) => p.id == id);
    notifyListeners();
  }
}
