import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;
  StreamSubscription<void>? _sessionExpiredSubscription;

  /// [sessionExpired] comes from ApiClient: fires when the refresh token is no longer valid.
  AuthBloc({required this.authRepository, Stream<void>? sessionExpired}) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthRegisterRequested>(_onAuthRegisterRequested);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
    on<AuthSessionExpired>(_onSessionExpired);
    on<AuthSocialLoginSucceeded>(_onAuthCheckRequested);
    on<AuthUserUpdated>((event, emit) {
      if (event.user is UserModel) {
        emit(AuthAuthenticated(event.user as UserModel));
      }
    });
    _sessionExpiredSubscription = sessionExpired?.listen((_) => add(AuthSessionExpired()));
  }

  Future<AuthAuthenticated> _authenticated(UserModel user) async {
    return AuthAuthenticated(user, needsOnboarding: await authRepository.needsOnboarding(user.id));
  }

  Future<void> _onAuthCheckRequested(
    AuthEvent event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final isAuth = await authRepository.isAuthenticated();
      if (isAuth) {
        final user = await authRepository.getStoredUser();
        if (user != null) {
          emit(await _authenticated(user));
          return;
        }
      }
      emit(const AuthUnauthenticated());
    } catch (_) {
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onAuthLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await authRepository.login(event.email, event.password);
      emit(await _authenticated(user));
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onAuthRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await authRepository.register(
        event.email,
        event.password,
        event.displayName,
      );
      emit(await _authenticated(user));
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    await authRepository.logout();
    emit(const AuthUnauthenticated());
  }

  Future<void> _onSessionExpired(
    AuthSessionExpired event,
    Emitter<AuthState> emit,
  ) async {
    if (state is AuthUnauthenticated) return;
    await authRepository.logout();
    emit(const AuthUnauthenticated(sessionExpired: true));
  }

  @override
  Future<void> close() {
    _sessionExpiredSubscription?.cancel();
    return super.close();
  }
}
