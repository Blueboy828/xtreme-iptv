import 'package:equatable/equatable.dart';

/// The type of content being played — affects player behavior
/// (live streams need reconnection; VOD/series need seek bar).
enum PlayerContentType { live, vod, series }

/// Configuration passed to the player when a stream is opened.
class PlayerConfig extends Equatable {
  final String url;
  final String title;
  final String? subtitle;
  final PlayerContentType contentType;

  const PlayerConfig({
    required this.url,
    required this.title,
    this.subtitle,
    this.contentType = PlayerContentType.vod,
  });

  @override
  List<Object?> get props => [url, title, subtitle, contentType];
}
