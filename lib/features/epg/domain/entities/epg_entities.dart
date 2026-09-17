import 'package:equatable/equatable.dart';

/// Domain entity for a single EPG (Electronic Programme Guide) entry.
class EpgEntry extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String start;        // Raw timestamp string
  final String end;          // Raw timestamp string
  final String? category;

  const EpgEntry({
    required this.id,
    required this.title,
    this.description,
    required this.start,
    required this.end,
    this.category,
  });

  @override
  List<Object?> get props => [id, title, start, end];
}

/// Domain entity representing the current + next program for a channel.
class EpgNowNext extends Equatable {
  final EpgEntry? now;
  final EpgEntry? next;

  const EpgNowNext({this.now, this.next});

  @override
  List<Object?> get props => [now, next];
}
