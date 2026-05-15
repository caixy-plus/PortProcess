import 'package:flutter/material.dart';

/// Custom restore-from-maximize icon used in the window title bar.
class RestoreIcon extends StatelessWidget {
  const RestoreIcon({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ?? Theme.of(context).iconTheme.color ?? Colors.black;

    return SizedBox(
      width: 14,
      height: 14,
      child: Stack(
        children: [
          Positioned(
            left: 2,
            top: 0,
            child: Container(
              width: 10,
              height: 8,
              decoration: BoxDecoration(
                border: Border.all(color: effectiveColor, width: 1.2),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 4,
            child: Container(
              width: 10,
              height: 8,
              decoration: BoxDecoration(
                border: Border.all(color: effectiveColor, width: 1.2),
                color: effectiveColor.withValues(alpha: 0.1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
