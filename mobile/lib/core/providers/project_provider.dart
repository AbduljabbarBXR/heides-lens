import 'package:flutter_riverpod/flutter_riverpod.dart';

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
}

class ProjectState {
  final List<Project> projects;
  final Project? activeProject;

  const ProjectState({this.projects = const [], this.activeProject});
}

class ProjectNotifier extends StateNotifier<ProjectState> {
  ProjectNotifier() : super(const ProjectState());

  void addProject(Project project) {
    state = ProjectState(projects: [...state.projects, project], activeProject: project);
  }

  void setActiveProject(Project project) {
    state = ProjectState(projects: state.projects, activeProject: project);
  }

  void updateProject(Project project) {
    final projects = state.projects.map((p) => p.id == project.id ? project : p).toList();
    final active = state.activeProject?.id == project.id ? project : state.activeProject;
    state = ProjectState(projects: projects, activeProject: active);
  }
}

final projectProvider = StateNotifierProvider<ProjectNotifier, ProjectState>((ref) {
  return ProjectNotifier();
});
