import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/series_entities.dart';
import '../../domain/repositories/series_repository.dart';

// ── States ──────────────────────────────────────────────────────
sealed class SeriesState extends Equatable {
  const SeriesState();

  @override
  List<Object?> get props => [];
}

class SeriesInitial extends SeriesState {
  const SeriesInitial();
}

class SeriesLoading extends SeriesState {
  const SeriesLoading();
}

class SeriesReady extends SeriesState {
  final List<SeriesCategory> categories;
  final String? selectedCategoryId;
  final List<SeriesItem> series;
  final bool isLoadingSeries;
  final String? errorMessage;

  const SeriesReady({
    required this.categories,
    this.selectedCategoryId,
    this.series = const [],
    this.isLoadingSeries = false,
    this.errorMessage,
  });

  SeriesReady copyWith({
    List<SeriesCategory>? categories,
    String? selectedCategoryId,
    List<SeriesItem>? series,
    bool? isLoadingSeries,
    String? errorMessage,
  }) {
    return SeriesReady(
      categories: categories ?? this.categories,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      series: series ?? this.series,
      isLoadingSeries: isLoadingSeries ?? this.isLoadingSeries,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        categories, selectedCategoryId, series, isLoadingSeries, errorMessage,
      ];
}

class SeriesError extends SeriesState {
  final String message;
  const SeriesError(this.message);

  @override
  List<Object?> get props => [message];
}

// ── Events ──────────────────────────────────────────────────────
sealed class SeriesEvent extends Equatable {
  const SeriesEvent();

  @override
  List<Object?> get props => [];
}

class LoadSeriesCategories extends SeriesEvent {
  const LoadSeriesCategories();
}

class SelectSeriesCategory extends SeriesEvent {
  final String categoryId;
  const SelectSeriesCategory(this.categoryId);

  @override
  List<Object?> get props => [categoryId];
}

class RefreshSeries extends SeriesEvent {
  const RefreshSeries();
}

// ── BLoC ────────────────────────────────────────────────────────
class SeriesBloc extends Bloc<SeriesEvent, SeriesState> {
  final SeriesRepository _repository;

  SeriesBloc(this._repository) : super(const SeriesInitial()) {
    on<LoadSeriesCategories>(_onLoadCategories);
    on<SelectSeriesCategory>(_onSelectCategory);
    on<RefreshSeries>(_onRefreshSeries);
  }

  Future<void> _onLoadCategories(
    LoadSeriesCategories event,
    Emitter<SeriesState> emit,
  ) async {
    emit(const SeriesLoading());

    final result = await _repository.getCategories();

    result.fold(
      (failure) => emit(SeriesError(failure.message)),
      (categories) {
        emit(SeriesReady(categories: categories));
        add(const SelectSeriesCategory('__all__'));
      },
    );
  }

  Future<void> _onSelectCategory(
    SelectSeriesCategory event,
    Emitter<SeriesState> emit,
  ) async {
    final state = this.state;
    if (state is! SeriesReady) return;

    final categoryId =
        event.categoryId == '__all__' ? null : event.categoryId;

    emit(state.copyWith(
      selectedCategoryId: event.categoryId,
      isLoadingSeries: true,
      errorMessage: null,
      series: [],
    ));

    final result = await _repository.getSeries(categoryId: categoryId);

    result.fold(
      (failure) => emit(state.copyWith(
        isLoadingSeries: false,
        errorMessage: failure.message,
      )),
      (series) => emit(state.copyWith(
        series: series,
        isLoadingSeries: false,
      )),
    );
  }

  Future<void> _onRefreshSeries(
    RefreshSeries event,
    Emitter<SeriesState> emit,
  ) async {
    final state = this.state;
    if (state is! SeriesReady) return;
    final catId = state.selectedCategoryId ?? '__all__';
    add(SelectSeriesCategory(catId));
  }
}
