import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/favorite_entities.dart';
import '../../domain/repositories/favorites_repository.dart';

/// Hive-backed implementation of [FavoritesRepository].
///
/// Stores favorites in a local Hive box, keyed by a composite ID
/// ("${type}_$streamId") so the same streamId can exist under
/// different types (e.g. live channel vs. movie) without collision.
class FavoritesRepositoryImpl implements FavoritesRepository {
  final Box _box;

  FavoritesRepositoryImpl(this._box);

  @override
  Future<Either<Failure, List<FavoriteItem>>> getFavorites({
    FavoriteType? type,
  }) async {
    try {
      final items = <FavoriteItem>[];
      for (final key in _box.keys) {
        final map = _box.get(key) as Map<dynamic, dynamic>?;
        if (map == null) continue;
        final item = FavoriteItem.fromMap(map);
        if (type == null || item.type == type) {
          items.add(item);
        }
      }
      // Sort by name for a consistent list.
      items.sort((a, b) => a.name.compareTo(b.name));
      return Right(items);
    } catch (e) {
      return Left(UnexpectedFailure(message: 'Failed to load favorites: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> isFavorite(
      FavoriteType type, String streamId) async {
    try {
      final id = FavoriteItem.buildId(type, streamId);
      return Right(_box.containsKey(id));
    } catch (e) {
      return Left(UnexpectedFailure(message: 'Failed to check favorite: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> addFavorite(FavoriteItem item) async {
    try {
      await _box.put(item.id, item.toMap());
      return const Right(null);
    } catch (e) {
      return Left(UnexpectedFailure(message: 'Failed to add favorite: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> removeFavorite(
      FavoriteType type, String streamId) async {
    try {
      final id = FavoriteItem.buildId(type, streamId);
      await _box.delete(id);
      return const Right(null);
    } catch (e) {
      return Left(UnexpectedFailure(message: 'Failed to remove favorite: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> toggleFavorite(FavoriteItem item) async {
    try {
      final isFav = _box.containsKey(item.id);
      if (isFav) {
        await _box.delete(item.id);
        return const Right(false);
      } else {
        await _box.put(item.id, item.toMap());
        return const Right(true);
      }
    } catch (e) {
      return Left(UnexpectedFailure(message: 'Failed to toggle favorite: $e'));
    }
  }
}
