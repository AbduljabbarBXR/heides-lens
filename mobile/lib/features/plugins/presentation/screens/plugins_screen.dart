import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spikey/shared/themes/app_colors.dart';
import 'package:spikey/core/services/plugin_marketplace.dart';

class PluginsScreen extends ConsumerStatefulWidget {
  const PluginsScreen({super.key});

  @override
  ConsumerState<PluginsScreen> createState() => _PluginsScreenState();
}

class _PluginsScreenState extends ConsumerState<PluginsScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'all';
  final PluginMarketplace _marketplace = PluginMarketplace();
  List<Map<String, dynamic>> _allPlugins = [];
  List<Map<String, dynamic>> _filteredPlugins = [];
  bool _isLoading = true;
  final Set<String> _installedPlugins = {};

  @override
  void initState() {
    super.initState();
    _loadPlugins();
  }

  Future<void> _loadPlugins() async {
    setState(() => _isLoading = true);
    final plugins = await _marketplace.getAllPlugins();
    if (mounted) {
      setState(() {
        _allPlugins = plugins;
        _filteredPlugins = plugins;
        _isLoading = false;
      });
    }
  }

  void _filterPlugins() {
    setState(() {
      _filteredPlugins = _allPlugins.where((plugin) {
        final matchesSearch = _searchQuery.isEmpty ||
            (plugin['name']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
            (plugin['description']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
        final matchesCategory = _selectedCategory == 'all' ||
            (plugin['category'] as List?)?.contains(_selectedCategory) == true;
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  void _installPlugin(Map<String, dynamic> plugin) {
    final id = plugin['id'] ?? plugin['name'];
    setState(() {
      if (_installedPlugins.contains(id)) {
        _installedPlugins.remove(id);
      } else {
        _installedPlugins.add(id);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _installedPlugins.contains(id)
              ? 'Installed ${plugin['name']}'
              : 'Removed ${plugin['name']}',
        ),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['all', 'security', 'analysis', 'performance', 'style'];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.extension_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text('Plugins', style: AppTextStyles.h3),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHover,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text('${_filteredPlugins.length} available', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Search bar
                TextField(
                  onChanged: (query) {
                    _searchQuery = query;
                    _filterPlugins();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search plugins...',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textMuted),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                // Category chips
                Wrap(
                  spacing: 8,
                  children: categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return FilterChip(
                      label: Text(cat == 'all' ? 'All' : cat[0].toUpperCase() + cat.substring(1)),
                      selected: isSelected,
                      onSelected: (_) {
                        _selectedCategory = cat;
                        _filterPlugins();
                      },
                      backgroundColor: AppColors.surfaceHover,
                      selectedColor: AppColors.primary,
                      checkmarkColor: AppColors.background,
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.background : AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          // Plugin list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _filteredPlugins.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 16),
                            Text('No plugins found', style: AppTextStyles.body.copyWith(color: AppColors.textMuted)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredPlugins.length,
                        itemBuilder: (context, index) {
                          final plugin = _filteredPlugins[index];
                          return _PluginCard(
                            plugin: plugin,
                            index: index,
                            isInstalled: _installedPlugins.contains(plugin['id'] ?? plugin['name']),
                            onInstall: () => _installPlugin(plugin),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _PluginCard extends StatefulWidget {
  final Map<String, dynamic> plugin;
  final int index;
  final bool isInstalled;
  final VoidCallback onInstall;

  const _PluginCard({required this.plugin, required this.index, required this.isInstalled, required this.onInstall});

  @override
  State<_PluginCard> createState() => _PluginCardState();
}

class _PluginCardState extends State<_PluginCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    Future.delayed(Duration(milliseconds: widget.index * 60), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isHovered ? AppColors.surfaceHover : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _isHovered ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.extension_rounded, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.plugin['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14)),
                          Text('v${widget.plugin['version'] ?? '1.0.0'}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                    if (widget.plugin['rating'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.star_rounded, size: 14, color: AppColors.warning),
                            const SizedBox(width: 4),
                            Text('${widget.plugin['rating']}', style: const TextStyle(color: AppColors.warning, fontSize: 12)),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(widget.plugin['description'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (widget.plugin['downloads'] != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Row(
                          children: [
                            Icon(Icons.download_rounded, size: 14, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text('${widget.plugin['downloads']}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                    if (widget.plugin['category'] != null)
                      Wrap(
                        spacing: 6,
                        children: (widget.plugin['category'] as List).map((cat) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(cat, style: const TextStyle(color: AppColors.primary, fontSize: 11)),
                          );
                        }).toList(),
                      ),
                    const Spacer(),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: widget.isInstalled
                          ? OutlinedButton.icon(
                              key: const ValueKey('installed'),
                              onPressed: widget.onInstall,
                              icon: const Icon(Icons.check_rounded, size: 16),
                              label: const Text('Installed', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.success,
                                side: const BorderSide(color: AppColors.success),
                              ),
                            )
                          : ElevatedButton.icon(
                              key: const ValueKey('install'),
                              onPressed: widget.onInstall,
                              icon: const Icon(Icons.download_rounded, size: 16),
                              label: const Text('Install', style: TextStyle(fontSize: 12)),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
