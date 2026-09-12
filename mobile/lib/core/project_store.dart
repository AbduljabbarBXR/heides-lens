import 'package:flutter/foundation.dart';

class Project {
  final String id;
  final String name;
  final String path;
  final DateTime lastSynced;

  Project({required this.id, required this.name, required this.path, required this.lastSynced});
}

class ProjectStore extends ChangeNotifier {
  final List<Project> _projects = [];

  List<Project> get projects => List.unmodifiable(_projects);

  void addProject(Project project) {
    _projects.add(project);
    notifyListeners();
  }

  void removeProject(String id) {
    _projects.removeWhere((p) => p.id == id);
    notifyListeners();
  }
}
