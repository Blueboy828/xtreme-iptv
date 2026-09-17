import 'package:equatable/equatable.dart';

/// Domain entity for a VOD (movie) category.
class MovieCategory extends Equatable {
  final String categoryId;
  final String name;

  const MovieCategory({required this.categoryId, required this.name});

  @override
  List<Object> get props => [categoryId, name];
}

/// Domain entity for a VOD (movie) item.
class Movie extends Equatable {
  final String streamId;
  final String name;
  final String categoryId;
  final String? streamIcon;
  final String? rating;
  final String? plot;
  final String? cast;
  final String? director;
  final String? genre;
  final String? releasedate;
  final int? duration;
  final String? containerExtension;

  const Movie({
    required this.streamId,
    required this.name,
    required this.categoryId,
    this.streamIcon,
    this.rating,
    this.plot,
    this.cast,
    this.director,
    this.genre,
    this.releasedate,
    this.duration,
    this.containerExtension,
  });

  @override
  List<Object?> get props => [streamId, name, categoryId, streamIcon];
}
