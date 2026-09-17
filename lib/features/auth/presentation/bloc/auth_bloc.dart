import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/auth_entities.dart';
import '../../domain/repositories/auth_repository.dart';

// ── States ──────────────────────────────────────────────────────
sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final AuthResult result;
  const AuthAuthenticated(this.result);

  @override
  List<Object?> get props => [result];
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

class AuthCheckingStored extends AuthState {
  const AuthCheckingStored();
}

// ── Events ──────────────────────────────────────────────────────
sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class LoginRequested extends AuthEvent {
  final String baseUrl;
  final String username;
  final String password;

  const LoginRequested({
    required this.baseUrl,
    required this.username,
    required this.password,
  });

  @override
  List<Object?> get props => [baseUrl, username, password];
}

class CheckStoredCredentials extends AuthEvent {
  const CheckStoredCredentials();
}

class LogoutRequested extends AuthEvent {
  const LogoutRequested();
}

// ── BLoC ────────────────────────────────────────────────────────
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repository;

  AuthBloc(this._repository) : super(const AuthInitial()) {
    on<CheckStoredCredentials>(_onCheckStored);
    on<LoginRequested>(_onLogin);
    on<LogoutRequested>(_onLogout);
  }

  Future<void> _onCheckStored(
    CheckStoredCredentials event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthCheckingStored());
    final credentials = await _repository.getStoredCredentials();
    if (credentials != null) {
      // Try auto-login with stored credentials.
      final result = await _repository.authenticate(
        baseUrl: credentials.baseUrl,
        username: credentials.username,
        password: credentials.password,
      );
      result.fold(
        (failure) => emit(const AuthInitial()),
        (authResult) => emit(AuthAuthenticated(authResult)),
      );
    } else {
      emit(const AuthInitial());
    }
  }

  Future<void> _onLogin(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await _repository.authenticate(
      baseUrl: event.baseUrl,
      username: event.username,
      password: event.password,
    );

    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (authResult) => emit(AuthAuthenticated(authResult)),
    );
  }

  Future<void> _onLogout(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _repository.clearCredentials();
    emit(const AuthInitial());
  }
}
