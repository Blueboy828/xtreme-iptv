import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/date_time_utils.dart';
import '../../../epg/domain/entities/epg_entities.dart';
import '../../../favorites/domain/entities/favorite_entities.dart';
import '../../../favorites/presentation/bloc/favorites_bloc.dart';
import '../../domain/entities/live_entities.dart';

/// A single channel card in the Live TV grid.
///
/// Shows channel logo, name, current EPG program, and a favorite
/// heart toggle in the top-right corner.
class ChannelCard extends StatelessWidget {
  final LiveChannel channel;
  final EpgNowNext? epg;
  final bool isEpgLoading;
  final VoidCallback onTap;

  const ChannelCard({
    super.key,
    required this.channel,
    this.epg,
    this.isEpgLoading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final favId = FavoriteItem.buildId(FavoriteType.live, channel.streamId);

    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Channel logo + favorite button
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    child: channel.streamIcon != null &&
                            channel.streamIcon!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: channel.streamIcon!,
                            fit: BoxFit.contain,
                            placeholder: (context, url) => _placeholder(theme),
                            errorWidget: (context, url, error) =>
                                _placeholder(theme),
                          )
                        : _placeholder(theme),
                  ),
                  // Favorite heart toggle
                  Positioned(
                    top: 4,
                    right: 4,
                    child: BlocBuilder<FavoritesBloc, FavoritesState>(
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
                        return GestureDetector(
                          onTap: () {
                            context.read<FavoritesBloc>().add(
                                  ToggleFavorite(FavoriteItem(
                                    id: favId,
                                    type: FavoriteType.live,
                                    streamId: channel.streamId,
                                    name: channel.name,
                                    imageUrl: channel.streamIcon,
                                  )),
                                );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              size: 14,
                              color: isFav ? Colors.red : Colors.white70,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Channel name + EPG
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (epg?.now != null)
                      Expanded(
                        child: Text(
                          epg!.now!.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontSize: 10,
                          ),
                        ),
                      )
                    else if (isEpgLoading)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      )
                    else
                      Expanded(
                        child: Text(
                          DateTimeUtils.formatEpgRange(
                            epg?.now?.start,
                            epg?.now?.end,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(ThemeData theme) {
    return Icon(
      Icons.live_tv,
      size: 28,
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
    );
  }
}
