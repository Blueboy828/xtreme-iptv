import 'package:equatable/equatable.dart';

/// Domain entity for a Series category.
class SeriesCategory extends Equatable {
  final String categoryId;
  final String name;

  const SeriesCategory({required this.categoryId, required this.name});

  @override
  List<Object> get props => [categoryId, name];
}

/// Domain entity for a Series item.
class SeriesItem extends Equatable {
  final String seriesId;
  final String name;
  final String categoryId;
  final String? cover;
  final String? plot;
  final String? cast;
  final String? director;
  final String? genre;
  final String? releaseDate;
  final String? rating;
  final int? episodeCount;

  const SeriesItem({
    required this.seriesId,
    required this.name,
    required this.categoryId,
    this.cover,
    this.plot,
    this.cast,
    this.director,
    this.genre,
    this.releaseDate,
    this.rating,
    this.episodeCount,
  });

  @override
  List<Object?> get props => [seriesId, name, categoryId, cover];
}

/// Domain entity for a Series episode.
class SeriesEpisode extends Equatable {
  final String episodeId;
  final String title;
  final String episodeNum;
  final String season;
  final String? info;
  final String? containerExtension;

  const SeriesEpisode({
    required this.episodeId,
    required this.title,
    required this.episodeNum,
    required this.season,
    this.info,
    this.containerExtension,
  });

  @override
  List<Object?> get props => [episodeId, title, episodeNum, season];
}

/// Domain entity for a full season with its episodes.
class SeriesSeason extends Equatable {
  final String seasonNumber;
  final List<SeriesEpisode> episodes;

  const SeriesSeason({
    required this.seasonNumber,
    required this.episodes,
  });

  @override
  List<Object> get props => [seasonNumber, episodes];
}
