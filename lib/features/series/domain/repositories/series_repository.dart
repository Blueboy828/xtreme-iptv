import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/series_entities.dart';

/// Contract for Series data operations.
abstract class SeriesRepository {
  Future<Either<Failure, List<SeriesCategory>>> getCategories();
  Future<Either<Failure, List<SeriesItem>>> getSeries({String? categoryId});
  Future<Either<Failure, ({SeriesItem info, List<SeriesSeason> seasons})>>
      getSeriesInfo(String seriesId);
}
