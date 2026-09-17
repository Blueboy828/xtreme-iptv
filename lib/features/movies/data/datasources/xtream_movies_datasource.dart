import 'package:dio/dio.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/server_config.dart';

/// Remote data source for Xtream Codes VOD (movie) endpoints.
///
/// Endpoints used:
///   get_vod_categories
///   get_vod_streams (optionally filtered by category_id)
///   get_vod_info (for a single movie's details)
class XtreamMoviesDatasource {
  final Dio _dio;
  final ServerConfig _serverConfig;

  XtreamMoviesDatasource(this._dio, this._serverConfig);

  /// Returns all VOD categories as raw JSON.
  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final response = await _dio.get(
        '${_serverConfig.baseUrl}/player_api.php',
        queryParameters: {
          'username': _serverConfig.username,
          'password': _serverConfig.password,
          'action': 'get_vod_categories',
        },
      );

      final data = response.data;
      if (data is List) return data.cast<Map<String, dynamic>>();
      return [];
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    } catch (e) {
      throw UnexpectedFailure(message: e.toString());
    }
  }

  /// Returns VOD streams, optionally filtered by category.
  Future<List<Map<String, dynamic>>> getStreams({String? categoryId}) async {
    try {
      final params = <String, dynamic>{
        'username': _serverConfig.username,
        'password': _serverConfig.password,
        'action': 'get_vod_streams',
      };
      if (categoryId != null) params['category_id'] = categoryId;

      final response = await _dio.get(
        '${_serverConfig.baseUrl}/player_api.php',
        queryParameters: params,
      );

      final data = response.data;
      if (data is List) return data.cast<Map<String, dynamic>>();
      return [];
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    } catch (e) {
      throw UnexpectedFailure(message: e.toString());
    }
  }

  /// Returns detailed info for a single VOD item.
  Future<Map<String, dynamic>> getMovieInfo(String vodId) async {
    try {
      final response = await _dio.get(
        '${_serverConfig.baseUrl}/player_api.php',
        queryParameters: {
          'username': _serverConfig.username,
          'password': _serverConfig.password,
          'action': 'get_vod_info',
          'vod_id': vodId,
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      throw const ParseFailure(message: 'Unexpected VOD info response');
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    } on Failure {
      rethrow;
    } catch (e) {
      throw UnexpectedFailure(message: e.toString());
    }
  }
}
