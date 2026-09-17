import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/widgets/shimmer_grid.dart';
import '../../../../core/widgets/tv_focusable.dart';
import '../../domain/entities/series_entities.dart';
import '../../../favorites/domain/entities/favorite_entities.dart';
import '../../../favorites/presentation/bloc/favorites_bloc.dart';
import '../bloc/series_bloc.dart';
import '../pages/series_details_page.dart';

class SeriesPage extends StatelessWidget {
  const SeriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SeriesView();
  }
}

class _SeriesView extends StatefulWidget {
  const _SeriesView();

  @override
  State<_SeriesView> createState() => _SeriesViewState();
}

class _SeriesViewState extends State<_SeriesView> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  SeriesItem? _selectedSeries;
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

  void _openDetails(SeriesItem series) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => SeriesDetailsPage(series: series)));
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
      appBar: AppBar(title: const Text('Series')),
      body: BlocConsumer<SeriesBloc, SeriesState>(
        listenWhen: (prev, curr) => curr is SeriesReady && prev is! SeriesReady,
        listener: (context, state) {
          if (state is SeriesReady && state.series.isNotEmpty && _selectedSeries == null) {
            setState(() => _selectedSeries = state.series.first);
          }
        },
        builder: (context, state) {
          return switch (state) {
            SeriesInitial() => const LoadingWidget(message: 'Loading…'),
            SeriesLoading() => const ShimmerGrid(),
            SeriesError() => ErrorStateWidget(
                failure: UnexpectedFailure(message: state.message),
                onRetry: () => context.read<SeriesBloc>().add(const LoadSeriesCategories())),
            SeriesReady() => (true)
                ? _buildWideLayout(context, state)
                : _buildNarrowLayout(context, state),
          };
        },
      ),
    );
  }

  Widget _buildWideLayout(BuildContext context, SeriesReady state) {
    return Row(children: [
        SizedBox(width: 200, child: _buildCategorySidebar(context, state)),
        const VerticalDivider(width: 1),
        SizedBox(width: 320, child: _buildSeriesList(context, state)),
        const VerticalDivider(width: 1),
        Expanded(child: _buildPreview(context, state)),
    ]);
  }

  Widget _buildNarrowLayout(BuildContext context, SeriesReady state) {
    return Scaffold(
      drawer: Drawer(child: _buildCategorySidebar(context, state)),
      body: Column(children: [
        _buildCategoryBar(context, state),
        Expanded(child: _buildSeriesGrid(context, state)),
      ]),
    );
  }

  Widget _buildCategorySidebar(BuildContext context, SeriesReady state) {
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
                context.read<SeriesBloc>().add(const SelectSeriesCategory('__all__'));
                setState(() { _showFavorites = true; _selectedSeries = null; });
              });
          }
          if (index == 1) {
            return _TvCatTile(title: 'All Series', icon: Icons.grid_view,
              isSelected: !_showFavorites && (state.selectedCategoryId == null || state.selectedCategoryId == '__all__'),
              autofocus: state.selectedCategoryId == null,
              onTap: () {
                context.read<SeriesBloc>().add(const SelectSeriesCategory('__all__'));
                setState(() { _showFavorites = false; _selectedSeries = null; });
              });
          }
          final cat = state.categories[index - 2];
          return _TvCatTile(title: cat.name, icon: Icons.folder,
            isSelected: state.selectedCategoryId == cat.categoryId,
            autofocus: state.selectedCategoryId == cat.categoryId,
            onTap: () {
              context.read<SeriesBloc>().add(SelectSeriesCategory(cat.categoryId));
              setState(() { _showFavorites = false; _selectedSeries = null; });
            });
        },
      )),
    ]);
  }

  Widget _buildSeriesList(BuildContext context, SeriesReady state) {
    final theme = Theme.of(context);
    if (state.isLoadingSeries) return const Center(child: LoadingWidget(message: 'Loading series…'));
    if (state.errorMessage != null) return ErrorStateWidget(
      failure: UnexpectedFailure(message: state.errorMessage!),
      onRetry: () => context.read<SeriesBloc>().add(SelectSeriesCategory(state.selectedCategoryId ?? '__all__')));
    if (_showFavorites) {
      final favState = context.watch<FavoritesBloc>().state;
      final favIds = favState is FavoritesReady
          ? favState.favoritedIds
          : const <String>{};
      final favCount = state.series
          .where((s) => favIds.contains(FavoriteItem.buildId(FavoriteType.series, s.seriesId)))
          .length;
      if (favCount == 0) {
        return const EmptyStateWidget(
            icon: Icons.favorite_border,
            message: 'No saved series yet.\nOpen a series and press the ♥ button to save it here.');
      }
    }
    if (state.series.isEmpty) return const EmptyStateWidget(icon: Icons.tv_off, message: 'No series in this category');

    // Favorites filter (when ★ Favorites is selected in the sidebar)
    final favState = context.watch<FavoritesBloc>().state;
    final favIds =
        favState is FavoritesReady ? favState.favoritedIds : <String>{};
    List<SeriesItem> baseSeries = state.series;
    if (_showFavorites) {
      baseSeries = state.series
          .where((s) => favIds.contains(FavoriteItem.buildId(FavoriteType.series, s.seriesId)))
          .toList();
    }

    // Filter series by search query
    final filteredSeries = _searchQuery.isEmpty
        ? baseSeries
        : baseSeries.where((s) => s.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Column(children: [
      // Search bar
      Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: 'Search series...',
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
                ? 'All Series' : state.categories.where((c) => c.categoryId == state.selectedCategoryId).firstOrNull?.name ?? 'Series',
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
          Text('${filteredSeries.length}', style: theme.textTheme.bodySmall),
        ])),
      const Divider(height: 1),
      if (filteredSeries.isEmpty)
        Expanded(child: EmptyStateWidget(icon: Icons.search_off, message: 'No series match "$_searchQuery"'))
      else
      Expanded(child: ListView.builder(
        controller: _scrollController, padding: EdgeInsets.zero, cacheExtent: 500,
        itemCount: filteredSeries.length,
        itemBuilder: (context, index) {
          final series = filteredSeries[index];
          final isSelected = _selectedSeries?.seriesId == series.seriesId;
          final favId = FavoriteItem.buildId(FavoriteType.series, series.seriesId);
          return TvFocusable(
            autofocus: isSelected,
            onTap: () => setState(() => _selectedSeries = series),
            onFocusChange: () => _scrollToFocused(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: isSelected ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3) : Colors.transparent,
              child: Row(children: [
                ClipRRect(borderRadius: BorderRadius.circular(4),
                  child: SizedBox(width: 36, height: 52,
                    child: series.cover != null && series.cover!.isNotEmpty
                      ? CachedNetworkImage(imageUrl: series.cover!, fit: BoxFit.cover,
                          placeholder: (c, u) => _posterPlaceholder(theme), errorWidget: (c, u, e) => _posterPlaceholder(theme))
                      : _posterPlaceholder(theme))),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(series.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
                  if (series.episodeCount != null && series.episodeCount! > 0)
                    Padding(padding: const EdgeInsets.only(top: 2),
                      child: Text('${series.episodeCount} eps', style: const TextStyle(fontSize: 11))),
                ])),
              ]),
            ),
          );
        },
      )),
    ]);
  }

  Widget _buildPreview(BuildContext context, SeriesReady state) {
    final theme = Theme.of(context);
    if (_selectedSeries == null) return const EmptyStateWidget(icon: Icons.play_circle_outline, message: 'Select a series to preview');
    final series = _selectedSeries!;
    final favId = FavoriteItem.buildId(FavoriteType.series, series.seriesId);

    return SingleChildScrollView(padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        const SizedBox(height: 20),
        Container(width: 180, height: 270,
          decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12)),
          child: series.cover != null && series.cover!.isNotEmpty
            ? ClipRRect(borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(imageUrl: series.cover!, fit: BoxFit.cover,
                  placeholder: (c, u) => _posterPlaceholder(theme, size: 64), errorWidget: (c, u, e) => _posterPlaceholder(theme, size: 64)))
            : _posterPlaceholder(theme, size: 64)),
        const SizedBox(height: 16),
        Text(series.name, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (series.rating != null && series.rating!.isNotEmpty && series.rating != 'N/A')
            _metaChip(theme, Icons.star, series.rating!, Colors.amber),
          if (series.releaseDate != null && series.releaseDate!.isNotEmpty)
            _metaChip(theme, Icons.calendar_today, series.releaseDate!),
          if (series.genre != null && series.genre!.isNotEmpty)
            _metaChip(theme, Icons.category, series.genre!),
          if (series.episodeCount != null && series.episodeCount! > 0)
            _metaChip(theme, Icons.tv, '${series.episodeCount} episodes'),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: TvFocusable(borderRadius: BorderRadius.circular(12), autofocus: true,
            onTap: () => _openDetails(series),
            child: Container(padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.list, size: 24), const SizedBox(width: 8),
                const Text('View Seasons', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))])))),
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
                    id: favId, type: FavoriteType.series, streamId: series.seriesId,
                    name: series.name, imageUrl: series.cover)));
                },
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : null),
                    const SizedBox(width: 6), Text(isFav ? 'Saved' : 'Save')])));
            }),
        ]),
        const SizedBox(height: 16),
        if (series.plot != null && series.plot!.isNotEmpty) ...[
          Text('Overview', style: theme.textTheme.titleLarge?.copyWith(fontSize: 16)),
          const SizedBox(height: 8), Text(series.plot!, style: theme.textTheme.bodyMedium),
        ],
      ]),
    );
  }

  Widget _buildCategoryBar(BuildContext context, SeriesReady state) {
    final theme = Theme.of(context);
    final selectedName = state.selectedCategoryId == null || state.selectedCategoryId == '__all__'
      ? 'All Series' : state.categories.where((c) => c.categoryId == state.selectedCategoryId).firstOrNull?.name;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        Builder(builder: (context) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(context).openDrawer())),
        const SizedBox(width: 4),
        Icon(Icons.folder_open, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8),
        Expanded(child: Text(selectedName ?? 'All Series', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
        Text('${state.series.length} series', style: theme.textTheme.bodySmall),
      ]));
  }

  Widget _buildSeriesGrid(BuildContext context, SeriesReady state) {
    return switch (state) {
      _ when state.isLoadingSeries => const ShimmerGrid(),
      _ when state.errorMessage != null => ErrorStateWidget(
          failure: UnexpectedFailure(message: state.errorMessage!),
          onRetry: () => context.read<SeriesBloc>().add(SelectSeriesCategory(state.selectedCategoryId ?? '__all__'))),
      _ when state.series.isEmpty => const EmptyStateWidget(icon: Icons.tv_off, message: 'No series in this category'),
      _ => GridView.builder(
          padding: const EdgeInsets.all(8), cacheExtent: 600,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.50, crossAxisSpacing: 8, mainAxisSpacing: 8),
          itemCount: state.series.length,
          itemBuilder: (context, index) {
            final series = state.series[index];
            return GestureDetector(onTap: () => _openDetails(series),
              child: Card(clipBehavior: Clip.antiAlias,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: Stack(children: [
                    Container(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      child: series.cover != null && series.cover!.isNotEmpty
                        ? CachedNetworkImage(imageUrl: series.cover!, fit: BoxFit.cover,
                            placeholder: (c, u) => _posterPlaceholder(Theme.of(context)), errorWidget: (c, u, e) => _posterPlaceholder(Theme.of(context)))
                        : Center(child: Icon(Icons.tv, size: 32, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4)))),
                    if (series.episodeCount != null && series.episodeCount! > 0)
                      Positioned(bottom: 6, left: 6,
                        child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(4)),
                          child: Text('${series.episodeCount} eps', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)))),
                  ])),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(series.name, maxLines: 2, overflow: TextOverflow.ellipsis,
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
    return Icon(Icons.tv, size: size, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4));
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
