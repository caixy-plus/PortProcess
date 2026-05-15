import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../models/process_info.dart';
import '../services/process_service.dart';
import '../widgets/tab_hit/tab_hit.dart';
import '../widgets/tab_hit/keyword_matcher.dart';
import '../widgets/window_title_bar/window_title_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WindowListener {
  final ProcessService _processService = ProcessService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<ProcessInfo> _allProcesses = [];
  List<ProcessInfo> _filteredProcesses = [];
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;
  Timer? _searchDebounceTimer;
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initWindow();
    _loadProcesses();
    _startAutoRefresh();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _initWindow() async {
    await windowManager.ensureInitialized();
    await windowManager.setTitle('Port Process');
    await windowManager.setMinimumSize(const Size(800, 500));
    final maximized = await windowManager.isMaximized();
    if (mounted) setState(() => _isMaximized = maximized);
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _isMaximized = false);
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _loadProcesses();
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _refreshTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadProcesses() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final processes = await _processService.getListeningProcesses();
      if (!mounted) return;
      setState(() {
        _allProcesses = processes..sort((a, b) => b.port.compareTo(a.port));
        _applySearchFilter();
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _onSearchChanged() {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) _applySearchFilter();
    });
  }

  void _applySearchFilter() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredProcesses = List.from(_allProcesses));
      return;
    }
    setState(() {
      _filteredProcesses = _allProcesses.where((p) {
        return p.port.toString().contains(query) ||
            p.pid.toString().contains(query) ||
            (p.name?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  Future<void> _killProcess(ProcessInfo process) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Kill'),
        content: Text('Kill process ${process.name ?? process.pid} (PID: ${process.pid}, Port: ${process.port})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Kill'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final error = await _processService.killProcess(process.pid);
    if (!mounted) return;

    if (error.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Process ${process.pid} killed'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      _loadProcesses();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        color: theme.colorScheme.surface,
        child: Column(
          children: [
            WindowTitleBar(
              title: 'Port Process',
              leading: Icon(
                Icons.settings_ethernet,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              isMaximized: _isMaximized,
              onDragStart: windowManager.startDragging,
              onDoubleTap: () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
              onMinimize: windowManager.minimize,
              onMaximize: () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
              onClose: windowManager.close,
            ),
            _buildSearchBar(theme),
            Expanded(
              child: _isLoading && _allProcesses.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text('Error: $_error'))
                      : _buildProcessList(theme, isDark),
            ),
            _buildStatusBar(theme, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TabHit(
              controller: _searchController,
              focusNode: _searchFocusNode,
              matcher: KeywordHitMatcher(
                keywords: const [
                  'java',
                  'node',
                  'python',
                  'docker',
                  'nginx',
                  'mysql',
                  'redis',
                  'postgres',
                  'mongodb',
                  '8080',
                  '3000',
                  '3306',
                  '5432',
                  '6379',
                  '27017',
                  '80',
                  '443',
                  '22',
                  '80443',
                ],
                caseSensitive: false,
              ),
              hintText: 'Search by port, PID, or name...',
              onChanged: (_) => _onSearchChanged(),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _searchFocusNode.requestFocus();
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh',
            onPressed: _loadProcesses,
          ),
        ],
      ),
    );
  }

  Widget _buildProcessList(ThemeData theme, bool isDark) {
    if (_filteredProcesses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty
                  ? 'No listening processes found'
                  : 'No results found',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: true),
      child: ListView.separated(
        itemCount: _filteredProcesses.length,
        padding: const EdgeInsets.symmetric(vertical: 4),
        separatorBuilder: (_, __) => Divider(
          height: 1,
          indent: 16,
          endIndent: 16,
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
        ),
        itemBuilder: (context, index) {
          final process = _filteredProcesses[index];
          return _ProcessListTile(
            process: process,
            isDark: isDark,
            onKill: () => _killProcess(process),
          );
        },
      ),
    );
  }

  Widget _buildStatusBar(ThemeData theme, bool isDark) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            '${_filteredProcesses.length} process${_filteredProcesses.length != 1 ? 'es' : ''}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          if (_isLoading)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}

class _ProcessListTile extends StatefulWidget {
  final ProcessInfo process;
  final bool isDark;
  final VoidCallback onKill;

  const _ProcessListTile({
    required this.process,
    required this.isDark,
    required this.onKill,
  });

  @override
  State<_ProcessListTile> createState() => _ProcessListTileState();
}

class _ProcessListTileState extends State<_ProcessListTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final process = widget.process;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: _isHovered
            ? theme.colorScheme.primaryContainer.withOpacity(0.2)
            : Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.4),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(
                  process.protocol,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    process.name ?? 'Unknown',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    process.address ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildInfoChip(
                theme,
                'PID',
                process.pid.toString(),
              ),
            ),
            Expanded(
              child: _buildInfoChip(
                theme,
                'Port',
                process.port.toString(),
                isHighlight: true,
              ),
            ),
            SizedBox(
              width: 80,
              child: AnimatedOpacity(
                opacity: _isHovered ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 150),
                child: FilledButton.icon(
                  onPressed: widget.onKill,
                  icon: const Icon(Icons.close, size: 14),
                  label: const Text('Kill'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.9),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    textStyle: theme.textTheme.labelSmall,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(ThemeData theme, String label, String value, {bool isHighlight = false}) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: isHighlight ? theme.colorScheme.primary : null,
            fontFamily: 'monospace',
            fontFamilyFallback: const ['Courier', 'monospace'],
          ),
        ),
      ],
    );
  }
}

