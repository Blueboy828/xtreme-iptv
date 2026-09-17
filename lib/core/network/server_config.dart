import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../constants/app_constants.dart';

/// Holds the currently authenticated Xtream Codes server details.
///
/// After a successful login, [configure] is called with the server info.
/// All subsequent API calls use these values automatically.
class ServerConfig {
  static final ServerConfig _instance = ServerConfig._();
  factory ServerConfig() => _instance;
  ServerConfig._();

  String? _baseUrl;
  String? _username;
  String? _password;

  /// Whether credentials have been configured.
  bool get isConfigured =>
      _baseUrl != null && _username != null && _password != null;

  /// Base URL without trailing slash, e.g. `http://1.2.3.4:8080`.
  String get baseUrl => _baseUrl!;

  String get username => _username!;

  String get password => _password!;

  /// Sets the server connection details after login.
  void configure({
    required String baseUrl,
    required String username,
    required String password,
  }) {
    // Normalize: remove trailing slash.
    _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    _username = username;
    _password = password;
  }

  /// Clears credentials on logout.
  void clear() {
    _baseUrl = null;
    _username = null;
    _password = null;
  }
}
