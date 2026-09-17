import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/favorite_entities.dart';
import '../../domain/repositories/favorites_repository.dart';

// ── States ──────────────────────────────────────────────────────
sealed class FavoritesState extends Equatable {
  const FavoritesState();

  @override
  List<Object?> get props => [];
}

class FavoritesInitial extends FavoritesState {
  const FavoritesInitial();
}

class FavoritesLoading extends FavoritesState {
  const FavoritesLoading();
}

class FavoritesReady extends FavoritesState {
  final List<FavoriteItem> favorites;
  final FavoriteType? filterType;
  final Set<String> favoritedIds; // quick lookup for "is favorited?" checks
  final String? errorMessage;

  const FavoritesReady({
    required this.favorites,
    this.filterType,
    this.favoritedIds = const {},
    this.errorMessage,
  });

  FavoritesReady copyWith({
    List<FavoriteItem>? favorites,
    FavoriteType? filterType,
    Set<String>? favoritedIds,
    String? errorMessage,
  }) {
    return FavoritesReady(
      favorites: favorites ?? this.favorites,
      filterType: filterType ?? this.filterType,
      favoritedIds: favoritedIds ?? this.favoritedIds,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [favorites, filterType, favoritedIds, errorMessage];
}

class FavoritesError extends FavoritesState {
  final String message;
  const FavoritesError(this.message);

  @override
  List<Object?> get props => [message];
}

// ── Events ──────────────────────────────────────────────────────
sealed class FavoritesEvent extends Equatable {
  const FavoritesEvent();

  @override
  List<Object?> get props => [];
}

class LoadFavorites extends FavoritesEvent {
  final FavoriteType? filterType;
  const LoadFavorites({this.filterType});

  @override
  List<Object?> get props => [filterType];
}

class ToggleFavorite extends FavoritesEvent {
  final FavoriteItem item;
  const ToggleFavorite(this.item);

  @override
  List<Object?> get props => [item];
}

class CheckFavorite extends FavoritesEvent {
  final FavoriteType type;
  final String streamId;
  const CheckFavorite(this.type, this.streamId);

  @override
  List<Object?> get props => [type, streamId];
}

// ── BLoC ────────────────────────────────────────────────────────
class FavoritesBloc extends Bloc<FavoritesEvent, FavoritesState> {
  final FavoritesRepository _repository;

  FavoritesBloc(this._repository) : super(const FavoritesInitial()) {
    on<LoadFavorites>(_onLoadFavorites);
    on<ToggleFavorite>(_onToggleFavorite);
    on<CheckFavorite>(_onCheckFavorite);
  }

  Future<void> _onLoadFavorites(
    LoadFavorites event,
    Emitter<FavoritesState> emit,
  ) async {
    final state = this.state;
    if (state is! FavoritesReady) {
      emit(const FavoritesLoading());
    }

    final result = await _repository.getFavorites(type: event.filterType);

    result.fold(
      (failure) => emit(FavoritesError(failure.message)),
      (favorites) {
        final favoritedIds = favorites.map((f) => f.id).toSet();
        emit(FavoritesReady(
          favorites: favorites,
          filterType: event.filterType,
          favoritedIds: favoritedIds,
        ));
      },
    );
  }

  Future<void> _onToggleFavorite(
    ToggleFavorite event,
    Emitter<FavoritesState> emit,
  ) async {
    final result = await _repository.toggleFavorite(event.item);

    result.fold(
      (failure) {
        final state = this.state;
        if (state is FavoritesReady) {
          emit(state.copyWith(errorMessage: failure.message));
        } else {
          emit(FavoritesError(failure.message));
        }
      },
      (isNowFavorited) {
        // Refresh the favorites list.
        final state = this.state;
        final currentFilter = state is FavoritesReady ? state.filterType : null;
        add(LoadFavorites(filterType: currentFilter));
      },
    );
  }

  Future<void> _onCheckFavorite(
    CheckFavorite event,
    Emitter<FavoritesState> emit,
  ) async {
    final result = await _repository.isFavorite(event.type, event.streamId);

    result.fold(
      (failure) => null, // silently ignore — not critical
      (isFav) {
        final state = this.state;
        if (state is FavoritesReady) {
          final id = FavoriteItem.buildId(event.type, event.streamId);
          final newIds = Set<String>.from(state.favoritedIds);
          if (isFav) {
            newIds.add(id);
          } else {
            newIds.remove(id);
          }
          emit(state.copyWith(favoritedIds: newIds));
        }
      },
    );
  }
}
