import 'package:dio/dio.dart';

/// DEPRECATED: This interceptor was removed from the Dio chain because
/// connectivity_plus reports false negatives on Fire TV / Android TV.
///
/// Kept as a no-op for backwards compatibility. Does nothing.
class ConnectivityInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Always pass through — never block requests.
    handler.next(options);
  }
}
