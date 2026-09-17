import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/movie_entities.dart';

/// A single movie poster card in the Movies grid.
///
/// Shows the poster image, title, and optional rating badge.
class MoviePosterCard extends StatelessWidget {
  final Movie movie;
  final VoidCallback onTap;

  const MoviePosterCard({
    super.key,
    required this.movie,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Poster image
            Expanded(
              child: Stack(
                children: [
                  Container(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    child: movie.streamIcon != null &&
                            movie.streamIcon!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: movie.streamIcon!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => _placeholder(theme),
                            errorWidget: (context, url, error) =>
                                _placeholder(theme),
                          )
                        : _placeholder(theme),
                  ),
                  // Rating badge
                  if (movie.rating != null &&
                      movie.rating!.isNotEmpty &&
                      movie.rating != 'N/A')
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                                size: 11, color: Colors.amber),
                            const SizedBox(width: 2),
                            Text(
                              movie.rating!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                movie.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(ThemeData theme) {
    return Center(
      child: Icon(
        Icons.movie,
        size: 32,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
      ),
    );
  }
}
