import 'package:dio/dio.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/server_config.dart';

/// Remote data source for Xtream Codes Series endpoints.
///
/// Endpoints used:
///   get_series_categories
///   get_series (optionally filtered by category_id)
///   get_series_info (for a single series with seasons + episodes)
class XtreamSeriesDatasource {
  final Dio _dio;
  final ServerConfig _serverConfig;

  XtreamSeriesDatasource(this._dio, this._serverConfig);

  /// Returns all series categories as raw JSON.
  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final response = await _dio.get(
        '${_serverConfig.baseUrl}/player_api.php',
        queryParameters: {
          'username': _serverConfig.username,
          'password': _serverConfig.password,
          'action': 'get_series_categories',
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

  /// Returns series items, optionally filtered by category.
  Future<List<Map<String, dynamic>>> getSeries({String? categoryId}) async {
    try {
      final params = <String, dynamic>{
        'username': _serverConfig.username,
        'password': _serverConfig.password,
        'action': 'get_series',
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

  /// Returns detailed info for a single series, including seasons and episodes.
  Future<Map<String, dynamic>> getSeriesInfo(String seriesId) async {
    try {
      final response = await _dio.get(
        '${_serverConfig.baseUrl}/player_api.php',
        queryParameters: {
          'username': _serverConfig.username,
          'password': _serverConfig.password,
          'action': 'get_series_info',
          'series_id': seriesId,
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      throw const ParseFailure(message: 'Unexpected series info response');
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    } on Failure {
      rethrow;
    } catch (e) {
      throw UnexpectedFailure(message: e.toString());
    }
  }
}
