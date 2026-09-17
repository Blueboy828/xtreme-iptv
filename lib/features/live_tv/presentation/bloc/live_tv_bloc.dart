import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/live_entities.dart';
import '../../domain/repositories/live_repository.dart';
import '../../../epg/domain/repositories/epg_repository.dart';
import '../../../epg/domain/entities/epg_entities.dart';
import '../../../../core/utils/date_time_utils.dart';

// ── States ──────────────────────────────────────────────────────
sealed class LiveTvState extends Equatable {
  const LiveTvState();

  @override
  List<Object?> get props => [];
}

class LiveTvInitial extends LiveTvState {
  const LiveTvInitial();
}

class LiveTvLoading extends LiveTvState {
  const LiveTvLoading();
}

class LiveTvReady extends LiveTvState {
  final List<LiveCategory> categories;
  final String? selectedCategoryId;
  final List<LiveChannel> channels;
  final bool isLoadingChannels;
  final Map<String, EpgNowNext> epgCache;  // streamId → EPG now/next
  final Set<String> loadingEpgIds;          // streamIds currently fetching EPG
  final Map<String, DateTime> epgFetchedAt; // streamId → when its EPG was last refreshed
  final Map<String, List<EpgEntry>> scheduleCache; // streamId → upcoming programs (full guide)
  final String? errorMessage;

  const LiveTvReady({
    required this.categories,
    this.selectedCategoryId,
    this.channels = const [],
    this.isLoadingChannels = false,
    this.epgCache = const {},
    this.loadingEpgIds = const {},
    this.epgFetchedAt = const {},
    this.scheduleCache = const {},
    this.errorMessage,
  });

  /// True if this channel's EPG is missing or stale and should be re-fetched.
  /// Stale means: never fetched, fetched more than 10 minutes ago, or the
  /// program shown as "now" has already ended (times resolved via the
  /// calibrated EPG clock).
  bool needsEpgRefresh(String streamId) {
    if (loadingEpgIds.contains(streamId)) return false;
    final epg = epgCache[streamId];
    if (epg == null) return true;
    final fetched = epgFetchedAt[streamId];
    if (fetched == null) return true;
    if (DateTime.now().difference(fetched) >= const Duration(minutes: 10)) {
      return true;
    }
    if (epg.now != null && DateTimeUtils.epgEntryEnded(epg.now!.end)) {
      return true;
    }
    return false;
  }

  LiveTvReady copyWith({
    List<LiveCategory>? categories,
    String? selectedCategoryId,
    List<LiveChannel>? channels,
    bool? isLoadingChannels,
    Map<String, EpgNowNext>? epgCache,
    Set<String>? loadingEpgIds,
    Map<String, DateTime>? epgFetchedAt,
    Map<String, List<EpgEntry>>? scheduleCache,
    String? errorMessage,
  }) {
    return LiveTvReady(
      categories: categories ?? this.categories,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      channels: channels ?? this.channels,
      isLoadingChannels: isLoadingChannels ?? this.isLoadingChannels,
      epgCache: epgCache ?? this.epgCache,
      loadingEpgIds: loadingEpgIds ?? this.loadingEpgIds,
      epgFetchedAt: epgFetchedAt ?? this.epgFetchedAt,
      scheduleCache: scheduleCache ?? this.scheduleCache,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        categories, selectedCategoryId, channels, isLoadingChannels,
        epgCache, loadingEpgIds, epgFetchedAt, scheduleCache, errorMessage,
      ];
}

class LiveTvError extends LiveTvState {
  final String message;
  const LiveTvError(this.message);

  @override
  List<Object?> get props => [message];
}

// ── Events ──────────────────────────────────────────────────────
sealed class LiveTvEvent extends Equatable {
  const LiveTvEvent();

  @override
  List<Object?> get props => [];
}

class LoadCategories extends LiveTvEvent {
  const LoadCategories();
}

class SelectCategory extends LiveTvEvent {
  final String categoryId;
  const SelectCategory(this.categoryId);

