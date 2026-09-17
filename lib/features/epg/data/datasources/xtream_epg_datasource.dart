import 'package:dio/dio.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/server_config.dart';

/// Remote data source for Xtream Codes EPG endpoints.
///
/// Endpoints used:
///   get_short_epg        (now + next for a stream)
///   get_simple_data_table (full EPG for a stream via stream_id)
class XtreamEpgDatasource {
  final Dio _dio;
  final ServerConfig _serverConfig;

  XtreamEpgDatasource(this._dio, this._serverConfig);

  /// Returns short EPG (typically 2 entries: now + next) for a stream.
  Future<List<Map<String, dynamic>>> getShortEpg(String streamId) async {
    try {
      final response = await _dio.get(
        '${_serverConfig.baseUrl}/player_api.php',
        queryParameters: {
          'username': _serverConfig.username,
          'password': _serverConfig.password,
          'action': 'get_short_epg',
          'stream_id': streamId,
        },
      );

      final data = response.data;
      // Response shape: { epg_listings: [ ... ] }
      if (data is Map<String, dynamic>) {
        final listings = data['epg_listings'] as List? ?? [];
        return listings.cast<Map<String, dynamic>>();
      }
      if (data is List) return data.cast<Map<String, dynamic>>();
      return [];
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    } catch (e) {
      throw UnexpectedFailure(message: e.toString());
    }
  }

  /// Returns full EPG listings for a stream.
  Future<List<Map<String, dynamic>>> getFullEpg(
    String streamId, {
    int limit = 50,
  }) async {
    try {
      final response = await _dio.get(
        '${_serverConfig.baseUrl}/player_api.php',
        queryParameters: {
          'username': _serverConfig.username,
          'password': _serverConfig.password,
          'action': 'get_simple_data_table',
          'stream_id': streamId,
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final listings = data['epg_listings'] as List? ?? [];
        return listings
            .take(limit)
            .cast<Map<String, dynamic>>()
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    } catch (e) {
      throw UnexpectedFailure(message: e.toString());
    }
  }
}
