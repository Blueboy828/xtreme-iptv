import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/stream_url_builder.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/network/server_config.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/widgets/shimmer_grid.dart';
import '../../../../core/widgets/tv_focusable.dart';
import '../../../player/domain/entities/player_entities.dart';
import '../../../favorites/domain/entities/favorite_entities.dart';
import '../../../favorites/presentation/bloc/favorites_bloc.dart';
import '../../domain/entities/live_entities.dart';
import '../../../epg/domain/entities/epg_entities.dart';
import '../bloc/live_tv_bloc.dart';

class LiveTvPage extends StatelessWidget {
  const LiveTvPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LiveTvView();
  }
}

class _LiveTvView extends StatefulWidget {
  const _LiveTvView();

  @override
  State<_LiveTvView> createState() => _LiveTvViewState();
}

class _LiveTvViewState extends State<_LiveTvView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  LiveChannel? _selectedChannel;
  final _middleScrollController = ScrollController();
  Timer? _epgRefreshTimer;
  final _categoryFocusNode = FocusNode();
  final _previewFocusNode = FocusNode();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showFavorites = false;

  @override
  void initState() {
    super.initState();
    // Keep the guide honest: re-check the server every 2 minutes for any
    // channel whose "now" program has ended or whose data is stale. The
    // bloc gates this, so only genuinely stale channels make a request.
    _epgRefreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (!mounted) return;
      final bloc = context.read<LiveTvBloc>();
      final state = bloc.state;
      if (state is! LiveTvReady) return;
      for (final channel in state.channels.take(20)) {
        if (state.needsEpgRefresh(channel.streamId)) {
          bloc.add(LoadEpgForChannel(channel.streamId));
        }
      }
      final selected = _selectedChannel;
      if (selected != null && state.needsEpgRefresh(selected.streamId)) {
        bloc.add(LoadEpgForChannel(selected.streamId, includeFullSchedule: true));
      }
    });
  }

  @override
  void dispose() {
    _epgRefreshTimer?.cancel();
    _middleScrollController.dispose();
    _categoryFocusNode.dispose();
    _previewFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _selectChannel(LiveChannel channel) {
    setState(() => _selectedChannel = channel);
    final bloc = context.read<LiveTvBloc>();
    final state = bloc.state;
    if (state is LiveTvReady && state.needsEpgRefresh(channel.streamId)) {
      bloc.add(LoadEpgForChannel(channel.streamId, includeFullSchedule: true));
    }
  }

  void _playChannel(LiveChannel channel) {
    final serverConfig = getIt<ServerConfig>();
    final url = StreamUrlBuilder.live(
      baseUrl: serverConfig.baseUrl,
      username: serverConfig.username,
      password: serverConfig.password,
      streamId: channel.streamId,
    );
    context.push(
      AppRoutes.livePlayer,
      extra: PlayerConfig(
        url: url,
        title: channel.name,
        contentType: PlayerContentType.live,
      ),
    );
  }

  void _loadEpgForVisibleChannels(BuildContext context, LiveTvReady state) {
    for (final channel in state.channels.take(20)) {
      if (state.needsEpgRefresh(channel.streamId)) {
        context.read<LiveTvBloc>().add(LoadEpgForChannel(channel.streamId));
      }
    }
  }

  void _scrollToFocusedChannel(int index) {
    if (_middleScrollController.hasClients) {
      final target = index * 56.0; // approx ListTile height
      _middleScrollController.animateTo(
        target.clamp(0.0, _middleScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // TV app — always use the three-panel wide layout

    return Scaffold(
      appBar: AppBar(title: const Text('Live TV')),
      body: BlocConsumer<LiveTvBloc, LiveTvState>(
        listenWhen: (prev, curr) => curr is LiveTvReady && prev is! LiveTvReady,
        listener: (context, state) {
          if (state is LiveTvReady && state.channels.isNotEmpty) {
            _loadEpgForVisibleChannels(context, state);
            if (_selectedChannel == null) {
              _selectChannel(state.channels.first);
            }
          }
        },
        buildWhen: (prev, curr) => true,
        builder: (context, state) {
          return switch (state) {
            LiveTvInitial() => const LoadingWidget(message: 'Loading…'),
            LiveTvLoading() => const ShimmerGrid(),
            LiveTvError() => ErrorStateWidget(
                failure: UnexpectedFailure(message: state.message),
                onRetry: () =>
                    context.read<LiveTvBloc>().add(const LoadCategories()),
              ),
            LiveTvReady() => (true)
                ? _buildWideLayout(context, state)
                : _buildNarrowLayout(context, state),
          };
        },
      ),
    );
  }

  // ── Wide / TV: three panels with D-pad focus traversal ─────────
  Widget _buildWideLayout(BuildContext context, LiveTvReady state) {
    return Row(
      children: [
          // Left: Categories
          SizedBox(width: 200, child: _buildCategorySidebar(context, state)),
          const VerticalDivider(width: 1),
          // Middle: Channel list
          SizedBox(width: 320, child: _buildChannelList(context, state)),
          const VerticalDivider(width: 1),
          // Right: Preview
          Expanded(child: _buildPreview(context, state)),
      ],
    );
  }

  // ── Narrow: drawer + grid ─────────────────────────────────────
  Widget _buildNarrowLayout(BuildContext context, LiveTvReady state) {
    return Scaffold(
      drawer: Drawer(
        child: _buildCategorySidebar(context, state),
      ),
      body: Column(
        children: [
          _buildCategoryBar(context, state),
          Expanded(child: _buildChannelGrid(context, state)),
        ],
      ),
    );
  }

  // ── Left panel: Categories ─────────────────────────────────────
  Widget _buildCategorySidebar(BuildContext context, LiveTvReady state) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          alignment: Alignment.centerLeft,
          child: Text('Categories',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: state.categories.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _TvCategoryTile(
                  title: '★ Favorites',
                  icon: Icons.favorite,
                  isSelected: _showFavorites,
                  onTap: () {
                    // Load all channels, then show only the saved ones.
                    context.read<LiveTvBloc>().add(const SelectCategory('__all__'));
                    setState(() {
                      _showFavorites = true;
                      _selectedChannel = null;
                    });
                  },
                  autofocus: false,
                );
              }
              if (index == 1) {
                return _TvCategoryTile(
                  title: 'All Channels',
                  icon: Icons.grid_view,
                  isSelected: !_showFavorites &&
                      (state.selectedCategoryId == null ||
                          state.selectedCategoryId == '__all__'),
                  onTap: () {
                    context.read<LiveTvBloc>().add(const SelectCategory('__all__'));
                    setState(() {
                      _showFavorites = false;
                      _selectedChannel = null;
                    });
                  },
                  autofocus: state.selectedCategoryId == null,
                );
              }
              final cat = state.categories[index - 2];
              return _TvCategoryTile(
                title: cat.name,
                icon: Icons.folder,
                isSelected: state.selectedCategoryId == cat.categoryId,
                onTap: () {
                  context.read<LiveTvBloc>().add(SelectCategory(cat.categoryId));
                  setState(() {
                    _showFavorites = false;
                    _selectedChannel = null;
                  });
                },
                autofocus: state.selectedCategoryId == cat.categoryId,
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Middle panel: Channel list (wide) ─────────────────────────
  Widget _buildChannelList(BuildContext context, LiveTvReady state) {
    final theme = Theme.of(context);

    if (state.isLoadingChannels) {
      return const Center(child: LoadingWidget(message: 'Loading channels…'));
    }
    if (state.errorMessage != null) {
      return ErrorStateWidget(
        failure: UnexpectedFailure(message: state.errorMessage!),
        onRetry: () => context.read<LiveTvBloc>().add(
              SelectCategory(state.selectedCategoryId ?? '__all__'),
            ),
      );
    }
    if (_showFavorites) {
      final favState = context.watch<FavoritesBloc>().state;
      final favIds = favState is FavoritesReady
          ? favState.favoritedIds
          : const <String>{};
      final favCount = state.channels
          .where((c) => favIds.contains(FavoriteItem.buildId(FavoriteType.live, c.streamId)))
          .length;
      if (favCount == 0) {
        return const EmptyStateWidget(
            icon: Icons.favorite_border,
            message: 'No saved channels yet.\nOpen a channel and press the ♥ button to save it here.');
      }
    }
    if (state.channels.isEmpty) {
      return const EmptyStateWidget(icon: Icons.tv_off, message: 'No channels in this category');
    }

    // Favorites filter (when ★ Favorites is selected in the sidebar)
    final favState = context.watch<FavoritesBloc>().state;
    final favIds =
        favState is FavoritesReady ? favState.favoritedIds : <String>{};
    List<LiveChannel> baseChannels = state.channels;
    if (_showFavorites) {
      baseChannels = state.channels
          .where((c) => favIds.contains(FavoriteItem.buildId(FavoriteType.live, c.streamId)))
          .toList();
    }

    // Filter channels by search query
    final filteredChannels = _searchQuery.isEmpty
        ? baseChannels
        : baseChannels.where((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Search channels...',
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(children: [
            Icon(Icons.folder_open, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _showFavorites
                    ? '★ Favorites'
                    : state.selectedCategoryId == null || state.selectedCategoryId == '__all__'
                        ? 'All Channels'
                        : state.categories.where((c) => c.categoryId == state.selectedCategoryId).firstOrNull?.name ?? 'Channels',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Text('${filteredChannels.length}', style: theme.textTheme.bodySmall),
          ]),
        ),
        const Divider(height: 1),
        if (filteredChannels.isEmpty)
          Expanded(child: EmptyStateWidget(icon: Icons.search_off, message: 'No channels match "$_searchQuery"'))
        else
        Expanded(
          child: ListView.builder(
            controller: _middleScrollController,
            padding: EdgeInsets.zero,
            cacheExtent: 500,
            itemCount: filteredChannels.length,
            itemBuilder: (context, index) {
              final channel = filteredChannels[index];
              final isSelected = _selectedChannel?.streamId == channel.streamId;
              final epg = state.epgCache[channel.streamId];
              final isEpgLoading = state.loadingEpgIds.contains(channel.streamId);

              return _TvChannelTile(
                channel: channel,
                epg: epg,
                isEpgLoading: isEpgLoading,
                isSelected: isSelected,
                autofocus: isSelected,
                onTap: () => _selectChannel(channel),
                onFocusChange: () => _scrollToFocusedChannel(index),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Right panel: Preview ──────────────────────────────────────
  Widget _buildPreview(BuildContext context, LiveTvReady state) {
    final theme = Theme.of(context);

    if (_selectedChannel == null) {
      return const EmptyStateWidget(icon: Icons.play_circle_outline, message: 'Select a channel to preview');
    }

    final channel = _selectedChannel!;
    final epg = state.epgCache[channel.streamId];
    final schedule = state.scheduleCache[channel.streamId] ?? const <EpgEntry>[];
    final favId = FavoriteItem.buildId(FavoriteType.live, channel.streamId);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Container(
            width: 160, height: 160,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: channel.streamIcon != null && channel.streamIcon!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: channel.streamIcon!, fit: BoxFit.contain,
                      placeholder: (c, u) => _logoPlaceholder(theme, size: 64),
                      errorWidget: (c, u, e) => _logoPlaceholder(theme, size: 64),
                    ))
                : _logoPlaceholder(theme, size: 64),
          ),
          const SizedBox(height: 16),
          Text(channel.name, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          // Favorite button
          BlocBuilder<FavoritesBloc, FavoritesState>(
            buildWhen: (prev, curr) {
              if (curr is! FavoritesReady) return false;
              final p = prev is FavoritesReady ? prev : null;
              return p == null || p.favoritedIds.contains(favId) != curr.favoritedIds.contains(favId);
            },
            builder: (context, favState) {
              final isFav = favState is FavoritesReady && favState.favoritedIds.contains(favId);
              return TvFocusable(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  context.read<FavoritesBloc>().add(ToggleFavorite(FavoriteItem(
                    id: favId, type: FavoriteType.live, streamId: channel.streamId,
                    name: channel.name, imageUrl: channel.streamIcon,
                  )));
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : null),
                    const SizedBox(width: 8),
                    Text(isFav ? 'Saved' : 'Add to Favorites'),
                  ]),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          if (epg?.now != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.play_circle, size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('Now Playing', style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 8),
                    Text(epg!.now!.title, style: theme.textTheme.titleMedium),
                    if (epg.now!.description != null && epg.now!.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(epg.now!.description!, maxLines: 3, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                    ],
                    const SizedBox(height: 8),
                    Text(DateTimeUtils.formatEpgRange(epg.now?.start, epg.now?.end),
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ] else if (state.loadingEpgIds.contains(channel.streamId)) ...[
            const Padding(padding: EdgeInsets.all(16), child: LoadingWidget(message: 'Loading program info…')),
          ],
          if (epg?.next != null) ...[
            Card(
              child: ListTile(
                leading: Icon(Icons.next_plan, size: 20, color: theme.colorScheme.onSurfaceVariant),
                title: Text('Up Next: ${epg!.next!.title}', maxLines: 1, overflow: TextOverflow.ellipsis),
                dense: true,
              ),
            ),
          ],
          // Full day's schedule (customer-requested). Computed from the
          // channel's full program list using the device clock.
          if (schedule.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.schedule, size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text('Coming Up', style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final program in schedule
                      .where((e) => e.start != epg?.next?.start)
                      .take(8))
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: Text(
                        DateTimeUtils.formatEpgTime(program.start),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      title: Text(program.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          // Watch button — D-pad selectable
          TvFocusable(
            borderRadius: BorderRadius.circular(12),
            autofocus: true,
            onTap: () => _playChannel(channel),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.play_arrow, size: 28),
                const SizedBox(width: 8),
                const Text('Watch Now', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Narrow helpers ────────────────────────────────────────────
  Widget _buildCategoryBar(BuildContext context, LiveTvReady state) {
    final theme = Theme.of(context);
    final selectedName = state.selectedCategoryId == null || state.selectedCategoryId == '__all__'
        ? 'All Channels'
        : state.categories.where((c) => c.categoryId == state.selectedCategoryId).firstOrNull?.name;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        Builder(builder: (context) => IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(context).openDrawer(),
        )),
        const SizedBox(width: 4),
        Icon(Icons.folder_open, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(selectedName ?? 'All Channels', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
        Text('${state.channels.length} channels', style: theme.textTheme.bodySmall),
      ]),
    );
  }

  Widget _buildChannelGrid(BuildContext context, LiveTvReady state) {
    final theme = Theme.of(context);
    return switch (state) {
      _ when state.isLoadingChannels => const ShimmerGrid(),
      _ when state.errorMessage != null => ErrorStateWidget(
          failure: UnexpectedFailure(message: state.errorMessage!),
          onRetry: () => context.read<LiveTvBloc>().add(SelectCategory(state.selectedCategoryId ?? '__all__')),
        ),
      _ when state.channels.isEmpty => const EmptyStateWidget(icon: Icons.tv_off, message: 'No channels in this category'),
      _ => GridView.builder(
          padding: const EdgeInsets.all(8), cacheExtent: 500,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, childAspectRatio: 0.72, crossAxisSpacing: 8, mainAxisSpacing: 8),
          itemCount: state.channels.length,
          itemBuilder: (context, index) {
            final channel = state.channels[index];
            final epg = state.epgCache[channel.streamId];
            final isEpgLoading = state.loadingEpgIds.contains(channel.streamId);
            final favId = FavoriteItem.buildId(FavoriteType.live, channel.streamId);
            return GestureDetector(
              onTap: () => _showPreviewSheet(context, state, channel, epg),
              onLongPress: () {
                context.read<FavoritesBloc>().add(ToggleFavorite(FavoriteItem(
                  id: favId, type: FavoriteType.live, streamId: channel.streamId,
                  name: channel.name, imageUrl: channel.streamIcon)));
              },
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(flex: 3, child: Stack(children: [
                    Container(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      child: channel.streamIcon != null && channel.streamIcon!.isNotEmpty
                          ? CachedNetworkImage(imageUrl: channel.streamIcon!, fit: BoxFit.contain,
                              placeholder: (c, u) => _logoPlaceholder(theme), errorWidget: (c, u, e) => _logoPlaceholder(theme))
                          : _logoPlaceholder(theme),
                    ),
                    Positioned(
                      top: 4, right: 4,
                      child: BlocBuilder<FavoritesBloc, FavoritesState>(
                        buildWhen: (prev, curr) {
                          if (curr is! FavoritesReady) return false;
                          final p = prev is FavoritesReady ? prev : null;
                          return p == null || p.favoritedIds.contains(favId) != curr.favoritedIds.contains(favId);
                        },
                        builder: (context, favState) {
                          final isFav = favState is FavoritesReady && favState.favoritedIds.contains(favId);
                          return GestureDetector(
                            onTap: () {
                              context.read<FavoritesBloc>().add(ToggleFavorite(FavoriteItem(
                                id: favId, type: FavoriteType.live, streamId: channel.streamId,
                                name: channel.name, imageUrl: channel.streamIcon)));
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
                              child: Icon(isFav ? Icons.favorite : Icons.favorite_border, size: 14, color: isFav ? Colors.red : Colors.white70),
                            ),
                          );
                        },
                      ),
                    ),
                  ])),
                  Expanded(flex: 2, child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(channel.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      if (epg?.now != null)
                        Expanded(child: Text(epg!.now!.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary, fontSize: 10)))
                      else if (isEpgLoading)
                        const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5))
                      else
                        Expanded(child: Text(DateTimeUtils.formatEpgRange(epg?.now?.start, epg?.now?.end),
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(fontSize: 10))),
                    ]),
                  )),
                ]),
              ),
            );
          },
        ),
    };
  }

  void _showPreviewSheet(BuildContext context, LiveTvReady state, LiveChannel channel, EpgNowNext? epg) {
    _selectChannel(channel);
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => BlocBuilder<LiveTvBloc, LiveTvState>(
        builder: (context, state) {
          final currentEpg = state is LiveTvReady ? state.epgCache[channel.streamId] : epg;
          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              Container(width: 100, height: 100,
                decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12)),
                child: channel.streamIcon != null && channel.streamIcon!.isNotEmpty
                    ? ClipRRect(borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(imageUrl: channel.streamIcon!, fit: BoxFit.contain,
                          placeholder: (c, u) => _logoPlaceholder(theme, size: 40), errorWidget: (c, u, e) => _logoPlaceholder(theme, size: 40)))
                    : _logoPlaceholder(theme, size: 40)),
              const SizedBox(height: 12),
              Text(channel.name, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              if (currentEpg?.now != null) ...[
                Text('Now: ${currentEpg!.now!.title}', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary)),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: () { Navigator.of(context).pop(); _playChannel(channel); },
                icon: const Icon(Icons.play_arrow, size: 28),
                label: const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Text('Watch Now', style: TextStyle(fontSize: 18))),
              )),
            ]),
          );
        },
      ),
    );
  }

  Widget _logoPlaceholder(ThemeData theme, {double size = 28}) {
    return Icon(Icons.live_tv, size: size, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4));
  }
}

