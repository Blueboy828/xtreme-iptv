import 'package:equatable/equatable.dart';

/// The type of content that can be favorited.
enum FavoriteType { live, movie, series }

/// A single favorited item stored locally in Hive.
///
/// Contains just enough data to render a card and navigate
/// to the correct details/player page without an API call.
class FavoriteItem extends Equatable {
  final String id;          // unique: "${type}_${streamId}"
  final FavoriteType type;
  final String streamId;
  final String name;
  final String? imageUrl;
  final String? extra;      // container extension for VOD/series, or category name for live

  const FavoriteItem({
    required this.id,
    required this.type,
    required this.streamId,
    required this.name,
    this.imageUrl,
    this.extra,
  });

  /// Build a unique key for Hive storage.
  static String buildId(FavoriteType type, String streamId) =>
      '${type.name}_$streamId';

  /// Convert to Hive-friendly Map.
  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'streamId': streamId,
        'name': name,
        'imageUrl': imageUrl,
        'extra': extra,
      };

  /// Reconstruct from Hive Map.
  factory FavoriteItem.fromMap(Map<dynamic, dynamic> map) => FavoriteItem(
        id: map['id'] as String,
        type: FavoriteType.values.byName(map['type'] as String),
        streamId: map['streamId'] as String,
        name: map['name'] as String,
        imageUrl: map['imageUrl'] as String?,
        extra: map['extra'] as String?,
      );

  @override
  List<Object?> get props => [id, type, streamId, name, imageUrl, extra];
}
