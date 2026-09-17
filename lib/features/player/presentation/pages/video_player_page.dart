import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../domain/entities/player_entities.dart';
import '../bloc/player_bloc.dart';
import '../widgets/video_controls_overlay.dart';

/// Full-screen video player page.
///
/// Receives a [PlayerConfig] via the route's `extra` and initializes
/// playback on mount. Handles fullscreen orientation, auto-reconnection
/// for live streams, and dispose on pop.
class VideoPlayerPage extends StatefulWidget {
  final PlayerConfig config;

  /// True while the player page is on screen. The app's global remote
  /// handler checks this so the FF/Rewind section keys don't fire
  /// while the user is watching something.
  static bool isPlayerOpen = false;

  const VideoPlayerPage({super.key, required this.config});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  VideoController? _videoController;

  @override
  void initState() {
    super.initState();
    VideoPlayerPage.isPlayerOpen = true;
    // Force landscape for a better viewing experience.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Hide status bar.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Start playback on mount.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlayerBloc>().add(PlayerInitialize(widget.config));
    });
  }

  @override
  void dispose() {
    VideoPlayerPage.isPlayerOpen = false;
    _videoController = null;
    // Stay landscape (TV app) and restore system UI.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _exit() {
    context.read<PlayerBloc>().add(const PlayerDispose());
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: BlocBuilder<PlayerBloc, PlayerState>(
          // Only rebuild when the top-level state type changes.
          // Position/buffering updates are handled by the overlay
          // through separate BlocBuilders with their own buildWhen.
          buildWhen: (prev, curr) {
            // Rebuild when switching between initial/loading/ready/error/disposed
            return prev.runtimeType != curr.runtimeType;
          },
          builder: (context, state) {
            return switch (state) {
              PlayerInitial() || PlayerLoading() =>
                const LoadingWidget(message: 'Connecting to stream…'),
              PlayerReady() => _buildPlayer(context, state),
              PlayerErrorState() => ErrorStateWidget(
                  failure: UnexpectedFailure(message: state.message),
                  onRetry: state.config != null
                      ? () => context
                          .read<PlayerBloc>()
                          .add(PlayerInitialize(state.config!))
                      : null,
                ),
              PlayerDisposed() => const SizedBox.shrink(),
            };
          },
        ),
      ),
    );
  }

  Widget _buildPlayer(BuildContext context, PlayerReady state) {
    // Create the VideoController ONCE when the player is first ready.
    // Reusing the same controller across rebuilds prevents the video
    // surface from being destroyed and recreated (which causes flickering).
    if (_videoController == null || !identical(_videoController!.player, state.player)) {
      _videoController = VideoController(state.player);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // The actual video surface — persists across rebuilds.
        // Our custom overlay is the only control surface.
        Video(
          controller: _videoController!,
          fit: BoxFit.contain,
          fill: Colors.black,
          controls: NoVideoControls,
        ),

        // Controls overlay — uses its own BlocBuilder for live updates
        // (position, buffering, etc.) without rebuilding the video surface.
        VideoControlsOverlay(
          state: state,
          videoController: _videoController!,
        ),

        // Reconnection banner for live streams — separate BlocBuilder
        // so it updates without touching the video surface.
        BlocBuilder<PlayerBloc, PlayerState>(
          buildWhen: (prev, curr) {
            if (curr is! PlayerReady) return false;
            final ready = curr;
            return ready.isBuffering !=
                (prev is PlayerReady ? prev.isBuffering : null);
          },
          builder: (context, s) {
            if (s is! PlayerReady) return const SizedBox.shrink();
            if (!s.isBuffering ||
                s.config.contentType != PlayerContentType.live) {
              return const SizedBox.shrink();
            }
            return Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.only(top: 40, bottom: 12),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Reconnecting…',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
