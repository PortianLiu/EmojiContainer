import 'package:flutter/material.dart';

/// 右下角 FAB，相对默认位置向内偏移
class InsetFab extends StatelessWidget {
  const InsetFab({
    super.key,
    required this.onPressed,
    required this.tooltip,
    required this.child,
  });

  final VoidCallback? onPressed;
  final String tooltip;
  final Widget child;

  static const _inset = EdgeInsets.only(right: 20, bottom: 20);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _inset,
      child: FloatingActionButton(
        onPressed: onPressed,
        tooltip: tooltip,
        child: child,
      ),
    );
  }
}
