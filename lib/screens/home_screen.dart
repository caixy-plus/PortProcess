import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../models/process_info.dart';
import '../services/process_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ProcessService _processService = ProcessService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<ProcessInfo> _allProcesses = [];
  List<ProcessInfo> _filteredProcesses = [];
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initWindow();
    _loadProcesses();
    _startAutoRefresh();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _initWindow() async {
    await windowManager.ensureInitialized();
    await windowManager.setTitle('Port Manager');
    await windowManager.setMinimumSize(const Size(800, 500));
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _loadProcesses();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
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
        _onSearchChanged();
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

    final success = await _processService.killProcess(process.pid);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Process ${process.pid} killed successfully'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      _loadProcesses();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to kill process'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
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
            _buildTitleBar(theme, isDark),
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

  Widget _buildTitleBar(ThemeData theme, bool isDark) {
    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: () async {
        if (await windowManager.isMaximized()) {
          windowManager.unmaximize();
        } else {
          windowManager.maximize();
        }
      },
      child: Container(
        height: 40,
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(Icons.settings_ethernet, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Port Manager',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            _buildWindowButton(
              icon: Icons.remove,
              onPressed: () => windowManager.minimize(),
            ),
            _buildWindowButton(
              icon: Icons.crop_square,
              onPressed: () async {
                if (await windowManager.isMaximized()) {
                  windowManager.unmaximize();
                } else {
                  windowManager.maximize();
                }
              },
            ),
            _buildWindowButton(
              icon: Icons.close,
              onPressed: () => windowManager.close(),
              hoverColor: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWindowButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color? hoverColor,
  }) {
    return SizedBox(
      width: 40,
      height: 40,
      child: InkWell(
        onTap: onPressed,
        hoverColor: hoverColor?.withOpacity(0.8) ?? Colors.white.withOpacity(0.1),
        child: Icon(icon, size: 16),
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
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search by port, PID, or name...',
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
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (_) => _onSearchChanged(),
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
                borderRadius: BorderRadius.circular(8),
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
