import 'package:flutter/material.dart';

/// A single window-control button (minimize / maximize / close).
///
/// Mimics native desktop window controls with hover effects:
/// - Minimize / maximize: dark-grey background on hover.
/// - Close: red background + white icon on hover.
class WindowControlButton extends StatefulWidget {
  const WindowControlButton({
    super.key,
    this.icon,
    this.customIcon,
    required this.onPressed,
    this.hoverColor,
    this.borderRadius,
  }) : assert(icon != null || customIcon != null);

  final IconData? icon;
  final Widget? customIcon;
  final VoidCallback onPressed;
  final Color? hoverColor;
  final BorderRadius? borderRadius;

  @override
  State<WindowControlButton> createState() => _WindowControlButtonState();
}

class _WindowControlButtonState extends State<WindowControlButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isCloseButton = widget.hoverColor == Colors.red;

    const Color defaultHoverBg = Color(0xFFE5E5E5);
    const Color closeHoverBg = Color(0xFFE81123);

    final bgColor = _isHovered
        ? (isCloseButton ? closeHoverBg : defaultHoverBg)
        : Colors.transparent;

    final iconColor = _isHovered && isCloseButton ? Colors.white : null;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: widget.borderRadius,
          ),
          child: Center(
            child: widget.customIcon ??
                Icon(
                  widget.icon!,
                  size: 14,
                  color: iconColor,
                ),
          ),
        ),
      ),
    );
  }
}
