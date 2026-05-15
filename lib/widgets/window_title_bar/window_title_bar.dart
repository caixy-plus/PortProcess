import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'restore_icon.dart';
import 'window_control_button.dart';

/// A reusable, platform-aware custom window title bar for Flutter desktop apps.
///
/// On mobile platforms (Android / iOS) the widget renders an empty [SizedBox]
/// unless [forceShow] is set to `true`. This makes the component safe to drop
/// into cross-platform codebases.
///
/// The bar supports drag-to-move, double-tap-to-toggle-maximize, and the
/// classic minimize / maximize / close buttons with native-feeling hover
/// effects.
class WindowTitleBar extends StatelessWidget {
  const WindowTitleBar({
    super.key,
    this.title,
    this.leading,
    this.showMinimize = true,
    this.showMaximize = true,
    this.showClose = true,
    this.isMaximized = false,
    this.onMinimize,
    this.onMaximize,
    this.onClose,
    this.onDragStart,
    this.onDoubleTap,
    this.backgroundColor,
    this.height = 40,
    this.forceShow = false,
  });

  /// Text shown next to the [leading] icon. Null = no text.
  final String? title;

  /// Widget displayed at the left of the bar (e.g. an app icon).
  final Widget? leading;

  /// Whether to render the minimize button.
  final bool showMinimize;

  /// Whether to render the maximize / restore button.
  final bool showMaximize;

  /// Whether to render the close button.
  final bool showClose;

  /// Current maximized state; controls the maximize/restore icon.
  final bool isMaximized;

  /// Called when the minimize button is pressed.
  final VoidCallback? onMinimize;

  /// Called when the maximize / restore button is pressed.
  final VoidCallback? onMaximize;

  /// Called when the close button is pressed.
  final VoidCallback? onClose;

  /// Called when the user starts dragging the bar.
  final VoidCallback? onDragStart;

  /// Called when the user double-taps the bar.
  final VoidCallback? onDoubleTap;

  /// Background color of the bar. Defaults to
  /// `Theme.of(context).colorScheme.surfaceContainerHighest` at 50 % opacity.
  final Color? backgroundColor;

  /// Height of the title bar in logical pixels.
  final double height;

  /// When `true` the bar is rendered even on mobile platforms.
  final bool forceShow;

  bool get _isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop && !forceShow) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final bg = backgroundColor ??
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);

    return GestureDetector(
      onPanStart: onDragStart != null ? (_) => onDragStart!() : null,
      onDoubleTap: onDoubleTap != null ? () => onDoubleTap!() : null,
      child: Container(
        height: height,
        color: bg,
        child: Row(
          children: [
            const SizedBox(width: 16),
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 8),
            ],
            if (title != null)
              Text(
                title!,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            const Spacer(),
            if (showMinimize)
              WindowControlButton(
                icon: Icons.remove,
                onPressed: onMinimize ?? () {},
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(6)),
              ),
            if (showMaximize)
              WindowControlButton(
                icon: isMaximized ? null : Icons.crop_square,
                customIcon: isMaximized
                    ? RestoreIcon(color: theme.iconTheme.color)
                    : null,
                onPressed: onMaximize ?? () {},
              ),
            if (showClose)
              WindowControlButton(
                icon: Icons.close,
                onPressed: onClose ?? () {},
                hoverColor: Colors.red,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
              ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}