  @override
  List<Object?> get props => [categoryId];
}

class LoadEpgForChannel extends LiveTvEvent {
  final String streamId;

  /// When true, also downloads the channel's full program list and computes
  /// "now" using the device clock (used for the selected channel's preview
  /// and full schedule). Otherwise only the light now/next snapshot is used.
  final bool includeFullSchedule;

  const LoadEpgForChannel(this.streamId, {this.includeFullSchedule = false});

  @override
  List<Object?> get props => [streamId, includeFullSchedule];
}

class RefreshChannels extends LiveTvEvent {
  const RefreshChannels();
}

// ── Helpers ─────────────────────────────────────────────────────
/// Result of resolving the full program list against the device clock.
class _ResolvedGuide {
  final EpgNowNext nowNext;
  final List<EpgEntry> upcoming;
  const _ResolvedGuide(this.nowNext, this.upcoming);
}

// ── BLoC ────────────────────────────────────────────────────────
class LiveTvBloc extends Bloc<LiveTvEvent, LiveTvState> {
  final LiveRepository _liveRepository;
  final EpgRepository _epgRepository;

  LiveTvBloc(this._liveRepository, this._epgRepository)
      : super(const LiveTvInitial()) {
    on<LoadCategories>(_onLoadCategories);
    on<SelectCategory>(_onSelectCategory);
    on<LoadEpgForChannel>(_onLoadEpg);
    on<RefreshChannels>(_onRefreshChannels);
  }

  Future<void> _onLoadCategories(
    LoadCategories event,
    Emitter<LiveTvState> emit,
  ) async {
    emit(const LiveTvLoading());

    final result = await _liveRepository.getCategories();

    result.fold(
      (failure) => emit(LiveTvError(failure.message)),
      (categories) {
        // Auto-select "All" or first category.
        emit(LiveTvReady(
          categories: categories,
          selectedCategoryId: null, // null = all channels
        ));
        // Auto-load channels for "all" (no category filter).
        add(const SelectCategory('__all__'));
      },
    );
  }

  Future<void> _onSelectCategory(
    SelectCategory event,
    Emitter<LiveTvState> emit,
  ) async {
    final state = this.state;
    if (state is! LiveTvReady) return;

    final categoryId =
        event.categoryId == '__all__' ? null : event.categoryId;

    emit(state.copyWith(
      selectedCategoryId: event.categoryId,
      isLoadingChannels: true,
      errorMessage: null,
      channels: [],  // Clear while loading.
    ));

    final result = await _liveRepository.getChannels(categoryId: categoryId);

    result.fold(
      (failure) => emit(state.copyWith(
        isLoadingChannels: false,
        errorMessage: failure.message,
      )),
      (channels) => emit(state.copyWith(
        channels: channels,
        isLoadingChannels: false,
      )),
    );
  }

