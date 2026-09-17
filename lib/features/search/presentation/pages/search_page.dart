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
import '../../../series/domain/entities/series_entities.dart';
import '../../../series/presentation/pages/series_details_page.dart';
import '../../domain/entities/search_entities.dart';
import '../../domain/repositories/search_repository.dart';
import '../bloc/search_bloc.dart';
import '../widgets/search_result_tile.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SearchBloc(getIt<SearchRepository>()),
      child: const _SearchView(),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    context.read<SearchBloc>().add(SearchQueryChanged(query));
  }

  void _clearSearch() {
    _controller.clear();
    context.read<SearchBloc>().add(const SearchCleared());
    _focusNode.requestFocus();
  }

  void _openResult(SearchResult result) {
    final serverConfig = getIt<ServerConfig>();

    switch (result.type) {
      case SearchResultType.live:
        final url = StreamUrlBuilder.live(
          baseUrl: serverConfig.baseUrl,
          username: serverConfig.username,
          password: serverConfig.password,
          streamId: result.streamId,
        );
        context.push(
          AppRoutes.livePlayer,
          extra: PlayerConfig(
            url: url,
            title: result.name,
            contentType: PlayerContentType.live,
          ),
        );

      case SearchResultType.movie:
        final url = StreamUrlBuilder.vod(
          baseUrl: serverConfig.baseUrl,
          username: serverConfig.username,
          password: serverConfig.password,
          streamId: result.streamId,
          containerExtension: result.containerExtension ?? 'mp4',
        );
        context.push(
          AppRoutes.moviePlayer,
          extra: PlayerConfig(
            url: url,
            title: result.name,
            contentType: PlayerContentType.vod,
          ),
        );

      case SearchResultType.series:
        // Build a minimal SeriesItem so SeriesDetailsPage can fetch full info.
        final seriesItem = SeriesItem(
          seriesId: result.streamId,
          name: result.name,
          cover: result.imageUrl,
          categoryId: result.categoryId ?? '',
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SeriesDetailsPage(series: seriesItem),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onChanged,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Search channels, movies, series…',
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: BlocBuilder<SearchBloc, SearchState>(
              buildWhen: (prev, curr) =>
                  curr is SearchIdle || curr is SearchLoading ||
                  curr is SearchReady,
              builder: (context, state) {
                if (state is SearchLoading) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                if (_controller.text.isNotEmpty) {
                  return IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearSearch,
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
      body: BlocBuilder<SearchBloc, SearchState>(
        builder: (context, state) {
          return switch (state) {
            SearchIdle() => const EmptyStateWidget(
                icon: Icons.search,
                message: 'Start typing to search across all content',
              ),
            SearchLoading() => const LoadingWidget(message: 'Searching…'),
            SearchReady() => _buildResults(context, state),
            SearchError() => ErrorStateWidget(
                failure: UnexpectedFailure(message: state.message),
                onRetry: () => context
                    .read<SearchBloc>()
                    .add(SearchQueryChanged(_controller.text)),
              ),
          };
        },
      ),
    );
  }

  Widget _buildResults(BuildContext context, SearchReady state) {
    final results = state.results;

    if (results.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.search_off,
        message: 'No results for "${state.query}"',
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      cacheExtent: 500,
      children: [
        if (results.live.isNotEmpty) ...[
          _sectionHeader(context, 'Live TV', results.live.length,
              color: Colors.red, icon: Icons.live_tv),
          ...results.live.map((r) => SearchResultTile(
                result: r,
                onTap: () => _openResult(r),
              )),
          const Divider(height: 32),
        ],
        if (results.movies.isNotEmpty) ...[
          _sectionHeader(context, 'Movies', results.movies.length,
              color: Colors.blue, icon: Icons.movie),
          ...results.movies.map((r) => SearchResultTile(
                result: r,
                onTap: () => _openResult(r),
              )),
          const Divider(height: 32),
        ],
        if (results.series.isNotEmpty) ...[
          _sectionHeader(context, 'Series', results.series.length,
              color: Colors.purple, icon: Icons.tv),
          ...results.series.map((r) => SearchResultTile(
                result: r,
                onTap: () => _openResult(r),
              )),
        ],
      ],
    );
  }

  Widget _sectionHeader(
    BuildContext context,
    String title,
    int count, {
    required Color color,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
