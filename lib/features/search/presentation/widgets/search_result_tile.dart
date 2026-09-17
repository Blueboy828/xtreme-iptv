import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/search_entities.dart';

/// A single search result tile — shows thumbnail, name, and type badge.
class SearchResultTile extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;

  const SearchResultTile({
    super.key,
    required this.result,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _buildThumbnail(theme),
      title: Text(
        result.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: _typeBadge(theme),
      onTap: onTap,
    );
  }

  Widget _buildThumbnail(ThemeData theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 50,
        height: 70,
        child: result.imageUrl != null && result.imageUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: result.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => _placeholder(theme),
                errorWidget: (context, url, error) => _placeholder(theme),
              )
            : _placeholder(theme),
      ),
    );
  }

  Widget _placeholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Icon(
        switch (result.type) {
          SearchResultType.live => Icons.live_tv,
          SearchResultType.movie => Icons.movie,
          SearchResultType.series => Icons.tv,
        },
        size: 24,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
      ),
    );
  }

  Widget _typeBadge(ThemeData theme) {
    final (label, color, icon) = switch (result.type) {
      SearchResultType.live => ('Live', Colors.red, Icons.live_tv),
      SearchResultType.movie => ('Movie', Colors.blue, Icons.movie),
      SearchResultType.series => ('Series', Colors.purple, Icons.tv),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
