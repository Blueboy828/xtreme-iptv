import 'package:dio/dio.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/server_config.dart';

/// Remote data source for Xtream Codes Live TV endpoints.
///
/// Endpoints used:
///   get_live_categories
///   get_live_streams (optionally filtered by category_id)
class XtreamLiveDatasource {
  final Dio _dio;
  final ServerConfig _serverConfig;

  XtreamLiveDatasource(this._dio, this._serverConfig);

  /// Returns all live TV categories as raw JSON.
  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final response = await _dio.get(
        '${_serverConfig.baseUrl}/player_api.php',
        queryParameters: {
          'username': _serverConfig.username,
          'password': _serverConfig.password,
          'action': 'get_live_categories',
        },
      );

      final data = response.data;
      if (data is List) {
        return data.cast<Map<String, dynamic>>();
      }
      // Some servers return an empty object on no categories.
      return [];
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    } catch (e) {
      throw UnexpectedFailure(message: e.toString());
    }
  }

  /// Returns live streams, optionally filtered by category.
  Future<List<Map<String, dynamic>>> getStreams({String? categoryId}) async {
    try {
      final params = <String, dynamic>{
        'username': _serverConfig.username,
        'password': _serverConfig.password,
        'action': 'get_live_streams',
      };
      if (categoryId != null) {
        params['category_id'] = categoryId;
      }

      final response = await _dio.get(
        '${_serverConfig.baseUrl}/player_api.php',
        queryParameters: params,
      );

      final data = response.data;
      if (data is List) {
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    } catch (e) {
      throw UnexpectedFailure(message: e.toString());
    }
  }
}
