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
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/widgets/shimmer_grid.dart';
import '../../../../core/widgets/tv_focusable.dart';
import '../../domain/entities/movie_entities.dart';
import '../../../favorites/domain/entities/favorite_entities.dart';
import '../../../favorites/presentation/bloc/favorites_bloc.dart';
import '../../../player/domain/entities/player_entities.dart';
import '../bloc/movies_bloc.dart';
import '../pages/movie_details_page.dart';

class MoviesPage extends StatelessWidget {
  const MoviesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _MoviesView();
  }
}

class _MoviesView extends StatefulWidget {
  const _MoviesView();

  @override
  State<_MoviesView> createState() => _MoviesViewState();
}

class _MoviesViewState extends State<_MoviesView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  Movie? _selectedMovie;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showFavorites = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _playMovie(Movie movie) {
    final serverConfig = getIt<ServerConfig>();
    final url = StreamUrlBuilder.vod(
      baseUrl: serverConfig.baseUrl,
      username: serverConfig.username,
      password: serverConfig.password,
      streamId: movie.streamId,
      containerExtension: movie.containerExtension ?? 'mp4',
    );
    context.push(AppRoutes.moviePlayer,
      extra: PlayerConfig(url: url, title: movie.name, contentType: PlayerContentType.vod));
  }

  void _openDetails(Movie movie) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => MovieDetailsPage(movie: movie)));
  }

  void _scrollToFocused(int index) {
    if (_scrollController.hasClients) {
      final target = index * 64.0;
      _scrollController.animateTo(target.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // TV app — always use the three-panel wide layout

    return Scaffold(
      appBar: AppBar(title: const Text('Movies')),
      body: BlocConsumer<MoviesBloc, MoviesState>(
        listenWhen: (prev, curr) => curr is MoviesReady && prev is! MoviesReady,
        listener: (context, state) {
          if (state is MoviesReady && state.movies.isNotEmpty && _selectedMovie == null) {
            setState(() => _selectedMovie = state.movies.first);
          }
        },
        builder: (context, state) {
          return switch (state) {
            MoviesInitial() => const LoadingWidget(message: 'Loading…'),
            MoviesLoading() => const ShimmerGrid(),
            MoviesError() => ErrorStateWidget(
                failure: UnexpectedFailure(message: state.message),
                onRetry: () => context.read<MoviesBloc>().add(const LoadMovieCategories())),
            MoviesReady() => (true)
                ? _buildWideLayout(context, state)
                : _buildNarrowLayout(context, state),
          };
        },
      ),
    );
  }

  Widget _buildWideLayout(BuildContext context, MoviesReady state) {
    return Row(children: [
        SizedBox(width: 200, child: _buildCategorySidebar(context, state)),
        const VerticalDivider(width: 1),
        SizedBox(width: 320, child: _buildMovieList(context, state)),
        const VerticalDivider(width: 1),
        Expanded(child: _buildPreview(context, state)),
    ]);
  }

  Widget _buildNarrowLayout(BuildContext context, MoviesReady state) {
    return Scaffold(
      drawer: Drawer(child: _buildCategorySidebar(context, state)),
      body: Column(children: [
        _buildCategoryBar(context, state),
        Expanded(child: _buildMovieGrid(context, state)),
      ]),
    );
  }

  Widget _buildCategorySidebar(BuildContext context, MoviesReady state) {
    final theme = Theme.of(context);
    return Column(children: [
      Container(padding: const EdgeInsets.all(16), alignment: Alignment.centerLeft,
        child: Text('Categories', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
      const Divider(height: 1),
      Expanded(child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: state.categories.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _TvCatTile(title: '★ Favorites', icon: Icons.favorite,
              isSelected: _showFavorites,
              autofocus: false,
              onTap: () {
                context.read<MoviesBloc>().add(const SelectMovieCategory('__all__'));
                setState(() { _showFavorites = true; _selectedMovie = null; });
              });
          }
          if (index == 1) {
            return _TvCatTile(title: 'All Movies', icon: Icons.grid_view,
              isSelected: !_showFavorites && (state.selectedCategoryId == null || state.selectedCategoryId == '__all__'),
              autofocus: state.selectedCategoryId == null,
              onTap: () {
                context.read<MoviesBloc>().add(const SelectMovieCategory('__all__'));
                setState(() { _showFavorites = false; _selectedMovie = null; });
              });
          }
          final cat = state.categories[index - 2];
          return _TvCatTile(title: cat.name, icon: Icons.folder,
            isSelected: state.selectedCategoryId == cat.categoryId,
            autofocus: state.selectedCategoryId == cat.categoryId,
            onTap: () {
              context.read<MoviesBloc>().add(SelectMovieCategory(cat.categoryId));
              setState(() { _showFavorites = false; _selectedMovie = null; });
            });
        },
      )),
    ]);
  }

  Widget _buildMovieList(BuildContext context, MoviesReady state) {
    final theme = Theme.of(context);
    if (state.isLoadingMovies) return const Center(child: LoadingWidget(message: 'Loading movies…'));
    if (state.errorMessage != null) return ErrorStateWidget(
      failure: UnexpectedFailure(message: state.errorMessage!),
      onRetry: () => context.read<MoviesBloc>().add(SelectMovieCategory(state.selectedCategoryId ?? '__all__')));
    if (_showFavorites) {
      final favState = context.watch<FavoritesBloc>().state;
      final favIds = favState is FavoritesReady
          ? favState.favoritedIds
          : const <String>{};
      final favCount = state.movies
          .where((m) => favIds.contains(FavoriteItem.buildId(FavoriteType.movie, m.streamId)))
          .length;
      if (favCount == 0) {
        return const EmptyStateWidget(
            icon: Icons.favorite_border,
            message: 'No saved movies yet.\nOpen a movie and press the ♥ button to save it here.');
      }
    }
    if (state.movies.isEmpty) return const EmptyStateWidget(icon: Icons.movie_filter, message: 'No movies in this category');

    // Favorites filter (when ★ Favorites is selected in the sidebar)
    final favState = context.watch<FavoritesBloc>().state;
    final favIds =
        favState is FavoritesReady ? favState.favoritedIds : <String>{};
    List<Movie> baseMovies = state.movies;
    if (_showFavorites) {
      baseMovies = state.movies
          .where((m) => favIds.contains(FavoriteItem.buildId(FavoriteType.movie, m.streamId)))
          .toList();
    }

    // Filter movies by search query
    final filteredMovies = _searchQuery.isEmpty
        ? baseMovies
        : baseMovies.where((m) => m.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Column(children: [
      // Search bar
      Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: 'Search movies...',
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); })
              : null,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: theme.colorScheme.outlineVariant)),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ),
        ),
      ),
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(children: [
          Icon(Icons.folder_open, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8),
          Expanded(child: Text(
            _showFavorites
              ? '★ Favorites'
              : state.selectedCategoryId == null || state.selectedCategoryId == '__all__'
                ? 'All Movies' : state.categories.where((c) => c.categoryId == state.selectedCategoryId).firstOrNull?.name ?? 'Movies',
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
          Text('${filteredMovies.length}', style: theme.textTheme.bodySmall),
        ])),
      const Divider(height: 1),
      if (filteredMovies.isEmpty)
        Expanded(child: EmptyStateWidget(icon: Icons.search_off, message: 'No movies match "$_searchQuery"'))
      else
      Expanded(child: ListView.builder(
        controller: _scrollController, padding: EdgeInsets.zero, cacheExtent: 500,
        itemCount: filteredMovies.length,
        itemBuilder: (context, index) {
          final movie = filteredMovies[index];
          final isSelected = _selectedMovie?.streamId == movie.streamId;
          final favId = FavoriteItem.buildId(FavoriteType.movie, movie.streamId);
          return TvFocusable(
            autofocus: isSelected,
            onTap: () => setState(() => _selectedMovie = movie),
            onFocusChange: () => _scrollToFocused(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: isSelected ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3) : Colors.transparent,
              child: Row(children: [
                ClipRRect(borderRadius: BorderRadius.circular(4),
                  child: SizedBox(width: 36, height: 52,
                    child: movie.streamIcon != null && movie.streamIcon!.isNotEmpty
                      ? CachedNetworkImage(imageUrl: movie.streamIcon!, fit: BoxFit.cover,
                          placeholder: (c, u) => _posterPlaceholder(theme), errorWidget: (c, u, e) => _posterPlaceholder(theme))
                      : _posterPlaceholder(theme))),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(movie.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
                  if (movie.rating != null && movie.rating!.isNotEmpty && movie.rating != 'N/A')
                    Padding(padding: const EdgeInsets.only(top: 2),
                      child: Row(children: [Icon(Icons.star, size: 12, color: Colors.amber), const SizedBox(width: 4),
                        Text(movie.rating!, style: const TextStyle(fontSize: 11))])),
                ])),
              ]),
            ),
          );
        },
      )),
    ]);
  }

  Widget _buildPreview(BuildContext context, MoviesReady state) {
    final theme = Theme.of(context);
    if (_selectedMovie == null) return const EmptyStateWidget(icon: Icons.play_circle_outline, message: 'Select a movie to preview');
    final movie = _selectedMovie!;
    final favId = FavoriteItem.buildId(FavoriteType.movie, movie.streamId);

    return SingleChildScrollView(padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        const SizedBox(height: 20),
        Container(width: 180, height: 270,
          decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12)),
          child: movie.streamIcon != null && movie.streamIcon!.isNotEmpty
            ? ClipRRect(borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(imageUrl: movie.streamIcon!, fit: BoxFit.cover,
                  placeholder: (c, u) => _posterPlaceholder(theme, size: 64), errorWidget: (c, u, e) => _posterPlaceholder(theme, size: 64)))
            : _posterPlaceholder(theme, size: 64)),
        const SizedBox(height: 16),
        Text(movie.name, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (movie.rating != null && movie.rating!.isNotEmpty && movie.rating != 'N/A')
            _metaChip(theme, Icons.star, movie.rating!, Colors.amber),
          if (movie.releasedate != null && movie.releasedate!.isNotEmpty)
            _metaChip(theme, Icons.calendar_today, movie.releasedate!),
          if (movie.genre != null && movie.genre!.isNotEmpty)
            _metaChip(theme, Icons.category, movie.genre!),
          if (movie.duration != null && movie.duration! > 0)
            _metaChip(theme, Icons.access_time, '${movie.duration} min'),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: TvFocusable(borderRadius: BorderRadius.circular(12), autofocus: true,
            onTap: () => _playMovie(movie),
            child: Container(padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.play_arrow, size: 28), const SizedBox(width: 8),
                const Text('Play', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))])))),
          const SizedBox(width: 12),
          BlocBuilder<FavoritesBloc, FavoritesState>(
            buildWhen: (prev, curr) {
              if (curr is! FavoritesReady) return false;
              final p = prev is FavoritesReady ? prev : null;
              return p == null || p.favoritedIds.contains(favId) != curr.favoritedIds.contains(favId);
            },
            builder: (context, favState) {
              final isFav = favState is FavoritesReady && favState.favoritedIds.contains(favId);
              return TvFocusable(borderRadius: BorderRadius.circular(12),
                onTap: () {
                  context.read<FavoritesBloc>().add(ToggleFavorite(FavoriteItem(
                    id: favId, type: FavoriteType.movie, streamId: movie.streamId,
                    name: movie.name, imageUrl: movie.streamIcon, extra: movie.containerExtension ?? 'mp4')));
                },
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : null),
                    const SizedBox(width: 6), Text(isFav ? 'Saved' : 'Save')])));
            }),
        ]),
        const SizedBox(height: 16),
        if (movie.plot != null && movie.plot!.isNotEmpty) ...[
          Text('Overview', style: theme.textTheme.titleLarge?.copyWith(fontSize: 16)),
          const SizedBox(height: 8), Text(movie.plot!, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: 12),
        TvFocusable(borderRadius: BorderRadius.circular(8),
          onTap: () => _openDetails(movie),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.info_outline, size: 20), const SizedBox(width: 8), const Text('Full Details')]))),
      ]),
    );
  }

  // Narrow helpers
  Widget _buildCategoryBar(BuildContext context, MoviesReady state) {
    final theme = Theme.of(context);
    final selectedName = state.selectedCategoryId == null || state.selectedCategoryId == '__all__'
      ? 'All Movies' : state.categories.where((c) => c.categoryId == state.selectedCategoryId).firstOrNull?.name;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        Builder(builder: (context) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(context).openDrawer())),
        const SizedBox(width: 4),
        Icon(Icons.folder_open, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8),
        Expanded(child: Text(selectedName ?? 'All Movies', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
        Text('${state.movies.length} movies', style: theme.textTheme.bodySmall),
      ]));
  }

  Widget _buildMovieGrid(BuildContext context, MoviesReady state) {
    return switch (state) {
      _ when state.isLoadingMovies => const ShimmerGrid(),
      _ when state.errorMessage != null => ErrorStateWidget(
          failure: UnexpectedFailure(message: state.errorMessage!),
          onRetry: () => context.read<MoviesBloc>().add(SelectMovieCategory(state.selectedCategoryId ?? '__all__'))),
      _ when state.movies.isEmpty => const EmptyStateWidget(icon: Icons.movie_filter, message: 'No movies in this category'),
      _ => GridView.builder(
          padding: const EdgeInsets.all(8), cacheExtent: 600,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.50, crossAxisSpacing: 8, mainAxisSpacing: 8),
          itemCount: state.movies.length,
          itemBuilder: (context, index) {
            final movie = state.movies[index];
            return GestureDetector(onTap: () => _openDetails(movie),
              child: Card(clipBehavior: Clip.antiAlias,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: Container(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    child: movie.streamIcon != null && movie.streamIcon!.isNotEmpty
                      ? CachedNetworkImage(imageUrl: movie.streamIcon!, fit: BoxFit.cover,
                          placeholder: (c, u) => _posterPlaceholder(Theme.of(context)), errorWidget: (c, u, e) => _posterPlaceholder(Theme.of(context)))
                      : Center(child: Icon(Icons.movie, size: 32, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4))))),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(movie.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600))),
                ])));
          }),
    };
  }

  Widget _metaChip(ThemeData theme, IconData icon, String label, [Color? iconColor]) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: iconColor ?? theme.colorScheme.primary), const SizedBox(width: 4),
        Text(label, style: theme.textTheme.bodySmall)]));
  }

  Widget _posterPlaceholder(ThemeData theme, {double size = 32}) {
    return Icon(Icons.movie, size: size, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4));
  }
}

class _TvCatTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final bool autofocus;
  final VoidCallback onTap;

  const _TvCatTile({required this.title, required this.icon, required this.isSelected, this.autofocus = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TvFocusable(
      autofocus: autofocus, onTap: onTap,
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Icon(icon, size: 20, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? theme.colorScheme.primary : null))),
        ])));
  }
}
