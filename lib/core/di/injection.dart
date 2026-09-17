import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';

import '../constants/app_constants.dart';
import '../network/connectivity_service.dart';
import '../network/dio_factory.dart';
import '../network/server_config.dart';

import '../../features/auth/data/datasources/xtream_auth_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';

import '../../features/live_tv/data/datasources/xtream_live_datasource.dart';
import '../../features/live_tv/data/repositories/live_repository_impl.dart';
import '../../features/live_tv/domain/repositories/live_repository.dart';

import '../../features/movies/data/datasources/xtream_movies_datasource.dart';
import '../../features/movies/data/repositories/movies_repository_impl.dart';
import '../../features/movies/domain/repositories/movies_repository.dart';

import '../../features/series/data/datasources/xtream_series_datasource.dart';
import '../../features/series/data/repositories/series_repository_impl.dart';
import '../../features/series/domain/repositories/series_repository.dart';

import '../../features/epg/data/datasources/xtream_epg_datasource.dart';
import '../../features/epg/data/repositories/epg_repository_impl.dart';
import '../../features/epg/domain/repositories/epg_repository.dart';

import '../../features/favorites/data/repositories/favorites_repository_impl.dart';
import '../../features/favorites/domain/repositories/favorites_repository.dart';

import '../../features/search/data/repositories/search_repository_impl.dart';
import '../../features/search/domain/repositories/search_repository.dart';

/// Manual DI container. GetIt is used as a service locator.
/// All registrations happen in [setup] called from main().
final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  // ── Core ───────────────────────────────────────────────────────
  getIt.registerLazySingleton<ServerConfig>(() => ServerConfig());
  getIt.registerLazySingleton<ConnectivityService>(
    () => ConnectivityService(),
  );
  getIt.registerLazySingleton<Dio>(() => DioFactory.create());

  // ── Auth feature ───────────────────────────────────────────────
  getIt.registerLazySingleton<XtreamAuthDatasource>(
    () => XtreamAuthDatasource(getIt<Dio>(), getIt<ServerConfig>()),
  );
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(getIt<XtreamAuthDatasource>()),
  );

  // ── Live TV feature ────────────────────────────────────────────
  getIt.registerLazySingleton<XtreamLiveDatasource>(
    () => XtreamLiveDatasource(getIt<Dio>(), getIt<ServerConfig>()),
  );
  getIt.registerLazySingleton<LiveRepository>(
    () => LiveRepositoryImpl(getIt<XtreamLiveDatasource>()),
  );

  // ── Movies feature ─────────────────────────────────────────────
  getIt.registerLazySingleton<XtreamMoviesDatasource>(
    () => XtreamMoviesDatasource(getIt<Dio>(), getIt<ServerConfig>()),
  );
  getIt.registerLazySingleton<MoviesRepository>(
    () => MoviesRepositoryImpl(getIt<XtreamMoviesDatasource>()),
  );

  // ── Series feature ─────────────────────────────────────────────
  getIt.registerLazySingleton<XtreamSeriesDatasource>(
    () => XtreamSeriesDatasource(getIt<Dio>(), getIt<ServerConfig>()),
  );
  getIt.registerLazySingleton<SeriesRepository>(
    () => SeriesRepositoryImpl(getIt<XtreamSeriesDatasource>()),
  );

  // ── EPG feature ────────────────────────────────────────────────
  getIt.registerLazySingleton<XtreamEpgDatasource>(
    () => XtreamEpgDatasource(getIt<Dio>(), getIt<ServerConfig>()),
  );
  getIt.registerLazySingleton<EpgRepository>(
    () => EpgRepositoryImpl(getIt<XtreamEpgDatasource>()),
  );

  // ── Favorites feature ─────────────────────────────────────────
  final favoritesBox = Hive.box(AppConstants.favoritesBox);
  getIt.registerLazySingleton<FavoritesRepository>(
    () => FavoritesRepositoryImpl(favoritesBox),
  );

  // ── Search feature ────────────────────────────────────────────
  getIt.registerLazySingleton<SearchRepository>(
    () => SearchRepositoryImpl(
      getIt<XtreamLiveDatasource>(),
      getIt<XtreamMoviesDatasource>(),
      getIt<XtreamSeriesDatasource>(),
    ),
  );
}
