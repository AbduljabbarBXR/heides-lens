import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vybecode_mobile/core/project_store.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ProjectStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('VybeCode'), backgroundColor: Theme.of(context).colorScheme.surface),
      body: store.projects.isEmpty
          ? const Center(child: Text('No projects. Add one to start.'))
          : ListView.builder(
              itemCount: store.projects.length,
              itemBuilder: (context, index) {
                final project = store.projects[index];
                return ListTile(
                  title: Text(project.name),
                  subtitle: Text(project.path),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => store.removeProject(project.id),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddProjectDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddProjectDialog(BuildContext context) {
    final nameController = TextEditingController();
    final pathController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Project'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: pathController, decoration: const InputDecoration(labelText: 'Path')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && pathController.text.isNotEmpty) {
                context.read<ProjectStore>().addProject(Project(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameController.text,
                      path: pathController.text,
                      lastSynced: DateTime.now(),
                    ));
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
