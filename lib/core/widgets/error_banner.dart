import 'package:flutter/material.dart';

import '../errors/failures.dart';

/// A lightweight non-blocking error banner that appears at the top
/// of the current screen via [ScaffoldMessenger].
///
/// Use for transient errors that don't require a full-screen error
/// state (e.g., EPG load failure, single-channel errors).
class ErrorBanner {
  ErrorBanner._();

  /// Show a snackbar with the failure message and an optional retry.
  static void show(
    BuildContext context,
    Failure failure, {
    VoidCallback? onRetry,
    Duration duration = const Duration(seconds: 4),
  }) {
    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _iconForFailure(failure),
              size: 18,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                failure.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: theme.colorScheme.errorContainer,
        duration: duration,
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: theme.colorScheme.onErrorContainer,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  static IconData _iconForFailure(Failure failure) {
    return switch (failure) {
      NetworkFailure() => Icons.wifi_off,
      AuthFailure() => Icons.lock_outline,
      NotFoundFailure() => Icons.search_off,
      ParseFailure() => Icons.broken_image,
      _ => Icons.error_outline,
    };
  }
}
