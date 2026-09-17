import 'dart:convert';

import 'package:dartz/dartz.dart';

import '../../../../core/utils/date_time_utils.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/epg_entities.dart';
import '../../domain/repositories/epg_repository.dart';
import '../datasources/xtream_epg_datasource.dart';

class EpgRepositoryImpl implements EpgRepository {
  final XtreamEpgDatasource _datasource;

  EpgRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, EpgNowNext>> getShortEpg(String streamId) async {
    try {
      final raw = await _datasource.getShortEpg(streamId);
      final entries = raw.map(_parseEntry).toList();

      // The first entry is the program the server says is on NOW.
      // Use it to auto-detect the panel's EPG clock (UTC vs local vs offset)
      // so all guide times display in the user's real local time.
      if (entries.isNotEmpty) {
        DateTimeUtils.calibrateEpgClock(entries.first.start, entries.first.end);
      }

      EpgEntry? now;
      EpgEntry? next;

      if (entries.isNotEmpty) {
        now = entries.first;
      }
      if (entries.length > 1) {
        next = entries[1];
      }

      return Right(EpgNowNext(now: now, next: next));
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<EpgEntry>>> getFullEpg(
    String streamId, {
    int limit = 50,
  }) async {
    try {
      final raw = await _datasource.getFullEpg(streamId, limit: limit);
      final entries = raw.map(_parseEntry).toList();
      return Right(entries);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  /// Parses a raw Xtream EPG listing into [EpgEntry].
  /// Xtream often returns title/description as base64-encoded strings.
  EpgEntry _parseEntry(Map<String, dynamic> raw) {
    return EpgEntry(
      id: raw['id']?.toString() ?? '',
      title: _decode(raw['title']),
      description: _decode(raw['description']),
      start: raw['start']?.toString() ?? '',
      end: raw['end']?.toString() ?? '',
      category: raw['category']?.toString(),
    );
  }

  /// Decodes base64 strings that Xtream sometimes returns for EPG fields.
  /// Falls back to raw string if not base64.
  String _decode(dynamic value) {
    if (value == null) return '';
    final str = value.toString();

    // Xtream EPG entries are often base64-encoded.
    // Try base64 first, fall back to raw.
    try {
      final decoded = utf8.decode(base64.decode(str));
      return decoded.trim().isEmpty ? str : decoded;
    } catch (_) {
      return str;
    }
  }
}
