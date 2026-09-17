import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/player_entities.dart';

// ── States ──────────────────────────────────────────────────────
sealed class PlayerState extends Equatable {
  const PlayerState();

  @override
  List<Object?> get props => [];
}

class PlayerInitial extends PlayerState {
  const PlayerInitial();
}

class PlayerLoading extends PlayerState {
  const PlayerLoading();
}

class PlayerReady extends PlayerState {
  final Player player;
  final PlayerConfig config;
  final bool isPlaying;
  final bool isBuffering;
  final Duration position;
  final Duration duration;
  final double volume;
  final bool isFullscreen;
  final bool isMuted;
  final int reconnectCount;

  const PlayerReady({
    required this.player,
    required this.config,
    this.isPlaying = false,
    this.isBuffering = true,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
    this.isFullscreen = false,
    this.isMuted = false,
    this.reconnectCount = 0,
  });

  PlayerReady copyWith({
    Player? player,
    PlayerConfig? config,
    bool? isPlaying,
    bool? isBuffering,
    Duration? position,
    Duration? duration,
    double? volume,
    bool? isFullscreen,
    bool? isMuted,
    int? reconnectCount,
  }) {
    return PlayerReady(
      player: player ?? this.player,
      config: config ?? this.config,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      isFullscreen: isFullscreen ?? this.isFullscreen,
      isMuted: isMuted ?? this.isMuted,
      reconnectCount: reconnectCount ?? this.reconnectCount,
    );
  }

  @override
  List<Object?> get props => [
        config, isPlaying, isBuffering, position, duration, volume,
        isFullscreen, isMuted, reconnectCount,
      ];
}

class PlayerErrorState extends PlayerState {
  final String message;
  final PlayerConfig? config;
  final int retryCount;
  final bool canRetry;

  const PlayerErrorState({
    required this.message,
    this.config,
    this.retryCount = 0,
    this.canRetry = true,
  });

  @override
  List<Object?> get props => [message, config, retryCount, canRetry];
}

class PlayerDisposed extends PlayerState {
  const PlayerDisposed();
}

// ── Events ──────────────────────────────────────────────────────
sealed class PlayerEvent extends Equatable {
  const PlayerEvent();

  @override
  List<Object?> get props => [];
}

class PlayerInitialize extends PlayerEvent {
  final PlayerConfig config;
  const PlayerInitialize(this.config);

  @override
  List<Object?> get props => [config];
}

class PlayerTogglePlayPause extends PlayerEvent {
  const PlayerTogglePlayPause();
}

class PlayerSeek extends PlayerEvent {
  final Duration position;
  const PlayerSeek(this.position);

  @override
  List<Object?> get props => [position];
}

class PlayerSetVolume extends PlayerEvent {
  final double volume;
  const PlayerSetVolume(this.volume);

  @override
  List<Object?> get props => [volume];
}

class PlayerToggleMute extends PlayerEvent {
  const PlayerToggleMute();
}

class PlayerToggleFullscreen extends PlayerEvent {
  const PlayerToggleFullscreen();
}

class PlayerReconnect extends PlayerEvent {
  const PlayerReconnect();
}

class PlayerPositionChanged extends PlayerEvent {
  final Duration position;
  const PlayerPositionChanged(this.position);

  @override
  List<Object?> get props => [position];
}

class PlayerDurationChanged extends PlayerEvent {
  final Duration duration;
  const PlayerDurationChanged(this.duration);

  @override
  List<Object?> get props => [duration];
}

class PlayerPlayingStateChanged extends PlayerEvent {
  final bool isPlaying;
  const PlayerPlayingStateChanged(this.isPlaying);

  @override
  List<Object?> get props => [isPlaying];
}

class PlayerBufferingChanged extends PlayerEvent {
  final bool isBuffering;
  const PlayerBufferingChanged(this.isBuffering);

  @override
  List<Object?> get props => [isBuffering];
}

class PlayerError extends PlayerEvent {
  final String message;
  const PlayerError(this.message);

  @override
  List<Object?> get props => [message];
}

class PlayerDispose extends PlayerEvent {
  const PlayerDispose();
}

// ── BLoC ────────────────────────────────────────────────────────
class PlayerBloc extends Bloc<PlayerEvent, PlayerState> {
  Player? _player;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool>? _bufferingSub;
  StreamSubscription<dynamic>? _errorSub;

  int _reconnectAttempts = 0;
  Timer? _autoReconnectTimer;
  bool _isAutoReconnecting = false;

