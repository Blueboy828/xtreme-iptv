import 'package:flutter/material.dart';

/// Full-screen shimmer loading placeholder for grid layouts.
///
/// Uses a theme-aware shimmer animation instead of static placeholders
/// for a more polished loading experience.
class ShimmerGrid extends StatefulWidget {
  const ShimmerGrid({super.key, this.itemCount = 12});

  final int itemCount;

  @override
  State<ShimmerGrid> createState() => _ShimmerGridState();
}

class _ShimmerGridState extends State<ShimmerGrid>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.surfaceContainerHighest
        .withValues(alpha: 0.4);
    final highlightColor = theme.colorScheme.surfaceContainerHighest
        .withValues(alpha: 0.15);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.65,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: widget.itemCount,
          itemBuilder: (context, index) => _shimmerBox(
            baseColor,
            highlightColor,
          ),
        );
      },
    );
  }

  Widget _shimmerBox(Color baseColor, Color highlightColor) {
    // Sweep the highlight across based on animation value.
    final t = _controller.value;
    final shimmerColor = Color.lerp(baseColor, highlightColor, t)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: shimmerColor,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 10,
          width: double.infinity,
          decoration: BoxDecoration(
            color: shimmerColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 8,
          width: 60,
          decoration: BoxDecoration(
            color: shimmerColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}
