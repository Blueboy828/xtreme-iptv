import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/epg_entities.dart';

/// Contract for EPG data operations.
abstract class EpgRepository {
  /// Returns short EPG (now + next) for a given live stream ID.
  Future<Either<Failure, EpgNowNext>> getShortEpg(String streamId);

  /// Returns full EPG list for a given stream ID (limited by `limit`).
  Future<Either<Failure, List<EpgEntry>>> getFullEpg(
    String streamId, {
    int limit = 50,
  });
}
