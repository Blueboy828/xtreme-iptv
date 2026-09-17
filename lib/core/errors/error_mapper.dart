import 'dart:io';

import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import 'failures.dart';

/// Maps low-level [DioException] / [SocketException] into domain [Failure]s.
class ErrorMapper {
  ErrorMapper._();

  static Failure fromException(Object error) {
    if (error is DioException) {
      return _fromDioException(error);
    }
    if (error is SocketException) {
      // Real socket error — server unreachable, not "no internet"
      return const NetworkFailure(message: 'Cannot reach server. Check the URL and your network.');
    }
    if (error is FormatException) {
      return ParseFailure(message: error.message);
    }
    return UnexpectedFailure(message: error.toString());
  }

  static Failure _fromDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const NetworkFailure(message: 'Connection timed out. The server may be slow or unreachable.');
      case DioExceptionType.connectionError:
        // This fires when the server is unreachable OR there's no network.
        // On Fire TV, this is almost always a server issue, not a connectivity issue.
        final msg = e.message;
        if (msg != null && msg.contains('No internet connection')) {
          return const NetworkFailure(message: 'No internet connection');
        }
        // Check if it's a DNS/hostname resolution failure
        if (msg != null && (msg.contains('Failed host lookup') || msg.contains('host'))) {
          return const NetworkFailure(message: 'Cannot find server. Check the URL is correct.');
        }
        // Generic connection error — server unreachable
        return const NetworkFailure(message: 'Cannot reach server. Check the URL and try again.');
      case DioExceptionType.badResponse:
        return _fromStatusCode(e.response?.statusCode ?? 0, e);
      case DioExceptionType.cancel:
        return const UnexpectedFailure(message: 'Request was cancelled');
      case DioExceptionType.badCertificate:
        return const UnexpectedFailure(message: 'Certificate error — server may use a self-signed cert.');
      case DioExceptionType.unknown:
        return UnexpectedFailure(message: e.message ?? 'Unknown error');
    }
  }

  static Failure _fromStatusCode(int statusCode, DioException e) {
    if (statusCode == 401 || statusCode == 403) {
      return AuthFailure(code: statusCode);
    }
    if (statusCode == 404) {
      return const NotFoundFailure();
    }
    if (statusCode >= 500) {
      return ServerFailure(
        message: 'Server error ($statusCode)',
        code: statusCode,
      );
    }
    return ServerFailure(
      message: 'Request failed ($statusCode)',
      code: statusCode,
    );
  }

  static bool isRetryable(Failure failure) {
    return failure is NetworkFailure ||
        (failure is ServerFailure && (failure.code ?? 0) >= 500);
  }
}