  Future<void> _onLoadEpg(
    LoadEpgForChannel event,
    Emitter<LiveTvState> emit,
  ) async {
    final state = this.state;
    if (state is! LiveTvReady) return;

    // Skip if fresh or currently loading (previously this was cached forever,
    // which froze the guide on the program that was live at first fetch).
    if (!state.needsEpgRefresh(event.streamId)) {
      return;
    }

    // Mark as loading.
    emit(state.copyWith(
      loadingEpgIds: {...state.loadingEpgIds, event.streamId},
    ));

    // 1. Short EPG: the server's idea of "now/next". Also calibrates the
    //    EPG clock (UTC vs provider-local) inside the repository.
    final shortResult = await _epgRepository.getShortEpg(event.streamId);

    // 2. Optional full guide: download the channel's program list and let
    //    the DEVICE CLOCK decide what is on now — the same philosophy used
    //    by IPTV Smarters. This makes us immune to a broken/stale short-EPG
    //    endpoint on the provider's side.
    EpgNowNext? resolved;
    List<EpgEntry> upcoming = const [];
    if (event.includeFullSchedule) {
      final fullResult = await _epgRepository.getFullEpg(event.streamId);
      fullResult.fold(
        (_) {}, // fall back to the short snapshot below
        (entries) {
          final guide = _resolveGuideFromFullList(entries);
          if (guide != null) {
            resolved = guide.nowNext;
            upcoming = guide.upcoming;
          }
        },
      );
    }

    final currentState = this.state as LiveTvReady;

    shortResult.fold(
      (failure) {
        if (resolved != null) {
          // Full list worked even though the snapshot failed — use it.
          emit(currentState.copyWith(
            epgCache: {...currentState.epgCache, event.streamId: resolved!},
            epgFetchedAt: {
              ...currentState.epgFetchedAt,
              event.streamId: DateTime.now(),
            },
            scheduleCache: {
              ...currentState.scheduleCache,
              event.streamId: upcoming,
            },
            loadingEpgIds: currentState.loadingEpgIds..remove(event.streamId),
          ));
        } else {
          emit(currentState.copyWith(
            loadingEpgIds: currentState.loadingEpgIds..remove(event.streamId),
          ));
        }
      },
      (shortEpg) {
        // Device-clock result wins; the short snapshot is the fallback.
        emit(currentState.copyWith(
          epgCache: {...currentState.epgCache, event.streamId: resolved ?? shortEpg},
          epgFetchedAt: {
            ...currentState.epgFetchedAt,
            event.streamId: DateTime.now(),
          },
          scheduleCache: {
            ...currentState.scheduleCache,
            event.streamId: upcoming,
          },
          loadingEpgIds: currentState.loadingEpgIds..remove(event.streamId),
        ));
      },
    );
  }

  /// Finds the program on right now using the device clock, plus what's
  /// coming up next. Returns null if the list can't be matched (e.g. a gap
  /// in the provider's data covering the current time).
  _ResolvedGuide? _resolveGuideFromFullList(List<EpgEntry> entries) {
    if (entries.isEmpty) return null;

    // Sort chronologically (providers occasionally return unsorted lists).
    final sorted = [...entries]..sort((a, b) {
        final sa = DateTimeUtils.parseEpgDateTime(a.start);
        final sb = DateTimeUtils.parseEpgDateTime(b.start);
        if (sa == null && sb == null) return 0;
        if (sa == null) return 1;
        if (sb == null) return -1;
        return sa.compareTo(sb);
      });

    final now = DateTime.now();
    for (var i = 0; i < sorted.length; i++) {
      final start = DateTimeUtils.parseEpgDateTime(sorted[i].start);
      final end = DateTimeUtils.parseEpgDateTime(sorted[i].end);
      if (start == null || end == null) continue;
      // The program whose window contains "right now" is on now.
      if (!now.isBefore(start) && now.isBefore(end)) {
        final next = (i + 1 < sorted.length) ? sorted[i + 1] : null;
        final upcoming = sorted.skip(i + 1).take(10).toList();
        return _ResolvedGuide(EpgNowNext(now: sorted[i], next: next), upcoming);
      }
    }

    // No window contains "now" (data gap). Show the next future program so
    // the preview isn't empty, but report no "now" — the caller falls back
    // to the short snapshot for the now/next headline.
    for (final entry in sorted) {
      final start = DateTimeUtils.parseEpgDateTime(entry.start);
      if (start != null && now.isBefore(start)) {
        final upcoming =
            sorted.where((e) {
              final s = DateTimeUtils.parseEpgDateTime(e.start);
              return s != null && s.isAfter(now);
            }).take(10).toList();
        return _ResolvedGuide(const EpgNowNext(), upcoming);
      }
    }
    return null;
  }

  Future<void> _onRefreshChannels(
    RefreshChannels event,
    Emitter<LiveTvState> emit,
  ) async {
    final state = this.state;
    if (state is! LiveTvReady) return;

    // Re-trigger category selection to reload channels.
    final catId = state.selectedCategoryId ?? '__all__';
    add(SelectCategory(catId));
  }
}
