import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/movie_entities.dart';

/// Contract for Movies (VOD) data operations.
abstract class MoviesRepository {
  Future<Either<Failure, List<MovieCategory>>> getCategories();
  Future<Either<Failure, List<Movie>>> getMovies({String? categoryId});
  Future<Either<Failure, Movie>> getMovieInfo(String vodId);
}
