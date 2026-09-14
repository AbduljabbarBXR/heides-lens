import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:spikey/shared/themes/app_colors.dart';
import 'package:spikey/core/providers/indexing_provider.dart';
import 'package:spikey/core/providers/project_provider.dart';
import 'package:spikey/data/services/indexing_engine.dart';

// Node type colors (matching Supabase schema visualizer pattern)
const Map<String, Color> nodeTypeColors = {
  'component': Color(0xFF007ACC),   // Blue - main files
  'service': Color(0xFFC586C0),     // Purple - services
  'util': Color(0xFFCCA700),        // Amber - utilities
  'model': Color(0xFFF48771),       // Red - models/types
  'test': Color(0xFF89D185),        // Green - tests
  'config': Color(0xFF606060),      // Gray - config files
  'entry': Color(0xFF4FC1FF),       // Cyan - entry points
  'other': Color(0xFF969696),       // Default
};

const Map<String, String> nodeTypeLabels = {
  'component': 'Components',
  'service': 'Services',
  'util': 'Utilities',
  'model': 'Models/Types',
  'test': 'Tests',
  'config': 'Config',
  'entry': 'Entry Points',
  'other': 'Other',
};

class GraphScreen extends ConsumerStatefulWidget {
  const GraphScreen({super.key});

