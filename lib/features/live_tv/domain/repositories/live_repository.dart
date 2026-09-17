import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/live_entities.dart';

/// Contract for Live TV data operations.
abstract class LiveRepository {
  Future<Either<Failure, List<LiveCategory>>> getCategories();
  Future<Either<Failure, List<LiveChannel>>> getChannels({String? categoryId});
}
