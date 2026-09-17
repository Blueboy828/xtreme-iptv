import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/search_entities.dart';

/// Abstract contract for unified search across all content.
abstract class SearchRepository {
  /// Search across live TV, movies, and series by query string.
  ///
  /// Returns grouped results. Implementations should fire
  /// all three API calls in parallel for speed.
  Future<Either<Failure, SearchResults>> search(String query);
}