  PlayerBloc() : super(const PlayerInitial()) {
    on<PlayerInitialize>(_onInitialize);
    on<PlayerTogglePlayPause>(_onTogglePlayPause);
    on<PlayerSeek>(_onSeek);
    on<PlayerSetVolume>(_onSetVolume);
    on<PlayerToggleMute>(_onToggleMute);
    on<PlayerToggleFullscreen>(_onToggleFullscreen);
    on<PlayerReconnect>(_onReconnect);
    on<PlayerPositionChanged>(_onPositionChanged);
    on<PlayerDurationChanged>(_onDurationChanged);
    on<PlayerPlayingStateChanged>(_onPlayingStateChanged);
    on<PlayerBufferingChanged>(_onBufferingChanged);
    on<PlayerError>(_onPlayerError);
    on<PlayerDispose>(_onDispose);
  }

  /// Computes exponential backoff delay for reconnection attempts.
  /// 2s, 4s, 8s, 16s, 32s (capped at 30s).
  Duration _getReconnectDelay() {
    final delaySeconds = AppConstants.playerReconnectBaseDelay.inSeconds *
        (1 << _reconnectAttempts); // 2^attempt
    return Duration(seconds: delaySeconds.clamp(1, 30));
  }

  Future<void> _onInitialize(
    PlayerInitialize event,
    Emitter<PlayerState> emit,
  ) async {
    emit(const PlayerLoading());
    _reconnectAttempts = 0;
    _isAutoReconnecting = false;
    _autoReconnectTimer?.cancel();

    // Dispose any existing player.
    await _disposeStreams();

    _player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 32 * 1024 * 1024, // 32MB buffer for smoother streaming
      ),
    );

    _attachListeners();

    try {
      // Some Xtream Codes servers reject requests without a User-Agent.
      // We pass one that mimics a standard media player.
      await _player!.open(Media(
        event.config.url,
        httpHeaders: {
          'User-Agent': 'VLC/3.0.20 LibVLC/3.0.20',
        },
      ));
      emit(PlayerReady(
        player: _player!,
        config: event.config,
        isPlaying: true,
        isBuffering: true,
      ));
    } catch (e) {
      emit(PlayerErrorState(
        message: 'Failed to load stream: $e',
        config: event.config,
      ));
    }
  }

  void _attachListeners() {
    _positionSub = _player!.stream.position.listen((pos) {
      add(PlayerPositionChanged(pos));
    });

    _durationSub = _player!.stream.duration.listen((dur) {
      add(PlayerDurationChanged(dur));
    });

    _playingSub = _player!.stream.playing.listen((playing) {
      add(PlayerPlayingStateChanged(playing));
    });

    _bufferingSub = _player!.stream.buffering.listen((buffering) {
      add(PlayerBufferingChanged(buffering));
    });

    _errorSub = _player!.stream.error.listen((dynamic error) {
      final msg = error is String ? error : (error.message?.toString() ?? 'Playback error'); add(PlayerError(msg));
    });
  }

  Future<void> _disposeStreams() async {
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _playingSub?.cancel();
    await _bufferingSub?.cancel();
    await _errorSub?.cancel();
    _positionSub = null;
    _durationSub = null;
    _playingSub = null;
    _bufferingSub = null;
    _errorSub = null;
  }

  void _onTogglePlayPause(
    PlayerTogglePlayPause event,
    Emitter<PlayerState> emit,
  ) {
    final state = this.state;
    if (state is PlayerReady) {
      if (state.isPlaying) {
        _player?.pause();
      } else {
        _player?.play();
      }
    }
  }

  void _onSeek(PlayerSeek event, Emitter<PlayerState> emit) {
    final state = this.state;
    if (state is PlayerReady) {
      _player?.seek(event.position);
      emit(state.copyWith(position: event.position));
    }
  }

  void _onSetVolume(PlayerSetVolume event, Emitter<PlayerState> emit) {
    final state = this.state;
    if (state is PlayerReady) {
      _player?.setVolume(event.volume);
      emit(state.copyWith(volume: event.volume, isMuted: event.volume == 0));
    }
  }

  void _onToggleMute(PlayerToggleMute event, Emitter<PlayerState> emit) {
    final state = this.state;
    if (state is PlayerReady) {
      final newMuted = !state.isMuted;
      _player?.setVolume(newMuted ? 0 : state.volume);
      emit(state.copyWith(isMuted: newMuted));
    }
  }

  void _onToggleFullscreen(
    PlayerToggleFullscreen event,
    Emitter<PlayerState> emit,
  ) {
    final state = this.state;
    if (state is PlayerReady) {
      emit(state.copyWith(isFullscreen: !state.isFullscreen));
    }
  }

  Future<void> _onReconnect(
    PlayerReconnect event,
    Emitter<PlayerState> emit,
  ) async {
    final state = this.state;
    final config = state is PlayerReady
        ? state.config
        : state is PlayerErrorState
            ? state.config
            : null;

    if (config == null) return;

    _reconnectAttempts++;
    _isAutoReconnecting = false;

    if (_reconnectAttempts > AppConstants.maxPlayerReconnects) {
      emit(PlayerErrorState(
        message:
            'Unable to reconnect after ${AppConstants.maxPlayerReconnects} attempts',
        config: config,
        retryCount: _reconnectAttempts,
        canRetry: false,
      ));
      return;
    }

    emit(const PlayerLoading());

    try {
      await _player?.open(Media(
        config.url,
        httpHeaders: {
          'User-Agent': 'VLC/3.0.20 LibVLC/3.0.20',
        },
      ));
      emit(PlayerReady(
        player: _player!,
        config: config,
        isPlaying: true,
        isBuffering: true,
        reconnectCount: _reconnectAttempts,
      ));
      _reconnectAttempts = 0;
    } catch (e) {
      emit(PlayerErrorState(
        message: 'Reconnection failed (attempt $_reconnectAttempts): $e',
        config: config,
        retryCount: _reconnectAttempts,
      ));
    }
  }

  void _onPositionChanged(
    PlayerPositionChanged event,
    Emitter<PlayerState> emit,
  ) {
    final state = this.state;
    if (state is PlayerReady) {
      emit(state.copyWith(position: event.position));
    }
  }

  void _onDurationChanged(
    PlayerDurationChanged event,
    Emitter<PlayerState> emit,
  ) {
    final state = this.state;
    if (state is PlayerReady) {
      emit(state.copyWith(duration: event.duration));
    }
  }

  void _onPlayingStateChanged(
    PlayerPlayingStateChanged event,
    Emitter<PlayerState> emit,
  ) {
    final state = this.state;
    if (state is PlayerReady) {
      emit(state.copyWith(isPlaying: event.isPlaying));
    }
  }

  void _onBufferingChanged(
    PlayerBufferingChanged event,
    Emitter<PlayerState> emit,
  ) {
    final state = this.state;
    if (state is PlayerReady) {
      emit(state.copyWith(isBuffering: event.isBuffering));
    }
  }

  void _onPlayerError(PlayerError event, Emitter<PlayerState> emit) {
    final state = this.state;
    final config = state is PlayerReady
        ? state.config
        : state is PlayerErrorState
            ? state.config
            : null;

    if (config == null) {
      emit(PlayerErrorState(message: event.message, config: null));
      return;
    }

    // For live streams, auto-attempt reconnection with exponential backoff.
    // For VOD/series, show error and let user manually retry.
    if (config.contentType == PlayerContentType.live &&
        !_isAutoReconnecting &&
        _reconnectAttempts < AppConstants.maxPlayerReconnects) {
      _isAutoReconnecting = true;
      final delay = _getReconnectDelay();

      emit(PlayerErrorState(
        message:
            'Stream error. Reconnecting in ${delay.inSeconds}s (attempt ${_reconnectAttempts + 1}/${AppConstants.maxPlayerReconnects})…',
        config: config,
        retryCount: _reconnectAttempts,
        canRetry: true,
      ));

      _autoReconnectTimer?.cancel();
      _autoReconnectTimer = Timer(delay, () {
        add(const PlayerReconnect());
      });
    } else {
      emit(PlayerErrorState(
        message: event.message,
        config: config,
        retryCount: _reconnectAttempts,
        canRetry: _reconnectAttempts < AppConstants.maxPlayerReconnects,
      ));
    }
  }

  Future<void> _onDispose(
    PlayerDispose event,
    Emitter<PlayerState> emit,
  ) async {
    _autoReconnectTimer?.cancel();
    await _disposeStreams();
    await _player?.dispose();
    _player = null;
    emit(const PlayerDisposed());
  }

  @override
  Future<void> close() async {
    _autoReconnectTimer?.cancel();
    await _disposeStreams();
    await _player?.dispose();
    return super.close();
  }
}
