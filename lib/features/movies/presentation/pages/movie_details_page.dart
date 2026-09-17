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
import '../../domain/entities/movie_entities.dart';
import '../../domain/repositories/movies_repository.dart';
import '../bloc/movies_bloc.dart';
import '../../../favorites/domain/entities/favorite_entities.dart';
import '../../../favorites/presentation/bloc/favorites_bloc.dart';
import '../../../player/domain/entities/player_entities.dart';

/// Movie details page — shows full poster, plot, cast, director,
/// rating, a play button, and a favorite toggle.
class MovieDetailsPage extends StatefulWidget {
  final Movie movie;

  const MovieDetailsPage({super.key, required this.movie});

  @override
  State<MovieDetailsPage> createState() => _MovieDetailsPageState();
}

class _MovieDetailsPageState extends State<MovieDetailsPage> {
  Movie? _movieInfo;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMovieInfo();
  }

  Future<void> _loadMovieInfo() async {
    final repo = getIt<MoviesRepository>();
    final result = await repo.getMovieInfo(widget.movie.streamId);

    result.fold(
      (failure) => setState(() {
        _error = failure.message;
        _isLoading = false;
      }),
      (movie) => setState(() {
        _movieInfo = movie;
        _isLoading = false;
      }),
    );
  }

  void _playMovie() {
    final serverConfig = getIt<ServerConfig>();
    final movie = _movieInfo ?? widget.movie;
    final url = StreamUrlBuilder.vod(
      baseUrl: serverConfig.baseUrl,
      username: serverConfig.username,
      password: serverConfig.password,
      streamId: movie.streamId,
      containerExtension: movie.containerExtension ?? 'mp4',
    );

    context.push(
      AppRoutes.moviePlayer,
      extra: PlayerConfig(
        url: url,
        title: movie.name,
        contentType: PlayerContentType.vod,
      ),
    );
  }

  void _toggleFavorite() {
    final movie = _movieInfo ?? widget.movie;
    final favId = FavoriteItem.buildId(FavoriteType.movie, movie.streamId);
    context.read<FavoritesBloc>().add(
          ToggleFavorite(FavoriteItem(
            id: favId,
            type: FavoriteType.movie,
            streamId: movie.streamId,
            name: movie.name,
            imageUrl: movie.streamIcon,
            extra: movie.containerExtension ?? 'mp4',
          )),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final movie = _movieInfo ?? widget.movie;
    final favId = FavoriteItem.buildId(FavoriteType.movie, movie.streamId);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Poster as app bar background
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
                  if (movie.streamIcon != null && movie.streamIcon!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: movie.streamIcon!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.movie, size: 48),
                      ),
                    )
                  else
                    Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.movie, size: 48),
                    ),
                  // Gradient overlay
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
                  // Title
                  Text(
                    movie.name,
                    style: theme.textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  // Meta row: rating, year, genre
                  _buildMetaRow(theme, movie),
                  const SizedBox(height: 24),
                  // Play + Favorite buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _playMovie,
                          icon: const Icon(Icons.play_arrow, size: 28),
                          label: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child:
                                Text('Play', style: TextStyle(fontSize: 18)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                  const SizedBox(height: 24),
                  // Loading or details
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: LoadingWidget(message: 'Loading details…'),
                    )
                  else if (_error != null)
                    ErrorStateWidget(
                      failure: UnexpectedFailure(message: _error!),
                      onRetry: () {
                        setState(() {
                          _error = null;
                          _isLoading = true;
                        });
                        _loadMovieInfo();
                      },
                    )
                  else ...[
                    // Plot
                    if (movie.plot != null && movie.plot!.isNotEmpty) ...[
                      Text('Overview',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(
                        movie.plot!,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                    ],
                    // Cast & Director
                    _buildInfoRow(theme, 'Director', movie.director),
                    _buildInfoRow(theme, 'Cast', movie.cast),
                    _buildInfoRow(theme, 'Genre', movie.genre),
                    _buildInfoRow(theme, 'Released', movie.releasedate),
                    const SizedBox(height: 40),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(ThemeData theme, Movie movie) {
    final chips = <Widget>[];

    if (movie.rating != null &&
        movie.rating!.isNotEmpty &&
        movie.rating != 'N/A') {
      chips.add(_metaChip(theme, Icons.star, movie.rating!, Colors.amber));
    }
    if (movie.releasedate != null && movie.releasedate!.isNotEmpty) {
      chips.add(_metaChip(theme, Icons.calendar_today, movie.releasedate!));
    }
    if (movie.genre != null && movie.genre!.isNotEmpty) {
      chips.add(_metaChip(theme, Icons.category, movie.genre!));
    }
    if (movie.duration != null && movie.duration! > 0) {
      chips.add(
          _metaChip(theme, Icons.access_time, '${movie.duration} min'));
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

  Widget _buildInfoRow(ThemeData theme, String label, String? value) {
    if (value == null || value.isEmpty || value == 'N/A') {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
