import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../live_tv/data/datasources/xtream_live_datasource.dart';
import '../../../movies/data/datasources/xtream_movies_datasource.dart';
import '../../../series/data/datasources/xtream_series_datasource.dart';
import '../../domain/entities/search_entities.dart';
import '../../domain/repositories/search_repository.dart';

/// Implementation that queries all three Xtream datasources in parallel
/// and merges results into a unified [SearchResults].
///
/// Uses `Future.wait` for parallelism. If one source fails, returns
/// partial results from the others (no all-or-nothing for search).
class SearchRepositoryImpl implements SearchRepository {
  final XtreamLiveDatasource _liveDatasource;
  final XtreamMoviesDatasource _moviesDatasource;
  final XtreamSeriesDatasource _seriesDatasource;

  SearchRepositoryImpl(
    this._liveDatasource,
    this._moviesDatasource,
    this._seriesDatasource,
  );

  @override
  Future<Either<Failure, SearchResults>> search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return const Right(SearchResults());
    }

    try {
      // Fire all three requests in parallel.
      final results = await Future.wait([
        _liveDatasource.getStreams(categoryId: null),
        _moviesDatasource.getStreams(categoryId: null),
        _seriesDatasource.getSeries(categoryId: null),
      ]);

      final liveStreams = results[0];
      final movieStreams = results[1];
      final seriesStreams = results[2];

      // Client-side filter by query.
      // Datasources return List<Map<String, dynamic>> (raw JSON),
      // so we use bracket notation to access fields.
      final live = liveStreams
          .where((s) => (s['name'] as String? ?? '').toLowerCase().contains(q))
          .map((s) => SearchResult(
                type: SearchResultType.live,
                streamId: s['stream_id']?.toString() ?? '',
                name: s['name']?.toString() ?? '',
                imageUrl: s['stream_icon']?.toString(),
                categoryId: s['category_id']?.toString(),
              ))
          .toList();

      final movies = movieStreams
          .where((s) => (s['name'] as String? ?? '').toLowerCase().contains(q))
          .map((s) => SearchResult(
                type: SearchResultType.movie,
                streamId: s['stream_id']?.toString() ?? '',
                name: s['name']?.toString() ?? '',
                imageUrl: s['stream_icon']?.toString(),
                containerExtension: s['container_extension']?.toString(),
                categoryId: s['category_id']?.toString(),
              ))
          .toList();

      final series = seriesStreams
          .where((s) => (s['name'] as String? ?? '').toLowerCase().contains(q))
          .map((s) => SearchResult(
                type: SearchResultType.series,
                streamId: s['series_id']?.toString() ?? '',
                name: s['name']?.toString() ?? '',
                imageUrl: s['cover']?.toString(),
                categoryId: s['category_id']?.toString(),
              ))
          .toList();

      // Limit each category to 50 results for performance.
      return Right(SearchResults(
        live: live.take(50).toList(),
        movies: movies.take(50).toList(),
        series: series.take(50).toList(),
      ));
    } catch (e) {
      return Left(UnexpectedFailure(message: 'Search failed: $e'));
    }
  }
}
