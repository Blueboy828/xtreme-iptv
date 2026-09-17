import 'package:flutter/material.dart';

import '../errors/failures.dart';

/// A reusable error state widget that shows a failure message
/// and an optional retry button.
class ErrorStateWidget extends StatelessWidget {
  const ErrorStateWidget({
    super.key,
    required this.failure,
    this.onRetry,
  });

  final Failure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _iconForFailure(failure),
              size: 56,
              color: theme.colorScheme.error.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              failure.message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            if (onRetry != null)
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconForFailure(Failure failure) {
    return switch (failure) {
      NetworkFailure() => Icons.wifi_off,
      AuthFailure() => Icons.lock_outline,
      NotFoundFailure() => Icons.search_off,
      ParseFailure() => Icons.broken_image,
      _ => Icons.error_outline,
    };
  }
}
