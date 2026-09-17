import 'package:flutter/material.dart';

/// A reusable heart-shaped favorite toggle button.
///
/// Animates between filled and outlined states with a small scale bounce.
class FavoriteButton extends StatefulWidget {
  final bool isFavorited;
  final ValueChanged<bool> onToggle;
  final double size;

  const FavoriteButton({
    super.key,
    required this.isFavorited,
    required this.onToggle,
    this.size = 24,
  });

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scale = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    widget.onToggle(!widget.isFavorited);
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            widget.isFavorited ? Icons.favorite : Icons.favorite_border,
            key: ValueKey(widget.isFavorited),
            size: widget.size,
            color: widget.isFavorited
                ? Colors.red
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
