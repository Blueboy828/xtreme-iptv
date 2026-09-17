import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../bloc/player_bloc.dart';
import '../../domain/entities/player_entities.dart';

/// Custom overlay controls for the video player.
///
/// Shows a gradient scrim, title, play/pause, seek bar (VOD/series only),
/// volume/mute, fullscreen toggle, and a back button.
/// Auto-hides after 4 seconds of inactivity.
///
/// Uses its own BlocBuilder so position/buffering updates don't
/// rebuild the video surface (which causes flickering).
class VideoControlsOverlay extends StatefulWidget {
  final PlayerReady state;
  final VideoController videoController;

  const VideoControlsOverlay({
    super.key,
    required this.state,
    required this.videoController,
  });

  @override
  State<VideoControlsOverlay> createState() => _VideoControlsOverlayState();
}

class _VideoControlsOverlayState extends State<VideoControlsOverlay> {
  bool _visible = true;
  Timer? _hideTimer;
  bool _seeking = false;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && widget.state.isPlaying) {
        setState(() => _visible = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _visible = !_visible);
    if (_visible) {
      _startHideTimer();
    }
  }

  /// Shows the controls and restarts the auto-hide timer.
  void _showControlsAndRestartTimer() {
    if (!_visible) setState(() => _visible = true);
    _startHideTimer();
  }

  /// Seeks relative to the current position, clamped to the stream bounds.
  void _seekBy(int seconds, PlayerReady state) {
    final target = state.position + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > state.duration ? state.duration : target);
    context.read<PlayerBloc>().add(PlayerSeek(clamped));
  }

  /// Remote control handling inside the player:
  ///   ◀ / ⏪ Rewind      → skip back 10 seconds (VOD only)
  ///   ▶ / ⏩ Fast Forward → skip forward 10 seconds (VOD only)
  ///   Select / OK / Enter → play / pause
  ///   ▲ / ▼              → show the controls
  KeyEventResult _handleRemoteKey(FocusNode node, KeyEvent event, PlayerReady state) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isLive = state.config.contentType == PlayerContentType.live;
    final canSeek = !isLive && state.duration > Duration.zero;

    final keyId = event.logicalKey.keyId;
    final keyLabel = event.logicalKey.keyLabel.toLowerCase();
    final hidUsage = event.physicalKey.usbHidUsage;

    final isBack = event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        keyId == 0x100000D31 ||
        keyLabel == 'media rewind' ||
        hidUsage == 0xC00B4;
    final isForward = event.logicalKey == LogicalKeyboardKey.arrowRight ||
        keyId == 0x100000D2C ||
        keyLabel == 'media fast forward' ||
        hidUsage == 0xC00B3;
    final isSelect = event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.space;
    final isVertical = event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.arrowDown;

    if (isBack || isForward) {
      _showControlsAndRestartTimer();
      if (canSeek) _seekBy(isBack ? -10 : 10, state);
      return KeyEventResult.handled;
    }
    if (isSelect) {
      _showControlsAndRestartTimer();
      context.read<PlayerBloc>().add(const PlayerTogglePlayPause());
      return KeyEventResult.handled;
    }
    if (isVertical) {
      _showControlsAndRestartTimer();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlayerBloc, PlayerState>(
      // This BlocBuilder gets all the fine-grained updates
      // (position, buffering, playing) WITHOUT rebuilding the video surface.
      buildWhen: (prev, curr) => curr is PlayerReady,
      builder: (context, state) {
        if (state is! PlayerReady) return const SizedBox.shrink();
        final isLive = state.config.contentType == PlayerContentType.live;
        final canSeek = !isLive && state.duration > Duration.zero;

        return Focus(
          autofocus: true,
          onKeyEvent: (node, event) => _handleRemoteKey(node, event, state),
          child: GestureDetector(
            onTap: _toggleControls,
          child: AnimatedOpacity(
            opacity: _visible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black54,
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black54,
                  ],
                  stops: [0, 0.15, 0.85, 1],
                ),
              ),
              child: _visible ? _buildControls(context, state, canSeek, isLive) : null,
            ),
          ),
          ),
        );
      },
    );
  }

  Widget _buildControls(BuildContext context, PlayerReady state, bool canSeek, bool isLive) {
    return Column(
      children: [
        _buildTopBar(context, state),
        const Spacer(),
        _buildCenterControls(context, state),
        const Spacer(),
        _buildBottomBar(context, state, canSeek, isLive),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context, PlayerReady state) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () { context.read<PlayerBloc>().add(const PlayerDispose()); context.pop(); },
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.config.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (state.config.subtitle != null)
                    Text(
                      state.config.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterControls(BuildContext context, PlayerReady state) {
    final isLive = state.config.contentType == PlayerContentType.live;
    final canSeek = !isLive && state.duration > Duration.zero;

    return Center(
      child: state.isBuffering
          ? const SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ⏪ Skip back 10s (VOD only)
                if (canSeek) _skipButton(
                  Icons.replay_10,
                  'Skip back 10 seconds',
                  () => _seekBy(-10, state),
                ),
                if (canSeek) const SizedBox(width: 36),
                // Play / pause
                GestureDetector(
                  onTap: () => context
                      .read<PlayerBloc>()
                      .add(const PlayerTogglePlayPause()),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Icon(
                      state.isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (canSeek) const SizedBox(width: 36),
                // ⏩ Skip forward 10s (VOD only)
                if (canSeek) _skipButton(
                  Icons.forward_10,
                  'Skip forward 10 seconds',
                  () => _seekBy(10, state),
                ),
              ],
            ),
    );
  }

  /// Round transparent skip button (-10s / +10s).
  Widget _skipButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 32),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }

  Widget _buildBottomBar(BuildContext context, PlayerReady state, bool canSeek, bool isLive) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canSeek)
              Row(
                children: [
                  Text(
                    _formatDuration(state.position),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Expanded(
                    child: Slider(
                      value: state.position.inMilliseconds.toDouble().clamp(
                            0,
                            state.duration.inMilliseconds.toDouble(),
                          ),
                      max: state.duration.inMilliseconds.toDouble(),
                      onChanged: (value) {
                        setState(() => _seeking = true);
                      },
                      onChangeEnd: (value) {
                        context.read<PlayerBloc>().add(
                              PlayerSeek(Duration(milliseconds: value.toInt())),
                            );
                        setState(() => _seeking = false);
                        _startHideTimer();
                      },
                      activeColor: Theme.of(context).colorScheme.primary,
                      inactiveColor: Colors.white24,
                    ),
                  ),
                  Text(
                    _formatDuration(state.duration),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              )
            else if (isLive)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
                    SizedBox(width: 6),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    state.isMuted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                    size: 22,
                  ),
                  onPressed: () => context
                      .read<PlayerBloc>()
                      .add(const PlayerToggleMute()),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    state.isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    color: Colors.white,
                    size: 22,
                  ),
                  onPressed: () {
                    if (state.isFullscreen) {
                      SystemChrome.setPreferredOrientations([
                        DeviceOrientation.portraitUp,
                      ]);
                    } else {
                      SystemChrome.setPreferredOrientations([
                        DeviceOrientation.landscapeLeft,
                      ]);
                    }
                    context
                        .read<PlayerBloc>()
                        .add(const PlayerToggleFullscreen());
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