// ── TV-optimized category tile ──────────────────────────────────
class _TvCategoryTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool autofocus;

  const _TvCategoryTile({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TvFocusable(
      autofocus: autofocus,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Icon(icon, size: 20,
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? theme.colorScheme.primary : null)),
          ),
        ]),
      ),
    );
  }
}

// ── TV-optimized channel tile ───────────────────────────────────
class _TvChannelTile extends StatelessWidget {
  final LiveChannel channel;
  final EpgNowNext? epg;
  final bool isEpgLoading;
  final bool isSelected;
  final bool autofocus;
  final VoidCallback onTap;
  final VoidCallback? onFocusChange;

  const _TvChannelTile({
    required this.channel,
    this.epg,
    this.isEpgLoading = false,
    this.isSelected = false,
    this.autofocus = false,
    required this.onTap,
    this.onFocusChange,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TvFocusable(
      autofocus: autofocus,
      onTap: onTap,
      onFocusChange: onFocusChange,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: isSelected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : Colors.transparent,
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 40, height: 40,
              child: channel.streamIcon != null && channel.streamIcon!.isNotEmpty
                  ? CachedNetworkImage(imageUrl: channel.streamIcon!, fit: BoxFit.contain,
                      placeholder: (c, u) => Icon(Icons.live_tv, size: 20, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                      errorWidget: (c, u, e) => Icon(Icons.live_tv, size: 20, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)))
                  : Icon(Icons.live_tv, size: 20, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(channel.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
              if (epg?.now != null)
                Text(epg!.now!.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.primary))
              else if (isEpgLoading)
                const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1)),
            ],
          )),
        ]),
      ),
    );
  }
}
