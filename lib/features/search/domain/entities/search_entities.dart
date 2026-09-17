import 'package:equatable/equatable.dart';

/// The content type of a search result.
enum SearchResultType { live, movie, series }

/// A single unified search result across all content types.
///
/// Carries just enough data to render a row and navigate
/// to the correct destination (player or details page).
class SearchResult extends Equatable {
  final SearchResultType type;
  final String streamId;
  final String name;
  final String? imageUrl;
  final String? containerExtension;
  final String? categoryId;

  const SearchResult({
    required this.type,
    required this.streamId,
    required this.name,
    this.imageUrl,
    this.containerExtension,
    this.categoryId,
  });

  @override
  List<Object?> get props =>
      [type, streamId, name, imageUrl, containerExtension, categoryId];
}

/// Grouped search results for display.
class SearchResults extends Equatable {
  final List<SearchResult> live;
  final List<SearchResult> movies;
  final List<SearchResult> series;

  const SearchResults({
    this.live = const [],
    this.movies = const [],
    this.series = const [],
  });

  bool get isEmpty => live.isEmpty && movies.isEmpty && series.isEmpty;

  int get total => live.length + movies.length + series.length;

  SearchResults copyWith({
    List<SearchResult>? live,
    List<SearchResult>? movies,
    List<SearchResult>? series,
  }) {
    return SearchResults(
      live: live ?? this.live,
      movies: movies ?? this.movies,
      series: series ?? this.series,
    );
  }

  @override
  List<Object?> get props => [live, movies, series];
}
