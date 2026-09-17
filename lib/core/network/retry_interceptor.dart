import 'dart:async';

import 'package:dio/dio.dart';

import '../constants/app_constants.dart';

/// Retries failed requests up to [AppConstants.maxRetries] times
/// using **exponential backoff**.
///
/// Delay between retries = `baseDelay * 2^attempt`, capped at
/// `maxDelay`. So: 1s → 2s → 4s → (capped at 10s).
///
/// Only retries on network errors and 5xx server errors — not on
/// auth failures (401/403) or not-found (404).
class RetryInterceptor extends Interceptor {
  final Dio _dio;

  RetryInterceptor(this._dio);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Don't retry on auth or not-found errors.
    final statusCode = err.response?.statusCode ?? 0;
    if (statusCode == 401 || statusCode == 403 || statusCode == 404) {
      handler.next(err);
      return;
    }

    final retryCount = (err.requestOptions.extra['retryCount'] as int?) ?? 0;
    if (retryCount >= AppConstants.maxRetries) {
      handler.next(err);
      return;
    }

    _scheduleRetry(err, handler, retryCount);
  }

  void _scheduleRetry(
    DioException err,
    ErrorInterceptorHandler handler,
    int retryCount,
  ) {
    final options = err.requestOptions.copyWith(
      extra: {...err.requestOptions.extra, 'retryCount': retryCount + 1},
    );

    // Exponential backoff: base * 2^attempt, capped at maxDelay.
    final delayMs = (AppConstants.retryBaseDelay.inMilliseconds *
        (1 << retryCount)); // 2^retryCount
    final delay = Duration(
      milliseconds: delayMs.clamp(
        AppConstants.retryBaseDelay.inMilliseconds,
        AppConstants.retryMaxDelay.inMilliseconds,
      ),
    );

    Timer(delay, () {
      _dio
          .fetch(options)
          .then((response) => handler.resolve(response))
          .catchError((e) {
        if (e is DioException) {
          handler.next(e);
        } else {
          handler.next(
            DioException(
              requestOptions: options,
              type: DioExceptionType.unknown,
              error: e,
            ),
          );
        }
      });
    });
  }
}
