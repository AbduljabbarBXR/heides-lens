import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Project {
  final String id;
  final String name;
  final String path;
  final DateTime lastOpened;
  final bool isIndexed;

  Project({
    required this.id,
    required this.name,
    required this.path,
    required this.lastOpened,
    this.isIndexed = false,
  });

  Project copyWith({String? name, String? path, DateTime? lastOpened, bool? isIndexed}) {
    return Project(
      id: id,
      name: name ?? this.name,
      path: path ?? this.path,
      lastOpened: lastOpened ?? this.lastOpened,
      isIndexed: isIndexed ?? this.isIndexed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'lastOpened': lastOpened.toIso8601String(),
      'isIndexed': isIndexed,
    };
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      name: json['name'] as String,
      path: json['path'] as String,
      lastOpened: DateTime.parse(json['lastOpened'] as String),
      isIndexed: json['isIndexed'] as bool? ?? false,
    );
  }
}

class ProjectState {
  final List<Project> projects;
  final Project? activeProject;

  const ProjectState({this.projects = const [], this.activeProject});
}

class ProjectNotifier extends StateNotifier<ProjectState> {
  static const _key = 'projects';
  ProjectNotifier() : super(const ProjectState()) {
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        final List<dynamic> decoded = json.decode(raw);
        final projects = decoded.map((p) => Project.fromJson(p)).toList();
        final active = projects.isNotEmpty ? projects.first : null;
        state = ProjectState(projects: projects, activeProject: active);
      }
    } catch (_) {
      // ignore load errors
    }
  }

  Future<void> _persistProjects() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = json.encode(state.projects.map((p) => p.toJson()).toList());
      await prefs.setString(_key, encoded);
    } catch (_) {
      // ignore persistence errors
    }
  }

  Future<void> addProject(Project project) async {
    state = ProjectState(projects: [...state.projects, project], activeProject: project);
    await _persistProjects();
  }

  Future<void> setActiveProject(Project project) async {
    state = ProjectState(projects: state.projects, activeProject: project);
    await _persistProjects();
  }

  Future<void> updateProject(Project project) async {
    final projects = state.projects.map((p) => p.id == project.id ? project : p).toList();
    final active = state.activeProject?.id == project.id ? project : state.activeProject;
    state = ProjectState(projects: projects, activeProject: active);
    await _persistProjects();
  }

  Future<void> removeProject(String projectId) async {
    final projects = state.projects.where((p) => p.id != projectId).toList();
    final active = state.activeProject?.id == projectId ? (projects.isNotEmpty ? projects.first : null) : state.activeProject;
    state = ProjectState(projects: projects, activeProject: active);
    await _persistProjects();
  }
}

final projectProvider = StateNotifierProvider<ProjectNotifier, ProjectState>((ref) {
  return ProjectNotifier();
});
