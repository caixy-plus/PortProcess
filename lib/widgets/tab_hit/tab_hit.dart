import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'hit_matcher.dart';

/// An AI-coding-style smart-completion input widget driven by a [HitMatcher].
///
/// ## Interaction
/// - As you type, a **grey ghost text** appears inline after the caret,
///   showing the top (shortest) suggestion.
/// - Press **Tab** to accept the current suggestion.
/// - When multiple suggestions exist, a dropdown list opens automatically;
///   use **ArrowDown / ArrowUp** to cycle and **Tab** to confirm.
/// - Press **Escape** to close the dropdown.
///
/// Designed to be extracted into a standalone package later.
class TabHit extends StatefulWidget {
  const TabHit({
    super.key,
    required this.matcher,
    this.hintText,
    this.onChanged,
    this.onTabCompleted,
    this.controller,
    this.focusNode,
    this.decoration,
    this.style,
    this.cursorColor,
    this.suggestionMaxHeight = 200.0,
    this.suggestionItemHeight = 40.0,
    this.suggestionItemPadding = const EdgeInsets.symmetric(horizontal: 12),
  });

  final HitMatcher matcher;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onTabCompleted;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextStyle? style;
  final Color? cursorColor;
  final double suggestionMaxHeight;
  final double suggestionItemHeight;
  final EdgeInsetsGeometry suggestionItemPadding;

  @override
  State<TabHit> createState() => _TabHitState();
}

class _TabHitState extends State<TabHit> {
  late final TextEditingController _controller;
  late final FocusNode _parentFocusNode;
  late final FocusNode _textFieldFocusNode;
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _textFieldKey = GlobalKey();

  List<String> _suggestions = const [];
  int _selectedIndex = 0;
  String? _ghostText;
  OverlayEntry? _overlayEntry;

  bool get _hasExternalController => widget.controller != null;
  bool get _hasExternalFocusNode => widget.focusNode != null;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _parentFocusNode = FocusNode();
    _textFieldFocusNode = widget.focusNode ?? FocusNode();
    _textFieldFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _hideOverlay();
    _textFieldFocusNode.removeListener(_onFocusChange);
    _parentFocusNode.dispose();
    if (!_hasExternalFocusNode) _textFieldFocusNode.dispose();
    if (!_hasExternalController) _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_textFieldFocusNode.hasFocus) _hideOverlay();
  }

  void _updateSuggestions() {
    final text = _controller.text;
    final suggestions = widget.matcher.match(text);

    String? ghost;
    if (suggestions.isNotEmpty && text.isNotEmpty) {
      final first = suggestions[0];
      if (first.startsWith(text)) {
        ghost = first.substring(text.length);
      }
    }

    setState(() {
      _suggestions = suggestions;
      _selectedIndex = 0;
      _ghostText = ghost;
    });

    // Only keep overlay open if it was already open (user pressed arrow keys).
    if (suggestions.isEmpty) {
      _hideOverlay();
    }
  }

  void _completeWith(int index) {
    if (_suggestions.isEmpty || index < 0 || index >= _suggestions.length) {
      return;
    }
    final value = _suggestions[index];
    _controller.text = value;
    _controller.selection = TextSelection.collapsed(offset: value.length);
    widget.onTabCompleted?.call(value);
    _hideOverlay();
    _updateSuggestions();
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => _buildDropdown(),
    );
    overlay.insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.tab) {
      if (_suggestions.isNotEmpty) {
        _completeWith(_selectedIndex);
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_suggestions.length > 1) {
        _showOverlay();
        setState(() {
          _selectedIndex = (_selectedIndex + 1) % _suggestions.length;
        });
        _overlayEntry?.markNeedsBuild();
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_suggestions.length > 1) {
        _showOverlay();
        setState(() {
          _selectedIndex =
              (_selectedIndex - 1 + _suggestions.length) % _suggestions.length;
        });
        _overlayEntry?.markNeedsBuild();
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _hideOverlay();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  double _measureTextWidth(String text, TextStyle? style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    return painter.width;
  }

  EdgeInsets _contentPadding(BuildContext context) {
    final decoration = widget.decoration;
    if (decoration?.contentPadding != null) {
      return decoration!.contentPadding! as EdgeInsets;
    }
    final isDense = decoration?.isDense ?? false;
    final isCollapsed = decoration?.isCollapsed ?? false;
    if (isCollapsed) return EdgeInsets.zero;
    if (isDense) {
      return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    }
    return const EdgeInsets.symmetric(horizontal: 12, vertical: 12);
  }

  double _prefixWidth() {
    if (widget.decoration?.prefixIcon != null) return 48;
    if (widget.decoration?.prefix != null) return 48;
    return 0;
  }

  Widget _buildDropdown() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return CompositedTransformFollower(
      link: _layerLink,
      showWhenUnlinked: false,
      offset: const Offset(0, 4),
      child: SizedBox(
        width: _layerLink.leaderSize?.width ?? 0,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(4),
          color: theme.colorScheme.surfaceContainerHighest,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: widget.suggestionMaxHeight,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    '\u2191 \u2193 to select',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    itemBuilder: (context, index) {
                      final isSelected = index == _selectedIndex;
                      return _SuggestionItem(
                        text: _suggestions[index],
                        isSelected: isSelected,
                        isDark: isDark,
                        theme: theme,
                        height: widget.suggestionItemHeight,
                        padding: widget.suggestionItemPadding,
                        onTap: () => _completeWith(index),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGhostText(TextStyle? textStyle) {
    if (_ghostText == null || _ghostText!.isEmpty) {
      return const SizedBox.shrink();
    }

    final style = textStyle ?? const TextStyle();
    final inputWidth = _measureTextWidth(_controller.text, style);
    final padding = _contentPadding(context);
    final prefixW = _prefixWidth();

    return Positioned.fill(
      left: padding.left + prefixW + inputWidth,
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _ghostText!,
            style: style.copyWith(
              color: Colors.grey,
            ),
            maxLines: 1,
            overflow: TextOverflow.clip,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = widget.style ?? Theme.of(context).textTheme.bodyMedium;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Focus(
        focusNode: _parentFocusNode,
        onKeyEvent: _onKeyEvent,
        child: Stack(
          children: [
            TextField(
              key: _textFieldKey,
              controller: _controller,
              focusNode: _textFieldFocusNode,
              decoration: widget.decoration?.copyWith(
                    hintText: widget.hintText,
                  ) ??
                  InputDecoration(
                    hintText: widget.hintText,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide.none,
                    ),
                  ),
              style: widget.style,
              cursorColor: widget.cursorColor,
              onChanged: (value) {
                _updateSuggestions();
                widget.onChanged?.call(value);
              },
            ),
            _buildGhostText(textStyle),
          ],
        ),
      ),
    );
  }
}

class _SuggestionItem extends StatefulWidget {
  const _SuggestionItem({
    required this.text,
    required this.isSelected,
    required this.isDark,
    required this.theme,
    required this.height,
    required this.padding,
    required this.onTap,
  });

  final String text;
  final bool isSelected;
  final bool isDark;
  final ThemeData theme;
  final double height;
  final EdgeInsetsGeometry padding;
  final VoidCallback onTap;

  @override
  State<_SuggestionItem> createState() => _SuggestionItemState();
}

class _SuggestionItemState extends State<_SuggestionItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.isSelected
        ? widget.theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
        : _isHovered
            ? widget.theme.colorScheme.primaryContainer.withValues(alpha: 0.2)
            : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: widget.height,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            widget.text,
            style: widget.theme.textTheme.bodyMedium?.copyWith(
              color: widget.theme.colorScheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
