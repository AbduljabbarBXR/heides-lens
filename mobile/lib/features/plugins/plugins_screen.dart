import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vybecode_mobile/core/plugin_store.dart';

class PluginsScreen extends StatelessWidget {
  const PluginsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PluginStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('Plugins')),
      body: store.plugins.isEmpty
          ? const Center(child: Text('No plugins installed.'))
          : ListView.builder(
              itemCount: store.plugins.length,
              itemBuilder: (context, index) {
                final plugin = store.plugins[index];
                return ListTile(
                  title: Text(plugin.name),
                  subtitle: Text('v${plugin.version} • ${plugin.hooks.join(', ')}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => store.removePlugin(plugin.id),
                  ),
                );
              },
            ),
    );
  }
}
