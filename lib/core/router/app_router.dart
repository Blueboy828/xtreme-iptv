import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

import '../constants/app_constants.dart';
import '../constants/app_routes.dart';
import '../di/injection.dart';
import '../network/server_config.dart';
import '../widgets/tv_focusable.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/live_tv/presentation/pages/live_tv_page.dart';
import '../../features/movies/presentation/pages/movies_page.dart';
import '../../features/series/presentation/pages/series_page.dart';
import '../../features/player/domain/entities/player_entities.dart';
import '../../features/player/presentation/pages/video_player_page.dart';

/// The three main sections (Search and Favorites live inside each section).
const _sectionRoutes = [
  AppRoutes.home,
  AppRoutes.movies,
  AppRoutes.series,
];

const _sectionLabels = ['Live TV', 'Movies', 'Series'];
const _sectionIcons = [
  Icons.live_tv,
  Icons.movie,
  Icons.tv,
];

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.child});

  final Widget child;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  String? _sectionToast;
  int _currentIndex = 0;
  bool _showTip = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
    _showTipIfNeeded();
  }

  /// Shows the remote-navigation tip once (persisted in Hive).
  Future<void> _showTipIfNeeded() async {
    try {
      final box = Hive.box(AppConstants.credentialsBox);
      if (box.get('nav_tip_shown') == true) return;
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      box.put('nav_tip_shown', true);
      setState(() => _showTip = true);
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted) setState(() => _showTip = false);
      });
    } catch (_) {
      // Non-fatal: never block the app because of the tip.
    }
  }

  void _dismissTip() {
    setState(() => _showTip = false);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    super.dispose();
  }

  bool _handleGlobalKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    // While the video player is open it owns the remote keys:
    // FF/Rewind seek the video instead of cycling sections.
    if (VideoPlayerPage.isPlayerOpen) return false;

    final keyId = event.logicalKey.keyId;
    final keyLabel = event.logicalKey.keyLabel.toLowerCase();
    final hidUsage = event.physicalKey.usbHidUsage;

    // Fast Forward → next section
    if (keyId == 0x100000D2C ||
        keyLabel == 'media fast forward' ||
        hidUsage == 0xC00B3) {
      _goToSection(_currentIndex + 1);
      return true;
    }

    // Rewind → previous section
    if (keyId == 0x100000D31 ||
        keyLabel == 'media rewind' ||
        hidUsage == 0xC00B4) {
      _goToSection(_currentIndex - 1);
      return true;
    }

    // Play/Pause → jump to Live TV
    if (keyId == 0x100000A05 || hidUsage == 0xC00CD) {
      if (_currentIndex != 0) {
        _goToSection(0);
        return true;
      }
    }

    return false;
  }

  void _goToSection(int index) {
    if (index < 0) index = _sectionRoutes.length - 1;
    if (index >= _sectionRoutes.length) index = 0;
    context.go(_sectionRoutes[index]);
    setState(() {
      _currentIndex = index;
      _sectionToast = _sectionLabels[index];
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _sectionToast = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    int index = 0;
    if (location.startsWith(AppRoutes.movies)) index = 1;
    if (location.startsWith(AppRoutes.series)) index = 2;
    _currentIndex = index;

    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(child: widget.child),
              _buildNavBar(context, index, theme),
            ],
          ),
          if (_sectionToast != null) _buildSectionToast(theme),
          if (_showTip) _buildNavTip(theme),
        ],
      ),
    );
  }

  /// One-time hint card explaining how to switch sections with the remote.
  Widget _buildNavTip(ThemeData theme) {
    return Positioned(
      bottom: 80,
      left: 24,
      right: 24,
      child: Center(
        child: GestureDetector(
          onTap: _dismissTip,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 560),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.97),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.primary, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.settings_remote,
                    size: 32, color: theme.colorScheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Quick Tip',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Use the ⏪ and ⏩ buttons on your remote to jump between Live TV, Movies, and Series. You can also select the arrows on this bar.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.close,
                    size: 18, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavBar(BuildContext context, int selectedIndex, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Row(
        children: [
          // ⏪ Rewind arrow — cycles to the previous section,
          // mirroring the remote's Rewind button.
          TvFocusable(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _goToSection(_currentIndex - 1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Icon(
                Icons.fast_rewind,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_sectionRoutes.length, (i) {
          final isSelected = i == selectedIndex;
          return TvFocusable(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _goToSection(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _sectionIcons[i],
                    size: 22,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _sectionLabels[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
          }),
            ),
          ),
          // ⏩ Fast-forward arrow — cycles to the next section,
          // mirroring the remote's Fast Forward button.
          TvFocusable(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _goToSection(_currentIndex + 1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Icon(
                Icons.fast_forward,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionToast(ThemeData theme) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.primary, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_sectionIcons[_currentIndex], size: 32, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  _sectionToast!,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

bool _isAuthenticated() {
  try {
    final config = getIt<ServerConfig>();
    return config.baseUrl.isNotEmpty && config.username.isNotEmpty && config.password.isNotEmpty;
  } catch (_) {
    return false;
  }
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.login,
  redirect: (context, state) {
    final isLoggedIn = _isAuthenticated();
    final isLoginRoute = state.matchedLocation == AppRoutes.login;
    if (!isLoggedIn && !isLoginRoute) return AppRoutes.login;
    if (isLoggedIn && isLoginRoute) return AppRoutes.home;
    return null;
  },
  routes: [
    GoRoute(path: AppRoutes.login, builder: (context, state) => const LoginPage()),
    ShellRoute(
      builder: (context, state, child) => HomeShell(child: child),
      routes: [
        GoRoute(path: AppRoutes.home, builder: (context, state) => const LiveTvPage()),
        GoRoute(path: AppRoutes.movies, builder: (context, state) => const MoviesPage()),
        GoRoute(path: AppRoutes.series, builder: (context, state) => const SeriesPage()),
      ],
    ),
    GoRoute(path: AppRoutes.livePlayer, builder: (context, state) {
      final config = state.extra as PlayerConfig;
      return VideoPlayerPage(config: config);
    }),
    GoRoute(path: AppRoutes.moviePlayer, builder: (context, state) {
      final config = state.extra as PlayerConfig;
      return VideoPlayerPage(config: config);
    }),
    GoRoute(path: AppRoutes.seriesPlayer, builder: (context, state) {
      final config = state.extra as PlayerConfig;
      return VideoPlayerPage(config: config);
    }),
  ],
);
