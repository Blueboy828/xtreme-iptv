import 'package:equatable/equatable.dart';

/// Domain entity for a Live TV channel category.
class LiveCategory extends Equatable {
  final String categoryId;
  final String name;

  const LiveCategory({required this.categoryId, required this.name});

  @override
  List<Object> get props => [categoryId, name];
}

/// Domain entity for a Live TV channel.
class LiveChannel extends Equatable {
  final String streamId;
  final String name;
  final String categoryId;
  final String? streamIcon;
  final String? epgChannelId;
  final bool added;
  final bool tvArchive;

  const LiveChannel({
    required this.streamId,
    required this.name,
    required this.categoryId,
    this.streamIcon,
    this.epgChannelId,
    this.added = false,
    this.tvArchive = false,
  });

  @override
  List<Object?> get props => [streamId, name, categoryId, streamIcon];
}
