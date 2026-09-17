import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:media_kit/media_kit.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/di/injection.dart';
import 'core/widgets/splash_screen.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/favorites/domain/repositories/favorites_repository.dart';
import 'features/favorites/presentation/bloc/favorites_bloc.dart';
import 'features/player/presentation/bloc/player_bloc.dart';
import 'features/live_tv/domain/repositories/live_repository.dart';
import 'features/live_tv/presentation/bloc/live_tv_bloc.dart';
import 'features/epg/domain/repositories/epg_repository.dart';
import 'features/movies/domain/repositories/movies_repository.dart';
import 'features/movies/presentation/bloc/movies_bloc.dart';
import 'features/series/domain/repositories/series_repository.dart';
import 'features/series/presentation/bloc/series_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize media_kit (libmpv) for video playback.
  MediaKit.ensureInitialized();

  // Initialize Hive for local storage (favorites, credentials cache).
  await Hive.initFlutter();
  await Hive.openBox(AppConstants.favoritesBox);
  await Hive.openBox(AppConstants.credentialsBox);

  // Set up dependency injection.
  await setupDependencies();

  runApp(const XtremeIptvApp());
}

class XtremeIptvApp extends StatefulWidget {
  const XtremeIptvApp({super.key});

  @override
  State<XtremeIptvApp> createState() => _XtremeIptvAppState();
}

class _XtremeIptvAppState extends State<XtremeIptvApp> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => AuthBloc(getIt<AuthRepository>()),
        ),
        BlocProvider(
          create: (_) => PlayerBloc(),
        ),
        BlocProvider(
          create: (_) =>
              FavoritesBloc(getIt<FavoritesRepository>())..add(const LoadFavorites()),
        ),
        // Global blocs so state survives navigation to/from player.
        BlocProvider(
          create: (_) => LiveTvBloc(
            getIt<LiveRepository>(),
            getIt<EpgRepository>(),
          )..add(const LoadCategories()),
        ),
        BlocProvider(
          create: (_) => MoviesBloc(
            getIt<MoviesRepository>(),
          )..add(const LoadMovieCategories()),
        ),
        BlocProvider(
          create: (_) => SeriesBloc(
            getIt<SeriesRepository>(),
          )..add(const LoadSeriesCategories()),
        ),
      ],
      child: MaterialApp.router(
        title: 'Xtreme IPTV',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        routerConfig: _showSplash ? _splashRouter : appRouter,
      ),
    );
  }

  late final GoRouter _splashRouter = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => SplashScreen(
          onDone: () {
            setState(() => _showSplash = false);
          },
        ),
      ),
    ],
  );
}
