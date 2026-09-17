import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/server_config.dart';
import '../../../../core/utils/stream_url_builder.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../player/domain/entities/player_entities.dart';
import '../../domain/entities/favorite_entities.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../bloc/favorites_bloc.dart';
import '../widgets/favorite_tile.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Use the global FavoritesBloc from main.dart and refresh on visit.
    context.read<FavoritesBloc>().add(const LoadFavorites());
    return const _FavoritesView();
  }
}

class _FavoritesView extends StatelessWidget {
  const _FavoritesView();

  void _openFavorite(BuildContext context, FavoriteItem item) {
    final serverConfig = getIt<ServerConfig>();

    switch (item.type) {
      case FavoriteType.live:
        final url = StreamUrlBuilder.live(
          baseUrl: serverConfig.baseUrl,
          username: serverConfig.username,
          password: serverConfig.password,
          streamId: item.streamId,
        );
        context.push(
          AppRoutes.livePlayer,
          extra: PlayerConfig(
            url: url,
            title: item.name,
            contentType: PlayerContentType.live,
          ),
        );

      case FavoriteType.movie:
        final url = StreamUrlBuilder.vod(
          baseUrl: serverConfig.baseUrl,
          username: serverConfig.username,
          password: serverConfig.password,
          streamId: item.streamId,
          containerExtension: item.extra ?? 'mp4',
        );
        context.push(
          AppRoutes.moviePlayer,
          extra: PlayerConfig(
            url: url,
            title: item.name,
            contentType: PlayerContentType.vod,
          ),
        );

      case FavoriteType.series:
        // Series favorites need the series details page for episode selection.
        // We push the series player directly if we have enough info.
        // In practice, series favorites are best opened from the Series tab.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Open series favorites from the Series tab to choose an episode'),
            duration: Duration(seconds: 2),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
      ),
      body: Column(
        children: [
          // Filter chips
          _buildFilterBar(context),
          // List
          Expanded(
            child: BlocBuilder<FavoritesBloc, FavoritesState>(
              buildWhen: (prev, curr) =>
                  curr is FavoritesReady || curr is FavoritesLoading,
              builder: (context, state) {
                return switch (state) {
                  FavoritesInitial() || FavoritesLoading() =>
                    const LoadingWidget(message: 'Loading favorites…'),
                  FavoritesError() => ErrorStateWidget(
                      failure: UnexpectedFailure(message: state.message),
                      onRetry: () => context
                          .read<FavoritesBloc>()
                          .add(const LoadFavorites()),
                    ),
                  FavoritesReady() => switch (state) {
                      _ when state.favorites.isEmpty =>
                        const EmptyStateWidget(
                          icon: Icons.favorite_border,
                          message:
                              'No favorites yet — tap the heart on any channel or movie',
                        ),
                      _ => ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          cacheExtent: 500,
                          itemCount: state.favorites.length,
                          itemBuilder: (context, index) {
                            final item = state.favorites[index];
                            return FavoriteTile(
                              item: item,
                              onTap: () => _openFavorite(context, item),
                              onRemove: () {
                                context.read<FavoritesBloc>().add(
                                      ToggleFavorite(item),
                                    );
                              },
                            );
                          },
                        ),
                    },
                };
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<FavoritesBloc, FavoritesState>(
      buildWhen: (prev, curr) =>
          curr is FavoritesReady && prev is! FavoritesReady ||
          (prev is FavoritesReady &&
              curr is FavoritesReady &&
              prev.filterType != curr.filterType),
      builder: (context, state) {
        final currentFilter = state is FavoritesReady ? state.filterType : null;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _filterChip(
                context,
                'All',
                null,
                currentFilter,
                theme,
              ),
              const SizedBox(width: 8),
              _filterChip(
                context,
                'Live',
                FavoriteType.live,
                currentFilter,
                theme,
              ),
              const SizedBox(width: 8),
              _filterChip(
                context,
                'Movies',
                FavoriteType.movie,
                currentFilter,
                theme,
              ),
              const SizedBox(width: 8),
              _filterChip(
                context,
                'Series',
                FavoriteType.series,
                currentFilter,
                theme,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _filterChip(
    BuildContext context,
    String label,
    FavoriteType? type,
    FavoriteType? currentFilter,
    ThemeData theme,
  ) {
    final isSelected = currentFilter == type;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        context.read<FavoritesBloc>().add(LoadFavorites(filterType: type));
      },
      selectedColor: theme.colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: isSelected
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}
