import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import 'logging_interceptor.dart';
import 'retry_interceptor.dart';
import 'server_config.dart';

/// Factory that builds a pre-configured [Dio] instance.
///
/// NOTE: ConnectivityInterceptor was REMOVED because the
/// connectivity_plus plugin reports false negatives on Fire TV
/// and Android TV devices (returns "none" even when connected
/// via Ethernet/WiFi). Dio's native error handling already covers
/// real network failures — the ErrorMapper converts them to the
/// correct Failure types. No pre-check needed.
class DioFactory {
  DioFactory._();

  static Dio create() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        sendTimeout: AppConstants.connectTimeout,
        responseType: ResponseType.json,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'XtremeIPTV/1.0',
        },
      ),
    );

    // Only retry + logging. No connectivity pre-check.
    dio.interceptors.add(RetryInterceptor(dio));
    dio.interceptors.add(LoggingInterceptor());

    return dio;
  }
}
