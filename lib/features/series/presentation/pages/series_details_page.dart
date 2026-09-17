import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/server_config.dart';
import '../../../../core/utils/stream_url_builder.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../domain/entities/series_entities.dart';
import '../../domain/repositories/series_repository.dart';
import '../../../favorites/domain/entities/favorite_entities.dart';
import '../../../favorites/presentation/bloc/favorites_bloc.dart';
import '../../../player/domain/entities/player_entities.dart';

/// Series details page — shows cover, plot, favorite toggle, and an
/// expandable list of seasons with their episodes. Tapping an episode plays it.
class SeriesDetailsPage extends StatefulWidget {
  final SeriesItem series;

  const SeriesDetailsPage({super.key, required this.series});

  @override
  State<SeriesDetailsPage> createState() => _SeriesDetailsPageState();
}

class _SeriesDetailsPageState extends State<SeriesDetailsPage> {
  SeriesItem? _info;
  List<SeriesSeason> _seasons = [];
  bool _isLoading = true;
  String? _error;
  String? _expandedSeason;

  @override
  void initState() {
    super.initState();
    _loadSeriesInfo();
  }

  Future<void> _loadSeriesInfo() async {
    final repo = getIt<SeriesRepository>();
    final result = await repo.getSeriesInfo(widget.series.seriesId);

    result.fold(
      (failure) => setState(() {
        _error = failure.message;
        _isLoading = false;
      }),
      (data) => setState(() {
        _info = data.info;
        _seasons = data.seasons;
        _expandedSeason =
            _seasons.isNotEmpty ? _seasons.first.seasonNumber : null;
        _isLoading = false;
      }),
    );
  }

  void _playEpisode(SeriesEpisode episode) {
    final serverConfig = getIt<ServerConfig>();
    final url = StreamUrlBuilder.series(
      baseUrl: serverConfig.baseUrl,
      username: serverConfig.username,
      password: serverConfig.password,
      episodeId: episode.episodeId,
      containerExtension: episode.containerExtension ?? 'mp4',
    );

    context.push(
      AppRoutes.seriesPlayer,
      extra: PlayerConfig(
        url: url,
        title: _info?.name ?? widget.series.name,
        subtitle: 'S${episode.season}E${episode.episodeNum} — ${episode.title}',
        contentType: PlayerContentType.series,
      ),
    );
  }

