import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/search_entities.dart';
import '../../domain/repositories/search_repository.dart';

// ── States ──────────────────────────────────────────────────────
sealed class SearchState extends Equatable {
  const SearchState();

  @override
  List<Object?> get props => [];
}

class SearchIdle extends SearchState {
  const SearchIdle();
}

class SearchLoading extends SearchState {
  final String query;
  const SearchLoading(this.query);

  @override
  List<Object?> get props => [query];
}

class SearchReady extends SearchState {
  final String query;
  final SearchResults results;

  const SearchReady({required this.query, required this.results});

  @override
  List<Object?> get props => [query, results];
}

class SearchError extends SearchState {
  final String message;
  const SearchError(this.message);

  @override
  List<Object?> get props => [message];
}

// ── Events ──────────────────────────────────────────────────────
sealed class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => [];
}

class SearchQueryChanged extends SearchEvent {
  final String query;
  const SearchQueryChanged(this.query);

  @override
  List<Object?> get props => [query];
}

class SearchCleared extends SearchEvent {
  const SearchCleared();
}

/// Internal event fired after debounce timer elapses.
class _ExecuteSearch extends SearchEvent {
  final String query;
  const _ExecuteSearch(this.query);

  @override
  List<Object?> get props => [query];
}

// ── BLoC ────────────────────────────────────────────────────────
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final SearchRepository _repository;
  Timer? _debounce;

  /// Debounce delay — wait this long after the user stops typing
  /// before firing the API search.
  static const _debounceDelay = Duration(milliseconds: 500);

  SearchBloc(this._repository) : super(const SearchIdle()) {
    on<SearchQueryChanged>(_onQueryChanged);
    on<SearchCleared>(_onCleared);
    on<_ExecuteSearch>(_onExecuteSearch);
  }

  void _onQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) {
    final query = event.query.trim();

    _debounce?.cancel();

    if (query.isEmpty) {
      emit(const SearchIdle());
      return;
    }

    // Show loading immediately; debounce the actual API call.
    emit(SearchLoading(query));

    _debounce = Timer(_debounceDelay, () {
      add(_ExecuteSearch(query));
    });
  }

  void _onCleared(
    SearchCleared event,
    Emitter<SearchState> emit,
  ) {
    _debounce?.cancel();
    emit(const SearchIdle());
  }

  Future<void> _onExecuteSearch(
    _ExecuteSearch event,
    Emitter<SearchState> emit,
  ) async {
    final result = await _repository.search(event.query);

    result.fold(
      (failure) => emit(SearchError(failure.message)),
      (results) => emit(SearchReady(query: event.query, results: results)),
    );
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
