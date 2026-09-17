import 'package:dio/dio.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/server_config.dart';

/// Remote data source that talks directly to the Xtream Codes `player_api.php`
/// endpoint for authentication.
class XtreamAuthDatasource {
  final Dio _dio;
  final ServerConfig _serverConfig;

  XtreamAuthDatasource(this._dio, this._serverConfig);

  /// Calls `player_api.php?username=X&password=Y`.
  ///
  /// Returns the raw JSON map or throws a [Failure].
  Future<Map<String, dynamic>> authenticate({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    final url = _buildApiUrl(baseUrl);

    try {
      final response = await _dio.get(
        url,
        queryParameters: {
          'username': username,
          'password': password,
        },
      );

      final data = response.data as Map<String, dynamic>;

      // Xtream returns { user_info: { auth: 0 } } on bad credentials.
      final userInfo = data['user_info'] as Map<String, dynamic>?;
      if (userInfo == null) {
        throw const AuthFailure(message: 'Invalid server response');
      }

      // Check if auth was rejected.
      final auth = userInfo['auth']?.toString();
      if (auth == '0') {
        throw const AuthFailure();
      }

      // Check if account is active.
      final status = userInfo['status']?.toString().toLowerCase();
      if (status == 'disabled' || status == 'banned') {
        throw AuthFailure(message: 'Account is $status');
      }

      // Configure the global server config for subsequent calls.
      _serverConfig.configure(
        baseUrl: baseUrl,
        username: username,
        password: password,
      );

      return data;
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    } on Failure {
      rethrow;
    } catch (e) {
      throw UnexpectedFailure(message: e.toString());
    }
  }

  String _buildApiUrl(String baseUrl) {
    final normalized = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return '$normalized/player_api.php';
  }
}