  @override
  ConsumerState<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends ConsumerState<GraphScreen> {
  bool _indexing = false;
  double _indexProgress = 0.0;
  final Map<String, Offset> _nodePositions = {};
  String? _selectedNode;
  String? _hoveredNode;
  String _searchQuery = '';
  final Set<String> _visibleTypes = Set.from(nodeTypeColors.keys);
  Offset? _dragStart;
  String? _draggingPath;
  final TransformationController _transformController = TransformationController();
  final GlobalKey _viewerKey = GlobalKey();
  bool _initialFitDone = false;
  bool _isGridView = false;
  bool _isPanning = false;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  /// Discrete zoom step around a focal point (viewport center for buttons,
  /// cursor position for double-click). Uses the same focal-point math as
  /// InteractiveViewer, so programmatic and gesture zoom never conflict.
  void _zoomAtPoint(Offset focalPoint, double factor) {
    final current = _transformController.value;
    final currentScale = current.getMaxScaleOnAxis();
    final newScale = (currentScale * factor).clamp(0.1, 4.0);
    final k = newScale / currentScale;
    _transformController.value = Matrix4.identity()
      ..translate(focalPoint.dx, focalPoint.dy)
      ..scale(k)
      ..translate(-focalPoint.dx, -focalPoint.dy)
      ..multiply(current);
  }

  void _stepZoom(double factor) {
    final viewport = _viewerKey.currentContext?.size;
    if (viewport == null) return;
    _zoomAtPoint(Offset(viewport.width / 2, viewport.height / 2), factor);
  }

  @override
  Widget build(BuildContext context) {
    final projectState = ref.watch(projectProvider);
    final filesAsync = ref.watch(indexedFilesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header with controls (Supabase style)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_tree_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text('Neural Graph', style: AppTextStyles.h3),
                    const Spacer(),
                    // Node/edge count
                    filesAsync.when(
                      data: (files) {
                        final edgeCount = files.length > 1 ? files.length - 1 : 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceHover,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text('${files.length} nodes • $edgeCount edges',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        );
                      },
                      loading: () => const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                      error: (_, __) => const Icon(Icons.error_rounded, size: 16, color: AppColors.error),
                    ),
                    const SizedBox(width: 12),
                    _ControlButton(
                      icon: Icons.refresh_rounded,
                      tooltip: 'Reset Layout',
                      onTap: _resetLayout,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Search, filter dropdown, and view toggle
                Row(
                  children: [
                    // Search
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 32,
                        child: TextField(
                          onChanged: (q) => setState(() => _searchQuery = q.toLowerCase()),
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Search files...',
                            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                            prefixIcon: const Icon(Icons.search_rounded, size: 16, color: AppColors.textMuted),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Filter dropdown
                    _FilterDropdown(
                      visibleTypes: _visibleTypes,
                      onToggle: (type, visible) {
                        setState(() {
                          if (visible) {
                            _visibleTypes.add(type);
                          } else {
                            _visibleTypes.remove(type);
                          }
                        });
                      },
                      onSelectAll: () => setState(() => _visibleTypes.addAll(nodeTypeColors.keys)),
                      onClearAll: () => setState(() => _visibleTypes.clear()),
                    ),
                    const SizedBox(width: 8),
                    // View toggle
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHover,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ViewToggleButton(
                            icon: Icons.account_tree_rounded,
                            tooltip: 'Graph View',
                            isActive: !_isGridView,
                            onTap: () => setState(() => _isGridView = false),
                          ),
                          Container(width: 1, height: 24, color: AppColors.border),
                          _ViewToggleButton(
                            icon: Icons.grid_view_rounded,
                            tooltip: 'Grid View',
                            isActive: _isGridView,
                            onTap: () => setState(() => _isGridView = true),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_indexing)
            LinearProgressIndicator(value: _indexProgress, backgroundColor: AppColors.surface, color: AppColors.primary),
          // Graph area
          Expanded(
            child: filesAsync.when(
              data: (files) {
                if (files.isEmpty) {
                  return _buildEmptyState(projectState);
                }
                final graphDataAsync = ref.watch(graphDataProvider(projectState.activeProject?.path ?? ''));
                return graphDataAsync.when(
                  data: (graphData) {
                    final filesList = graphData['files'] as List<IndexedFile>;
                    final edges = graphData['edges'] as List<Map<String, dynamic>>;

                    // Apply type filter and search
                    final visibleFiles = filesList.where((f) {
                      final type = _getFileType(f.path);
                      final typeVisible = _visibleTypes.contains(type);
                      final searchMatch = _searchQuery.isEmpty || p.basename(f.path).toLowerCase().contains(_searchQuery);
                      return typeVisible && searchMatch;
                    }).toList();

                    final visiblePaths = visibleFiles.map((f) => f.path).toSet();
                    final visibleEdges = edges.where((e) =>
                        visiblePaths.contains(e['from']) && visiblePaths.contains(e['to'])).toList();

                    // Initialize positions with force-directed layout
                    if (_nodePositions.isEmpty) {
                      _initializePositions(visibleFiles, visibleEdges);
                    }

                    // Calculate canvas size
                    double maxX = 0, maxY = 0;
                    for (final pos in _nodePositions.values) {
                      if (pos.dx > maxX) maxX = pos.dx;
                      if (pos.dy > maxY) maxY = pos.dy;
                    }
                    final canvasWidth = maxX + 300;
                    final canvasHeight = maxY + 200;

                    // Auto-fit on first load
                    if (!_initialFitDone && _nodePositions.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _fitToView();
                        _initialFitDone = true;
                      });
                    }

                    // Grid view
                    if (_isGridView) {
                      return _GridView(
                        files: visibleFiles,
                        edges: visibleEdges,
                        getFileType: _getFileType,
                        projectPath: projectState.activeProject?.path ?? '',
                        onFileTap: (path) {
                          setState(() {
                            _selectedNode = _selectedNode == path ? null : path;
                          });
                        },
                      );
                    }

                    // Graph view with InteractiveViewer
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
                        return Stack(
                      children: [
                        // Graph canvas — InteractiveViewer handles pan/zoom on background
                        RepaintBoundary(
                          child: GestureDetector(
                            // Double-click to zoom in at the cursor
                            onDoubleTapDown: (details) =>
                                _zoomAtPoint(details.localPosition, 1.5),
                            child: InteractiveViewer(
                          key: _viewerKey,
                          transformationController: _transformController,
                          constrained: false,
                          minScale: 0.1,
                          maxScale: 4.0,
                          // Infinite boundary = free panning in all directions
                          // (without it, InteractiveViewer locks an axis when the
                          // scaled content is narrower than the viewport)
                          boundaryMargin: const EdgeInsets.all(double.infinity),
                          onInteractionStart: (_) => _isPanning = true,
                          onInteractionEnd: (_) => _isPanning = false,
                          child: Container(
                            width: canvasWidth,
                            height: canvasHeight,
                            color: AppColors.background,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Edges
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _GraphEdgePainter(
                                      edges: visibleEdges,
                                      nodePositions: _nodePositions,
                                      selectedNode: _selectedNode,
                                      hoveredNode: _hoveredNode,
                                    ),
                                  ),
                                ),
                                // Nodes
                                ...visibleFiles.map((file) {
                                  final pos = _nodePositions[file.path] ?? Offset.zero;
                                  final type = _getFileType(file.path);
                                  final color = nodeTypeColors[type] ?? nodeTypeColors['other']!;
                                  final isSelected = _selectedNode == file.path;
                                  final isHovered = _hoveredNode == file.path;

                                  // Dim logic: dim when something is selected/hovered and this node isn't connected
                                  final activeNode = _selectedNode ?? _hoveredNode;
                                  final isActive = activeNode != null;
                                  final isConnectedToActive = isActive && _isConnected(file.path, activeNode, visibleEdges);
                                  final isDimmed = isActive && !isSelected && !isHovered && !isConnectedToActive;

                                  return Positioned(
                                    left: pos.dx,
                                    top: pos.dy,
                                    child: _GraphNode(
                                      file: file,
                                      color: color,
                                      isSelected: isSelected,
                                      isHovered: isHovered,
                                      isDimmed: isDimmed,
                                      edges: visibleEdges,
                                      allFiles: visibleFiles,
                                      projectPath: projectState.activeProject?.path ?? '',
                                      onSelect: () => setState(() {
                                        _selectedNode = _selectedNode == file.path ? null : file.path;
                                      }),
                                      onHover: (hovering) {
                                        if (_isPanning) return;
                                        setState(() => _hoveredNode = hovering ? file.path : null);
                                      },
                                      onDragStart: (globalPos) {
                                        _draggingPath = file.path;
                                        _dragStart = globalPos;
                                      },
                                      onDragUpdate: (globalPos) {
                                        if (_dragStart != null && _draggingPath == file.path) {
                                          final delta = globalPos - _dragStart!;
                                          final currentPos = _nodePositions[file.path] ?? Offset.zero;
                                          setState(() {
                                            _nodePositions[file.path] = Offset(currentPos.dx + delta.dx, currentPos.dy + delta.dy);
                                            _dragStart = globalPos;
                                          });
                                        }
                                      },
                                      onDragEnd: () {
                                        _dragStart = null;
                                        _draggingPath = null;
                                      },
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ),
                          ),
                        ),
                        // Zoom controls (bottom-right, above minimap)
                        Positioned(
                          right: 16,
                          bottom: 126,
                          child: Column(
                            children: [
                              _ZoomControlButton(
                                icon: Icons.add_rounded,
                                tooltip: 'Zoom In',
                                onTap: () => _stepZoom(1.25),
                              ),
                              const SizedBox(height: 4),
                              _ZoomControlButton(
                                icon: Icons.remove_rounded,
                                tooltip: 'Zoom Out',
                                onTap: () => _stepZoom(0.8),
                              ),
                              const SizedBox(height: 4),
                              _ZoomControlButton(
                                icon: Icons.fit_screen_rounded,
                                tooltip: 'Fit to View',
                                onTap: _fitToView,
                              ),
                            ],
                          ),
                        ),
                        // Minimap (bottom-right corner)
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: _Minimap(
                            canvasWidth: canvasWidth,
                            canvasHeight: canvasHeight,
                            nodePositions: _nodePositions,
                            visibleFiles: visibleFiles,
                            controller: _transformController,
                            viewportSize: viewportSize,
                          ),
                        ),
                        // Legend (bottom-left corner)
                        Positioned(
                          left: 16,
                          bottom: 16,
                          child: _Legend(visibleTypes: _visibleTypes),
                        ),
                      ],
                    );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  error: (error, _) => _buildErrorState(error),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (error, _) => _buildErrorState(error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(dynamic projectState) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text('No indexed files', style: AppTextStyles.body.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 8),
          Text('Select a project and tap Index Project', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              if (projectState.activeProject != null) {
                final engine = ref.read(indexingEngineProvider);
                try {
                  setState(() { _indexing = true; _indexProgress = 0.0; });
                  await engine.indexProject(
                    projectState.activeProject!.path,
                    onProgress: (current, total) => setState(() => _indexProgress = current / total),
                  );
                  ref.invalidate(indexedFilesProvider);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Indexing failed: $e'), backgroundColor: AppColors.surface),
                    );
                  }
                } finally {
                  setState(() => _indexing = false);
                }
              }
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Index Project'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_rounded, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text('Error: $error', style: AppTextStyles.body.copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }

  String _getFileType(String path) {
    final ext = p.extension(path).replaceFirst('.', '');
    final name = p.basename(path).toLowerCase();

    if (name.contains('test') || name.contains('spec')) return 'test';
    if (['component', 'screen', 'page', 'view', 'widget'].any((k) => name.contains(k))) return 'component';
    if (['service', 'repository', 'provider', 'notifier'].any((k) => name.contains(k))) return 'service';
    if (['util', 'helper', 'constant', 'extension'].any((k) => name.contains(k))) return 'util';
    if (['model', 'type', 'interface', 'schema'].any((k) => name.contains(k))) return 'model';
    if (['config', 'settings', 'env'].any((k) => name.contains(k))) return 'config';
    if (name == 'main.dart' || name == 'index' || name == 'app') return 'entry';

    switch (ext) {
      case 'dart': return 'component';
      case 'ts': case 'tsx': case 'js': case 'jsx': return 'component';
      case 'py': return 'service';
      case 'json': case 'yaml': case 'yml': case 'toml': return 'config';
      default: return 'other';
    }
  }

  bool _isConnected(String a, String b, List<Map<String, dynamic>> edges) {
    return edges.any((e) => (e['from'] == a && e['to'] == b) || (e['from'] == b && e['to'] == a));
  }

  void _initializePositions(List<IndexedFile> files, List<Map<String, dynamic>> edges) {
    // Layered (Sugiyama-style) layout — cards aligned in columns like Supabase
    const nodeWidth = 200.0;
    const nodeHeight = 80.0;
    const gapX = 80.0;
    const gapY = 40.0;

    // Build dependency adjacency: node -> set of nodes it depends on
    final byPath = {for (final f in files) f.path: f};
    final deps = <String, Set<String>>{};
    for (final f in files) {
      deps[f.path] = {};
    }
    for (final e in edges) {
      final from = e['from'] as String;
      final to = e['to'] as String;
      if (!byPath.containsKey(from) || !byPath.containsKey(to)) continue;
      deps[to]!.add(from);
    }

    // Layer = longest path from a source (cycle-safe)
    final layer = <String, int>{};
    final visiting = <String>{};
    int safeLayer(String path) {
      final cached = layer[path];
      if (cached != null) return cached;
      if (visiting.contains(path)) {
        layer[path] = 0;
        return 0;
      }
      visiting.add(path);
      var maxDep = -1;
      for (final dep in deps[path] ?? {}) {
        final d = safeLayer(dep);
        if (d > maxDep) maxDep = d;
      }
      visiting.remove(path);
      layer[path] = maxDep + 1;
      return maxDep + 1;
    }

    for (final f in files) {
      safeLayer(f.path);
    }

    // Group nodes by layer
    final layers = <int, List<String>>{};
    for (final f in files) {
      final l = layer[f.path] ?? 0;
      layers.putIfAbsent(l, () => []).add(f.path);
    }
    final maxLayer = layers.keys.reduce(math.max);

    // Order within each layer using barycenter of predecessors (reduces crossings)
    for (var l = 1; l <= maxLayer; l++) {
      final nodes = layers[l] ?? [];
      final prevLayer = layers[l - 1] ?? [];
      final prevIndex = {for (var i = 0; i < prevLayer.length; i++) prevLayer[i]: i.toDouble()};

      nodes.sort((a, b) {
        double barycenter(Set<String> depsSet) {
          var sum = 0.0;
          var count = 0;
          for (final d in depsSet) {
            final idx = prevIndex[d];
            if (idx != null) {
              sum += idx;
              count++;
            }
          }
          return count == 0 ? -1 : sum / count;
        }

        final ba = barycenter(deps[a] ?? {});
        final bb = barycenter(deps[b] ?? {});
        if (ba != bb) return ba.compareTo(bb);
        return p.basename(a).toLowerCase().compareTo(p.basename(b).toLowerCase());
      });
    }

    // Assign grid positions: x = column per layer, y = stacked rows
    final positions = <String, Offset>{};
    for (final entry in layers.entries) {
      final l = entry.key;
      final nodes = entry.value;
      final x = 100.0 + l * (nodeWidth + gapX);
      var y = 100.0;
      for (final node in nodes) {
        positions[node] = Offset(x, y);
        y += nodeHeight + gapY;
      }
    }

    _nodePositions.addAll(positions);
  }

  void _fitToView() {
    if (_nodePositions.isEmpty) return;
    double minX = double.infinity, minY = double.infinity;
    double maxX = 0, maxY = 0;
    for (final pos in _nodePositions.values) {
      if (pos.dx < minX) minX = pos.dx;
      if (pos.dy < minY) minY = pos.dy;
      if (pos.dx > maxX) maxX = pos.dx;
      if (pos.dy > maxY) maxY = pos.dy;
    }

    // Calculate the bounding box with padding
    final padding = 80.0;
    final contentWidth = maxX - minX + 400; // node width
    final contentHeight = maxY - minY + 150; // node height

    // Get viewport size from the actual viewer (not the full screen)
    final viewport = _viewerKey.currentContext?.size ?? context.size;
    if (viewport == null) return;

    final viewportWidth = viewport.width;
    final viewportHeight = viewport.height;

    // Calculate scale to fit
    final scaleX = (viewportWidth - padding * 2) / contentWidth;
    final scaleY = (viewportHeight - padding * 2) / contentHeight;
    final fitScale = math.min(scaleX, scaleY).clamp(0.1, 2.0);

    // Center the content
    final centerX = (minX + maxX) / 2;
    final centerY = (minY + maxY) / 2;
    final translateX = viewportWidth / 2 - centerX * fitScale;
    final translateY = viewportHeight / 2 - centerY * fitScale;

    _transformController.value = Matrix4.identity()
      ..translate(translateX, translateY)
      ..scale(fitScale);
  }

  void _resetLayout() {
    _transformController.value = Matrix4.identity();
    setState(() {
      _nodePositions.clear();
      _selectedNode = null;
      _hoveredNode = null;
      _initialFitDone = false;
    });
  }
}

// ==================== NODE WIDGET ====================

class _GraphNode extends StatefulWidget {
  final IndexedFile file;
  final Color color;
  final bool isSelected;
  final bool isHovered;
  final bool isDimmed;
  final List<Map<String, dynamic>> edges;
  final List<IndexedFile> allFiles;
  final String projectPath;
  final VoidCallback onSelect;
  final void Function(bool) onHover;
  final void Function(Offset) onDragStart;
  final void Function(Offset) onDragUpdate;
  final VoidCallback onDragEnd;

  const _GraphNode({
    required this.file,
    required this.color,
    required this.isSelected,
    required this.isHovered,
    required this.isDimmed,
    required this.edges,
    required this.allFiles,
    required this.projectPath,
    required this.onSelect,
    required this.onHover,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  State<_GraphNode> createState() => _GraphNodeState();
}

class _GraphNodeState extends State<_GraphNode> {
  @override
  Widget build(BuildContext context) {
    final fileName = p.basename(widget.file.path);
    final dirName = p.dirname(widget.file.path);
    final connectedFiles = <String>{};
    for (final edge in widget.edges) {
      if (edge['from'] == widget.file.path) {
        connectedFiles.add(p.basename(edge['to'] as String));
      }
      if (edge['to'] == widget.file.path) {
        connectedFiles.add(p.basename(edge['from'] as String));
      }
    }

    return MouseRegion(
      onEnter: (_) => widget.onHover(true),
      onExit: (_) => widget.onHover(false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onSelect,
        onPanStart: (d) => widget.onDragStart(d.globalPosition),
        onPanUpdate: (d) => widget.onDragUpdate(d.globalPosition),
        onPanEnd: (_) => widget.onDragEnd(),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: widget.isDimmed ? 0.2 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 200,
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? widget.color.withValues(alpha: 0.15)
                  : widget.isHovered
                      ? AppColors.surfaceHover
                      : AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.isSelected
                    ? widget.color
                    : widget.isHovered
                        ? widget.color.withValues(alpha: 0.5)
                        : AppColors.border,
                width: widget.isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.isSelected
                      ? widget.color.withValues(alpha: 0.3)
                      : widget.isHovered
                          ? widget.color.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.1),
                  blurRadius: widget.isSelected ? 12 : 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with type color indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fileName,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                overflow: TextOverflow.ellipsis),
                            if (dirName != '.' && dirName.isNotEmpty)
                              Text(dirName,
                                  style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
                                  overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      if (widget.isHovered || widget.isSelected)
                        Icon(Icons.open_in_new_rounded, size: 12, color: widget.color),
                    ],
                  ),
                ),
                // Connected files
                if (connectedFiles.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: connectedFiles.take(3).map((name) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(
                            children: [
                              Container(width: 6, height: 6, decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(1))),
                              const SizedBox(width: 6),
                              Expanded(child: Text(name, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== EDGE PAINTER ====================

class _GraphEdgePainter extends CustomPainter {
  final List<Map<String, dynamic>> edges;
  final Map<String, Offset> nodePositions;
  final String? selectedNode;
  final String? hoveredNode;

  static const double nodeWidth = 200.0;
  static const double nodeHeight = 80.0;

  _GraphEdgePainter({
    required this.edges,
    required this.nodePositions,
    this.selectedNode,
    this.hoveredNode,
  });

  /// True if the straight segment (p1 -> p2) intersects any node rect
  /// other than the two edge endpoints.
  bool _segmentHits(Offset p1, Offset p2, String fromPath, String toPath) {
    final segMinX = math.min(p1.dx, p2.dx);
    final segMaxX = math.max(p1.dx, p2.dx);
    final segMinY = math.min(p1.dy, p2.dy);
    final segMaxY = math.max(p1.dy, p2.dy);

    for (final entry in nodePositions.entries) {
      if (entry.key == fromPath || entry.key == toPath) continue;
      final pos = entry.value;
      final inset = 2.0;
      final nx = pos.dx + inset;
      final ny = pos.dy + inset;
      final nw = nodeWidth - inset * 2;
      final nh = nodeHeight - inset * 2;
      if (segMaxX > nx && segMinX < nx + nw && segMaxY > ny && segMinY < ny + nh) {
        return true;
      }
    }
    return false;
  }

  /// Build an orthogonal (elbow) path from source right edge to target left
  /// edge. Straight when clear; otherwise route through a vertical lane that
  /// avoids any card blocking the way (Supabase-style squarish routing).
  /// Searches both left and right of the midpoint, never racing off-canvas.
  List<Offset> _orthogonalRoute(Offset start, Offset end, String fromPath, String toPath) {
    // Straight line when nothing is in the way and rows align
    if ((start.dy - end.dy).abs() < 0.5 && !_segmentHits(start, end, fromPath, toPath)) {
      return [start, end];
    }

    // Route with elbows through a vertical lane.
    // Try the midpoint first, then alternate left/right, capped so lines
    // never shoot off toward infinity.
    final midX0 = (start.dx + end.dx) / 2;
    final startX = start.dx;
    final endX = end.dx;
    // Same column (same-layer edge): push the lane outward from the source.
    final baseX = (endX - startX).abs() < 1.0 ? startX + 60 : midX0;

    const step = 40.0;
    const maxAttempts = 24;
    var found = false;
    var midX = baseX;
    for (var i = 0; i < maxAttempts && !found; i++) {
      // Alternate sides: 0, -1, +1, -2, +2, ... around the base lane
      final side = (i % 2 == 0 ? 1 : -1);
      final distance = ((i + 1) ~/ 2) * step;
      midX = baseX + side * distance;

      // Never route further than the target column's edge — lines that
      // overshoot past the target look broken.
      final lowerBound = math.min(startX, endX) - nodeWidth;
      final upperBound = math.max(startX, endX) + nodeWidth;
      if (midX < lowerBound || midX > upperBound) continue;

      final p2 = Offset(midX, start.dy);
      final p3 = Offset(midX, end.dy);
      if (!_segmentHits(start, p2, fromPath, toPath) &&
          !_segmentHits(p2, p3, fromPath, toPath) &&
          !_segmentHits(p3, end, fromPath, toPath)) {
        found = true;
      }
    }
    return [start, Offset(midX, start.dy), Offset(midX, end.dy), end];
  }

  /// Classify an edge by its dominant direction so overlapping lines stay
  /// visually distinguishable.
  String _edgeDirection(Offset start, Offset end) {
    final dx = end.dx - start.dx;
    if (dx.abs() < 1.0) return 'vertical'; // same layer, up/down jog
    if (dx > 0) return 'forward'; // left → right (dependency flow)
    return 'backward'; // right → left (back-edge / cycle)
  }

  @override
  void paint(Canvas canvas, Size size) {
    final forwardPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.55)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final backwardPaint = Paint()
      ..color = AppColors.warning.withValues(alpha: 0.4)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final verticalPaint = Paint()
      ..color = AppColors.info.withValues(alpha: 0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final highlightPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final dimPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.15)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Precompute per-edge geometry and classification so we can draw in
    // layers: backward and vertical edges first (underneath), then the
    // main forward dependency flow on top.
    final paths = <({Path path, Offset end, double arrowAngle, String direction, String fromPath, String toPath})>[];
    for (final edge in edges) {
      final fromPath = edge['from'] as String;
      final toPath = edge['to'] as String;
      final fromPos = nodePositions[fromPath];
      final toPos = nodePositions[toPath];
      if (fromPos == null || toPos == null) continue;

      final start = Offset(fromPos.dx + nodeWidth, fromPos.dy + nodeHeight / 2);
      final end = Offset(toPos.dx, toPos.dy + nodeHeight / 2);

      final points = _orthogonalRoute(start, end, fromPath, toPath);

      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final pt in points.skip(1)) {
        path.lineTo(pt.dx, pt.dy);
      }

      // Arrow points along the final approach segment (last two points).
      final last = points[points.length - 1];
      final prev = points[points.length - 2];

      paths.add((
        path: path,
        end: end,
        arrowAngle: (last - prev).direction,
        direction: _edgeDirection(start, end),
        fromPath: fromPath,
        toPath: toPath,
      ));
    }

    // Layer order: vertical jogs → backward edges → forward edges on top.
    for (final layer in ['vertical', 'backward', 'forward']) {
      for (final entry in paths.where((e) => e.direction == layer)) {
        final basePaint = switch (layer) {
          'backward' => backwardPaint,
          'vertical' => verticalPaint,
          _ => forwardPaint,
        };
        _drawEdge(canvas, entry.path, entry.end, entry.arrowAngle, entry.fromPath, entry.toPath,
            basePaint, highlightPaint, dimPaint);
      }
    }
  }

  void _drawEdge(
    Canvas canvas,
    Path path,
    Offset end,
    double arrowAngle,
    String fromPath,
    String toPath,
    Paint basePaint,
    Paint highlightPaint,
    Paint dimPaint,
  ) {
    final activeNode = selectedNode ?? hoveredNode;
    final isActive = activeNode != null;
    final isConnectedToActive = isActive && (fromPath == activeNode || toPath == activeNode);

    final paint = isConnectedToActive
        ? highlightPaint
        : isActive
            ? dimPaint
            : basePaint;

    canvas.drawPath(path, paint);

    // Arrowhead along the final segment direction
    final arrowPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;

    final arrowSize = 5.0;
    final arrowPath = Path();
    arrowPath.moveTo(end.dx, end.dy);
    arrowPath.lineTo(
      end.dx - arrowSize * math.cos(arrowAngle - 0.5),
      end.dy - arrowSize * math.sin(arrowAngle - 0.5),
    );
    arrowPath.lineTo(
      end.dx - arrowSize * math.cos(arrowAngle + 0.5),
      end.dy - arrowSize * math.sin(arrowAngle + 0.5),
    );
    arrowPath.close();
    canvas.drawPath(arrowPath, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant _GraphEdgePainter oldDelegate) {
    return oldDelegate.selectedNode != selectedNode ||
        oldDelegate.hoveredNode != hoveredNode ||
        oldDelegate.nodePositions != nodePositions;
  }
}

// ==================== MINIMAP ====================

class _Minimap extends StatelessWidget {
  final double canvasWidth;
  final double canvasHeight;
  final Map<String, Offset> nodePositions;
  final List<IndexedFile> visibleFiles;
  final TransformationController controller;
  final Size viewportSize;

  const _Minimap({
    required this.canvasWidth,
    required this.canvasHeight,
    required this.nodePositions,
    required this.visibleFiles,
    required this.controller,
    required this.viewportSize,
  });

  @override
  Widget build(BuildContext context) {
    const minimapWidth = 160.0;
    const minimapHeight = 100.0;
    final scaleX = minimapWidth / canvasWidth.clamp(1.0, double.infinity);
    final scaleY = minimapHeight / canvasHeight.clamp(1.0, double.infinity);
    final minimapScale = math.min(scaleX, scaleY);

    // Only the minimap repaints on pan/zoom — no full-screen rebuilds
    return ValueListenableBuilder<Matrix4>(
      valueListenable: controller,
      builder: (context, matrix, _) {
        final viewScale = matrix.getMaxScaleOnAxis();
        final translation = matrix.getTranslation();
        final viewOffset = Offset(translation.x, translation.y);
        return Container(
          width: minimapWidth,
          height: minimapHeight,
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CustomPaint(
              painter: _MinimapPainter(
                nodePositions: nodePositions,
                files: visibleFiles,
                scale: minimapScale,
                viewScale: viewScale,
                viewOffset: viewOffset,
                viewportSize: viewportSize,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MinimapPainter extends CustomPainter {
  final Map<String, Offset> nodePositions;
  final List<IndexedFile> files;
  final double scale;
  final double viewScale;
  final Offset viewOffset;
  final Size viewportSize;

  _MinimapPainter({
    required this.nodePositions,
    required this.files,
    required this.scale,
    required this.viewScale,
    required this.viewOffset,
    required this.viewportSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..style = PaintingStyle.fill;

    for (final file in files) {
      final pos = nodePositions[file.path];
      if (pos == null) continue;
      dotPaint.color = AppColors.primary.withValues(alpha: 0.6);
      canvas.drawCircle(Offset(pos.dx * scale, pos.dy * scale), 2, dotPaint);
    }

    // Draw the visible viewport rectangle
    final rectPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = AppColors.primary.withValues(alpha: 0.9);

    // Convert viewport screen bounds to canvas world coords: world = (screen - offset) / scale
    final leftWorld = (0 - viewOffset.dx) / viewScale;
    final topWorld = (0 - viewOffset.dy) / viewScale;
    final rightWorld = (viewportSize.width - viewOffset.dx) / viewScale;
    final bottomWorld = (viewportSize.height - viewOffset.dy) / viewScale;

    final rect = Rect.fromLTRB(
      (leftWorld * scale).clamp(0, size.width),
      (topWorld * scale).clamp(0, size.height),
      (rightWorld * scale).clamp(0, size.width),
      (bottomWorld * scale).clamp(0, size.height),
    );
    canvas.drawRect(rect, rectPaint);
  }

  @override
  bool shouldRepaint(covariant _MinimapPainter oldDelegate) {
    return oldDelegate.viewScale != viewScale ||
        oldDelegate.viewOffset != viewOffset ||
        oldDelegate.viewportSize != viewportSize;
  }
}

// ==================== LEGEND ====================

class _Legend extends StatelessWidget {
  final Set<String> visibleTypes;

  const _Legend({required this.visibleTypes});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Node Types', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          ...nodeTypeColors.entries.where((e) => visibleTypes.contains(e.key)).map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: entry.value, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(nodeTypeLabels[entry.key] ?? entry.key, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          const Text('Edge Types', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          _LegendEdge(color: AppColors.border.withValues(alpha: 0.55), label: 'Dependency flow'),
          _LegendEdge(color: AppColors.warning.withValues(alpha: 0.4), label: 'Back-edge / cycle'),
          _LegendEdge(color: AppColors.info.withValues(alpha: 0.3), label: 'Vertical link'),
        ],
      ),
    );
  }
}

class _LegendEdge extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendEdge({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 0,
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: color, width: 2))),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ==================== CONTROL BUTTON ====================

class _ControlButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ControlButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  State<_ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _isHovered ? AppColors.surfaceHover : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(widget.icon, size: 18, color: _isHovered ? AppColors.primary : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _ZoomControlButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ZoomControlButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  State<_ZoomControlButton> createState() => _ZoomControlButtonState();
}

class _ZoomControlButtonState extends State<_ZoomControlButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: _isHovered ? 0.95 : 0.85),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _isHovered ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(widget.icon, size: 18, color: _isHovered ? AppColors.primary : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

// ==================== FILTER DROPDOWN ====================

class _FilterDropdown extends StatefulWidget {
  final Set<String> visibleTypes;
  final Function(String, bool) onToggle;
  final VoidCallback onSelectAll;
  final VoidCallback onClearAll;

  const _FilterDropdown({
    required this.visibleTypes,
    required this.onToggle,
    required this.onSelectAll,
    required this.onClearAll,
  });

  @override
  State<_FilterDropdown> createState() => _FilterDropdownState();
}

class _FilterDropdownState extends State<_FilterDropdown> {
  bool _isOpen = false;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  void _toggle() {
    if (_isOpen) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    _overlayEntry = _createOverlay();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _close() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() => _isOpen = false);
  }

  OverlayEntry _createOverlay() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: 220,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        const Text('Filter by Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            widget.onSelectAll();
                            _close();
                          },
                          child: const Text('All', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            widget.onClearAll();
                            _close();
                          },
                          child: const Text('None', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Checkboxes
                  ...nodeTypeColors.entries.map((entry) {
                    final isVisible = widget.visibleTypes.contains(entry.key);
                    return InkWell(
                      onTap: () => widget.onToggle(entry.key, !isVisible),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: isVisible ? entry.value : Colors.transparent,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: isVisible ? entry.value : AppColors.textMuted,
                                  width: 1.5,
                                ),
                              ),
                              child: isVisible
                                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: entry.value, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              nodeTypeLabels[entry.key] ?? entry.key,
                              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggle,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _isOpen ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surfaceHover,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _isOpen ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.filter_list_rounded, size: 14, color: _isOpen ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                'Types (${widget.visibleTypes.length}/${nodeTypeColors.length})',
                style: TextStyle(fontSize: 11, color: _isOpen ? AppColors.primary : AppColors.textSecondary),
              ),
              const SizedBox(width: 4),
              Icon(
                _isOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                size: 14,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== VIEW TOGGLE BUTTON ====================

class _ViewToggleButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

  const _ViewToggleButton({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_ViewToggleButton> createState() => _ViewToggleButtonState();
}

class _ViewToggleButtonState extends State<_ViewToggleButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: widget.isActive
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : _isHovered
                      ? AppColors.surfaceHover
                      : Colors.transparent,
            ),
            child: Icon(
              widget.icon,
              size: 16,
              color: widget.isActive ? AppColors.primary : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== GRID VIEW ====================

class _GridView extends StatelessWidget {
  final List<IndexedFile> files;
  final List<Map<String, dynamic>> edges;
  final String Function(String) getFileType;
  final String projectPath;
  final Function(String) onFileTap;

  const _GridView({
    required this.files,
    required this.edges,
    required this.getFileType,
    required this.projectPath,
    required this.onFileTap,
  });

  @override
  Widget build(BuildContext context) {
    // Sort files: by type group order, then alphabetically by name
    final sortedFiles = List<IndexedFile>.from(files)..sort((a, b) {
      final typeA = getFileType(a.path);
      final typeB = getFileType(b.path);
      final typeOrder = nodeTypeLabels.keys.toList().indexOf(typeA);
      final typeOrderB = nodeTypeLabels.keys.toList().indexOf(typeB);
      if (typeOrder != typeOrderB) return typeOrder.compareTo(typeOrderB);
      return p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase());
    });

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Stats row
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Text(
                  '${sortedFiles.length} files',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const Spacer(),
                // Sort options could go here
              ],
            ),
          ),
          // Grid
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 280,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
              ),
              itemCount: sortedFiles.length,
              itemBuilder: (context, index) {
                final file = sortedFiles[index];
                final type = getFileType(file.path);
                final color = nodeTypeColors[type] ?? nodeTypeColors['other']!;
                final fileName = p.basename(file.path);
                final dirName = p.dirname(file.path);

                // Find connected files
                final connectedFiles = <String>{};
                for (final edge in edges) {
                  if (edge['from'] == file.path) {
                    connectedFiles.add(p.basename(edge['to'] as String));
                  }
                  if (edge['to'] == file.path) {
                    connectedFiles.add(p.basename(edge['from'] as String));
                  }
                }

                return _GridCard(
                  fileName: fileName,
                  dirName: dirName,
                  type: type,
                  color: color,
                  connectedCount: connectedFiles.length,
                  connectedNames: connectedFiles.take(3).toList(),
                  loc: file.loc,
                  onTap: () => onFileTap(file.path),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GridCard extends StatefulWidget {
  final String fileName;
  final String dirName;
  final String type;
  final Color color;
  final int connectedCount;
  final List<String> connectedNames;
  final int loc;
  final VoidCallback onTap;

  const _GridCard({
    required this.fileName,
    required this.dirName,
    required this.type,
    required this.color,
    required this.connectedCount,
    required this.connectedNames,
    required this.loc,
    required this.onTap,
  });

  @override
  State<_GridCard> createState() => _GridCardState();
}

class _GridCardState extends State<_GridCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.surfaceHover : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isHovered ? widget.color.withValues(alpha: 0.5) : AppColors.border,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? widget.color.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: _isHovered ? 8 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.fileName,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.dirName != '.' && widget.dirName.isNotEmpty)
                            Text(
                              widget.dirName,
                              style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type badge + LOC
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: widget.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              nodeTypeLabels[widget.type] ?? widget.type,
                              style: TextStyle(fontSize: 9, color: widget.color, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Spacer(),
                          if (widget.loc > 0)
                            Text(
                              '${widget.loc} lines',
                              style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
                            ),
                        ],
                      ),
                      const Spacer(),
                      // Connected files
                      if (widget.connectedNames.isNotEmpty)
                        ...widget.connectedNames.map((name) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              children: [
                                Icon(Icons.arrow_right_rounded, size: 12, color: widget.color.withValues(alpha: 0.5)),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      if (widget.connectedCount > 3)
                        Text(
                          '+${widget.connectedCount - 3} more',
                          style: TextStyle(fontSize: 9, color: widget.color),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension IndexedFileListExtension on List<IndexedFile> {
  IndexedFile? firstWhereOrNull(bool Function(IndexedFile) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