  void _toggleFavorite() {
    final series = _info ?? widget.series;
    final favId = FavoriteItem.buildId(FavoriteType.series, series.seriesId);
    context.read<FavoritesBloc>().add(
          ToggleFavorite(FavoriteItem(
            id: favId,
            type: FavoriteType.series,
            streamId: series.seriesId,
            name: series.name,
            imageUrl: series.cover,
          )),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final series = _info ?? widget.series;
    final favId = FavoriteItem.buildId(FavoriteType.series, series.seriesId);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Cover as app bar background
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            actions: [
              BlocBuilder<FavoritesBloc, FavoritesState>(
                buildWhen: (prev, curr) {
                  if (curr is! FavoritesReady) return false;
                  final prevReady = prev is FavoritesReady ? prev : null;
                  return prevReady == null ||
                      prevReady.favoritedIds.contains(favId) !=
                          curr.favoritedIds.contains(favId);
                },
                builder: (context, state) {
                  final isFav = state is FavoritesReady &&
                      state.favoritedIds.contains(favId);
                  return IconButton(
                    icon: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      color: isFav ? Colors.red : Colors.white,
                    ),
                    onPressed: _toggleFavorite,
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (series.cover != null && series.cover!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: series.cover!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.tv, size: 48),
                      ),
                    )
                  else
                    Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.tv, size: 48),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          theme.colorScheme.surface.withValues(alpha: 0.8),
                          theme.colorScheme.surface,
                        ],
                        stops: const [0.3, 0.8, 1],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + favorite row
                  Row(
                    children: [
                      Expanded(
                        child: Text(series.name,
                            style: theme.textTheme.headlineLarge),
                      ),
                      BlocBuilder<FavoritesBloc, FavoritesState>(
                        buildWhen: (prev, curr) {
                          if (curr is! FavoritesReady) return false;
                          final prevReady =
                              prev is FavoritesReady ? prev : null;
                          return prevReady == null ||
                              prevReady.favoritedIds.contains(favId) !=
                                  curr.favoritedIds.contains(favId);
                        },
                        builder: (context, state) {
                          final isFav = state is FavoritesReady &&
                              state.favoritedIds.contains(favId);
                          return OutlinedButton.icon(
                            onPressed: _toggleFavorite,
                            icon: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              color: isFav ? Colors.red : null,
                            ),
                            label: Text(isFav ? 'Saved' : 'Save'),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Meta chips
                  _buildMetaRow(theme, series),
                  const SizedBox(height: 16),
                  // Plot
                  if (series.plot != null && series.plot!.isNotEmpty) ...[
                    Text('Overview',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(series.plot!, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 24),
                  ],
                  // Seasons header
                  Text('Seasons',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontSize: 18)),
                  const SizedBox(height: 12),
                  // Loading / Error / Seasons list
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: LoadingWidget(message: 'Loading seasons…'),
                    )
                  else if (_error != null)
                    ErrorStateWidget(
                      failure: UnexpectedFailure(message: _error!),
                      onRetry: () {
                        setState(() {
                          _error = null;
                          _isLoading = true;
                        });
                        _loadSeriesInfo();
                      },
                    )
                  else if (_seasons.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('No episodes available'),
                      ),
                    )
                  else
                    _buildSeasonsList(theme),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(ThemeData theme, SeriesItem series) {
    final chips = <Widget>[];

    if (series.rating != null &&
        series.rating!.isNotEmpty &&
        series.rating != 'N/A') {
      chips.add(_metaChip(theme, Icons.star, series.rating!, Colors.amber));
    }
    if (series.releaseDate != null && series.releaseDate!.isNotEmpty) {
      chips.add(_metaChip(theme, Icons.calendar_today, series.releaseDate!));
    }
    if (series.genre != null && series.genre!.isNotEmpty) {
      chips.add(_metaChip(theme, Icons.category, series.genre!));
    }
    if (series.episodeCount != null && series.episodeCount! > 0) {
      chips.add(_metaChip(
          theme, Icons.tv, '${series.episodeCount} episodes'));
    }

    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _metaChip(
    ThemeData theme,
    IconData icon,
    String label, [
    Color? iconColor,
  ]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor ?? theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildSeasonsList(ThemeData theme) {
    return Column(
      children: _seasons.map((season) {
        final isExpanded = _expandedSeason == season.seasonNumber;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Column(
            children: [
              // Season header (tap to expand/collapse)
              ListTile(
                leading: Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 28,
                  color: theme.colorScheme.primary,
                ),
                title: Text(
                  'Season ${season.seasonNumber}',
                  style: theme.textTheme.titleMedium,
                ),
                trailing: Text(
                  '${season.episodes.length} episodes',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                onTap: () {
                  setState(() {
                    _expandedSeason =
                        isExpanded ? null : season.seasonNumber;
                  });
                },
              ),
              // Episode list (animated expand/collapse)
              if (isExpanded)
                ...season.episodes.map((episode) {
                  return Column(
                    children: [
                      Divider(
                        height: 1,
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.3),
                      ),
                      ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              theme.colorScheme.primaryContainer,
                          child: Text(
                            episode.episodeNum,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        title: Text(
                          episode.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                        trailing: Icon(
                          Icons.play_circle_fill,
                          color: theme.colorScheme.primary,
                          size: 28,
                        ),
                        onTap: () => _playEpisode(episode),
                      ),
                    ],
                  );
                }),
            ],
          ),
        );
      }).toList(),
    );
  }
}
