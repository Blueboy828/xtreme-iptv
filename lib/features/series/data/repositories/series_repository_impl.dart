import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/series_entities.dart';
import '../../domain/repositories/series_repository.dart';
import '../datasources/xtream_series_datasource.dart';

class SeriesRepositoryImpl implements SeriesRepository {
  final XtreamSeriesDatasource _datasource;

  SeriesRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, List<SeriesCategory>>> getCategories() async {
    try {
      final raw = await _datasource.getCategories();
      final categories = raw
          .map((e) => SeriesCategory(
                categoryId: e['category_id']?.toString() ?? '',
                name: e['category_name']?.toString() ?? 'Unknown',
              ))
          .toList();
      return Right(categories);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<SeriesItem>>> getSeries({
    String? categoryId,
  }) async {
    try {
      final raw = await _datasource.getSeries(categoryId: categoryId);
      final series = raw
          .map((e) => SeriesItem(
                seriesId: e['series_id']?.toString() ?? '',
                name: e['name']?.toString() ?? 'Unknown',
                categoryId: e['category_id']?.toString() ?? '',
                cover: e['cover']?.toString(),
                plot: e['plot']?.toString(),
                cast: e['cast']?.toString(),
                director: e['director']?.toString(),
                genre: e['genre']?.toString(),
                releaseDate: e['releaseDate']?.toString(),
                rating: e['rating']?.toString(),
                episodeCount: int.tryParse(
                  e['episode_count']?.toString() ?? '',
                ),
              ))
          .toList();
      return Right(series);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<
      Either<Failure, ({SeriesItem info, List<SeriesSeason> seasons})>>
      getSeriesInfo(String seriesId) async {
    try {
      final raw = await _datasource.getSeriesInfo(seriesId);
      final infoRaw = raw['info'] as Map<String, dynamic>?;

      final info = SeriesItem(
        seriesId: seriesId,
        name: infoRaw?['name']?.toString() ?? 'Unknown',
        categoryId: infoRaw?['category_id']?.toString() ?? '',
        cover: infoRaw?['cover']?.toString(),
        plot: infoRaw?['plot']?.toString(),
        cast: infoRaw?['cast']?.toString(),
        director: infoRaw?['director']?.toString(),
        genre: infoRaw?['genre']?.toString(),
        releaseDate: infoRaw?['releaseDate']?.toString(),
        rating: infoRaw?['rating']?.toString(),
      );

      // Xtream returns seasons as a map where keys are season numbers
      // and values are arrays of episodes.
      final episodesMap = raw['episodes'] as Map<String, dynamic>?;

      final seasons = <SeriesSeason>[];
      if (episodesMap != null) {
        final sortedKeys = episodesMap.keys.toList()
          ..sort((a, b) {
            final aNum = int.tryParse(a) ?? 0;
            final bNum = int.tryParse(b) ?? 0;
            return aNum.compareTo(bNum);
          });

        for (final seasonKey in sortedKeys) {
          final episodesRaw = episodesMap[seasonKey] as List? ?? [];
          final episodes = episodesRaw
              .map((e) => SeriesEpisode(
                    episodeId: e['id']?.toString() ?? '',
                    title: e['title']?.toString() ?? 'Unknown',
                    episodeNum: e['episode_num']?.toString() ?? '0',
                    season: seasonKey,
                    info: e['info']?.toString(),
                    containerExtension:
                        e['container_extension']?.toString() ?? 'mp4',
                  ))
              .toList();
          seasons.add(SeriesSeason(
            seasonNumber: seasonKey,
            episodes: episodes,
          ));
        }
      }

      return Right((info: info, seasons: seasons));
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }
}
