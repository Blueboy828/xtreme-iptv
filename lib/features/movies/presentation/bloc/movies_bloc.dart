import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/movie_entities.dart';
import '../../domain/repositories/movies_repository.dart';

// ── States ──────────────────────────────────────────────────────
sealed class MoviesState extends Equatable {
  const MoviesState();

  @override
  List<Object?> get props => [];
}

class MoviesInitial extends MoviesState {
  const MoviesInitial();
}

class MoviesLoading extends MoviesState {
  const MoviesLoading();
}

class MoviesReady extends MoviesState {
  final List<MovieCategory> categories;
  final String? selectedCategoryId;
  final List<Movie> movies;
  final bool isLoadingMovies;
  final String? errorMessage;

  const MoviesReady({
    required this.categories,
    this.selectedCategoryId,
    this.movies = const [],
    this.isLoadingMovies = false,
    this.errorMessage,
  });

  MoviesReady copyWith({
    List<MovieCategory>? categories,
    String? selectedCategoryId,
    List<Movie>? movies,
    bool? isLoadingMovies,
    String? errorMessage,
  }) {
    return MoviesReady(
      categories: categories ?? this.categories,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      movies: movies ?? this.movies,
      isLoadingMovies: isLoadingMovies ?? this.isLoadingMovies,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        categories, selectedCategoryId, movies, isLoadingMovies, errorMessage,
      ];
}

class MoviesError extends MoviesState {
  final String message;
  const MoviesError(this.message);

  @override
  List<Object?> get props => [message];
}

// ── Events ──────────────────────────────────────────────────────
sealed class MoviesEvent extends Equatable {
  const MoviesEvent();

  @override
  List<Object?> get props => [];
}

class LoadMovieCategories extends MoviesEvent {
  const LoadMovieCategories();
}

class SelectMovieCategory extends MoviesEvent {
  final String categoryId;
  const SelectMovieCategory(this.categoryId);

  @override
  List<Object?> get props => [categoryId];
}

class RefreshMovies extends MoviesEvent {
  const RefreshMovies();
}

// ── BLoC ────────────────────────────────────────────────────────
class MoviesBloc extends Bloc<MoviesEvent, MoviesState> {
  final MoviesRepository _repository;

  MoviesBloc(this._repository) : super(const MoviesInitial()) {
    on<LoadMovieCategories>(_onLoadCategories);
    on<SelectMovieCategory>(_onSelectCategory);
    on<RefreshMovies>(_onRefreshMovies);
  }

  Future<void> _onLoadCategories(
    LoadMovieCategories event,
    Emitter<MoviesState> emit,
  ) async {
    emit(const MoviesLoading());

    final result = await _repository.getCategories();

    result.fold(
      (failure) => emit(MoviesError(failure.message)),
      (categories) {
        emit(MoviesReady(categories: categories));
        add(const SelectMovieCategory('__all__'));
      },
    );
  }

  Future<void> _onSelectCategory(
    SelectMovieCategory event,
    Emitter<MoviesState> emit,
  ) async {
    final state = this.state;
    if (state is! MoviesReady) return;

    final categoryId =
        event.categoryId == '__all__' ? null : event.categoryId;

    emit(state.copyWith(
      selectedCategoryId: event.categoryId,
      isLoadingMovies: true,
      errorMessage: null,
      movies: [],
    ));

    final result = await _repository.getMovies(categoryId: categoryId);

    result.fold(
      (failure) => emit(state.copyWith(
        isLoadingMovies: false,
        errorMessage: failure.message,
      )),
      (movies) => emit(state.copyWith(
        movies: movies,
        isLoadingMovies: false,
      )),
    );
  }

  Future<void> _onRefreshMovies(
    RefreshMovies event,
    Emitter<MoviesState> emit,
  ) async {
    final state = this.state;
    if (state is! MoviesReady) return;
    final catId = state.selectedCategoryId ?? '__all__';
    add(SelectMovieCategory(catId));
  }
}
