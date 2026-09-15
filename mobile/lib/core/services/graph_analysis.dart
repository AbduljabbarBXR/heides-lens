import 'package:heides_lens/data/services/indexing_engine.dart';

/// Deterministic structural analysis of a file-level dependency graph.
///
/// One source of truth shared by the Neural Graph screen and the activity-bar
/// badges, so the badge count and the graph can never disagree.
class GraphAnalysis {
  final Set<String> entryPoints;
  final Set<String> hubs;
  final Set<String> cyclePaths;

  const GraphAnalysis({
    required this.entryPoints,
    required this.hubs,
    required this.cyclePaths,
  });

  /// Analyze [files] (paths) and [edges] (maps with 'from'/'to').
  /// Files mentioned by edges but absent from [files] are ignored.
  static GraphAnalysis analyze(
    List<IndexedFile> files,
    List<Map<String, dynamic>> edges,
  ) {
    final paths = {for (final f in files) f.path};
    return analyzePaths(paths, edges);
  }

  /// Same analysis over raw paths (used by callers that only have paths).
  static GraphAnalysis analyzePaths(
    Set<String> paths,
    List<Map<String, dynamic>> edges,
  ) {
    return GraphAnalysis(
      entryPoints: _entryPoints(paths, edges),
      hubs: _hubs(paths, edges),
      cyclePaths: _cyclePaths(paths, edges),
    );
  }

  /// Entry points: files nothing else depends on (roots of the graph).
  static Set<String> _entryPoints(Set<String> paths, List<Map<String, dynamic>> edges) {
    final imported = <String>{};
    for (final e in edges) {
      final to = e['to'] as String;
      if (paths.contains(to)) imported.add(to);
    }
    return paths.where((p) => !imported.contains(p)).toSet();
  }

  /// Hubs: the most-connected nodes (degree >= 3, or >= 2 for small graphs).
  static Set<String> _hubs(Set<String> paths, List<Map<String, dynamic>> edges) {
    final degree = <String, int>{};
    for (final e in edges) {
      final from = e['from'] as String;
      final to = e['to'] as String;
      if (paths.contains(from)) degree[from] = (degree[from] ?? 0) + 1;
      if (paths.contains(to)) degree[to] = (degree[to] ?? 0) + 1;
    }
    final threshold = paths.length <= 8 ? 2 : 3;
    return degree.entries
        .where((e) => e.value >= threshold)
        .map((e) => e.key)
        .toSet();
  }

  /// Files inside strongly connected components with more than one member
  /// (Tarjan). This is the same algorithm the graph renders, so the badge
  /// count always matches what the user sees highlighted in Cycles facet.
  static Set<String> _cyclePaths(Set<String> paths, List<Map<String, dynamic>> edges) {
    final adj = <String, List<String>>{};
    for (final p in paths) {
      adj[p] = [];
    }
    for (final e in edges) {
      final from = e['from'] as String;
      final to = e['to'] as String;
      if (adj.containsKey(from) && adj.containsKey(to)) adj[from]!.add(to);
    }

    final index = <String, int>{};
    final lowLink = <String, int>{};
    final onStack = <String>{};
    final stack = <String>[];
    final cycleNodes = <String>{};
    var counter = 0;

    void strongConnect(String v) {
      index[v] = counter;
      lowLink[v] = counter;
      counter++;
      stack.add(v);
      onStack.add(v);

      for (final w in adj[v]!) {
        if (!index.containsKey(w)) {
          strongConnect(w);
          lowLink[v] = lowLink[v]! < lowLink[w]! ? lowLink[v]! : lowLink[w]!;
        } else if (onStack.contains(w)) {
          lowLink[v] = lowLink[v]! < index[w]! ? lowLink[v]! : index[w]!;
        }
      }

      if (lowLink[v] == index[v]) {
        final component = <String>[];
        while (true) {
          final w = stack.removeLast();
          onStack.remove(w);
          component.add(w);
          if (w == v) break;
        }
        if (component.length > 1) cycleNodes.addAll(component);
      }
    }

    for (final p in paths) {
      if (!index.containsKey(p)) strongConnect(p);
    }
    return cycleNodes;
  }
}
