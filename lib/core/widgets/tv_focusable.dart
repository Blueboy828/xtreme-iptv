import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A wrapper that makes any widget navigable with a TV remote D-pad.
class TvFocusable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onFocusChange;
  final bool autofocus;
  final BorderRadius? borderRadius;
  final EdgeInsets focusPadding;

  const TvFocusable({
    super.key,
    required this.child,
    this.onTap,
    this.onFocusChange,
    this.autofocus = false,
    this.borderRadius,
    this.focusPadding = const EdgeInsets.all(2),
  });

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'TvFocusable');
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (focused) {
        setState(() => _isFocused = focused);
        widget.onFocusChange?.call();
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter) {
            widget.onTap?.call();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        // Touch support (phones/tablets) — fires the same onTap the
        // remote's Enter/Select fires via onKeyEvent above.
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: _isFocused ? widget.focusPadding : EdgeInsets.zero,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
            border: _isFocused
                ? Border.all(color: theme.colorScheme.primary, width: 2.5)
                : Border.all(color: Colors.transparent, width: 2.5),
            color: _isFocused
                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
