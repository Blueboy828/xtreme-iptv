import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/live_entities.dart';
import '../../domain/repositories/live_repository.dart';
import '../datasources/xtream_live_datasource.dart';

class LiveRepositoryImpl implements LiveRepository {
  final XtreamLiveDatasource _datasource;

  LiveRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, List<LiveCategory>>> getCategories() async {
    try {
      final raw = await _datasource.getCategories();
      final categories = raw
          .map((e) => LiveCategory(
                categoryId: e['category_id']?.toString() ?? '',
                name: e['category_name']?.toString() ?? 'Unknown',
              ))
          .toList();
      return Right(categories);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<LiveChannel>>> getChannels({
    String? categoryId,
  }) async {
    try {
      final raw = await _datasource.getStreams(categoryId: categoryId);
      final channels = raw
          .map((e) => LiveChannel(
                streamId: e['stream_id']?.toString() ?? '',
                name: e['name']?.toString() ?? 'Unknown',
                categoryId: e['category_id']?.toString() ?? '',
                streamIcon: e['stream_icon']?.toString(),
                epgChannelId: e['epg_channel_id']?.toString(),
                added: e['added']?.toString() == '1',
                tvArchive: e['tv_archive']?.toString() == '1',
              ))
          .toList();
      return Right(channels);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }
}
