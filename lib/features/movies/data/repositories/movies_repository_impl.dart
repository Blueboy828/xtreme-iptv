import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/movie_entities.dart';
import '../../domain/repositories/movies_repository.dart';
import '../datasources/xtream_movies_datasource.dart';

class MoviesRepositoryImpl implements MoviesRepository {
  final XtreamMoviesDatasource _datasource;

  MoviesRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, List<MovieCategory>>> getCategories() async {
    try {
      final raw = await _datasource.getCategories();
      final categories = raw
          .map((e) => MovieCategory(
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
  Future<Either<Failure, List<Movie>>> getMovies({String? categoryId}) async {
    try {
      final raw = await _datasource.getStreams(categoryId: categoryId);
      final movies = raw
          .map((e) => Movie(
                streamId: e['stream_id']?.toString() ?? '',
                name: e['name']?.toString() ?? 'Unknown',
                categoryId: e['category_id']?.toString() ?? '',
                streamIcon: e['stream_icon']?.toString(),
                rating: e['rating']?.toString(),
                containerExtension:
                    e['container_extension']?.toString() ?? 'mp4',
              ))
          .toList();
      return Right(movies);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Movie>> getMovieInfo(String vodId) async {
    try {
      final raw = await _datasource.getMovieInfo(vodId);
      final info = raw['info'] as Map<String, dynamic>?;
      final movieData = raw['movie_data'] as Map<String, dynamic>?;

      return Right(Movie(
        streamId: vodId,
        name: movieData?['name']?.toString() ?? 'Unknown',
        categoryId: movieData?['category_id']?.toString() ?? '',
        streamIcon: info?['movie_image']?.toString(),
        rating: info?['rating']?.toString(),
        plot: info?['plot']?.toString(),
        cast: info?['cast']?.toString(),
        director: info?['director']?.toString(),
        genre: info?['genre']?.toString(),
        releasedate: info?['releasedate']?.toString(),
        duration: int.tryParse(
          info?['duration']?.toString() ?? '',
        ),
        containerExtension:
            movieData?['container_extension']?.toString() ?? 'mp4',
      ));
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }
}
