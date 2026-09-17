import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/favorite_entities.dart';

/// Abstract contract for local favorites persistence.
abstract class FavoritesRepository {
  /// Get all favorites, optionally filtered by type.
  Future<Either<Failure, List<FavoriteItem>>> getFavorites({
    FavoriteType? type,
  });

  /// Check whether an item is favorited.
  Future<Either<Failure, bool>> isFavorite(FavoriteType type, String streamId);

  /// Add a favorite.
  Future<Either<Failure, void>> addFavorite(FavoriteItem item);

  /// Remove a favorite by type + streamId.
  Future<Either<Failure, void>> removeFavorite(
      FavoriteType type, String streamId);

  /// Toggle favorite status. Returns `true` if now favorited.
  Future<Either<Failure, bool>> toggleFavorite(FavoriteItem item);
}
