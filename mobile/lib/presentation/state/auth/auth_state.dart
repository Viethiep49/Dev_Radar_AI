import 'package:equatable/equatable.dart';
import '../../../data/models/user_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final UserModel user;

  /// True right after the first login of this user on this device:
  /// the app opens Onboarding (choose languages/topics) instead of Home.
  final bool needsOnboarding;

  const AuthAuthenticated(this.user, {this.needsOnboarding = false});

  @override
  List<Object?> get props => [user, needsOnboarding];
}

class AuthUnauthenticated extends AuthState {
  /// True when the refresh token expired (show "please log in again").
  final bool sessionExpired;

  const AuthUnauthenticated({this.sessionExpired = false});

  @override
  List<Object?> get props => [sessionExpired];
}

class AuthFailure extends AuthState {
  final String message;

  const AuthFailure(this.message);

  @override
  List<Object?> get props => [message];
}
