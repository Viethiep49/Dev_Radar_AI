import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';

class ProfileState extends Equatable {
  /// Avatar chosen on screen but not saved yet.
  final String? pendingAvatarUrl;
  final bool isSaving;

  /// Set once after a successful save, so the screen can update AuthBloc.
  final UserModel? savedUser;
  final String? errorMessage;

  const ProfileState({this.pendingAvatarUrl, this.isSaving = false, this.savedUser, this.errorMessage});

  ProfileState copyWith({String? pendingAvatarUrl, bool? isSaving, UserModel? savedUser, String? errorMessage}) {
    return ProfileState(
      pendingAvatarUrl: pendingAvatarUrl ?? this.pendingAvatarUrl,
      isSaving: isSaving ?? this.isSaving,
      savedUser: savedUser,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [pendingAvatarUrl, isSaving, savedUser, errorMessage];
}

/// Avatar picking and saving (PUT /auth/avatar).
class ProfileCubit extends Cubit<ProfileState> {
  final AuthRepository authRepository;

  ProfileCubit(this.authRepository) : super(const ProfileState());

  void selectAvatar(String url) => emit(state.copyWith(pendingAvatarUrl: url));

  /// Avatar of a GitHub user, e.g. "torvalds" -> https://github.com/torvalds.png
  void selectGithubAvatar(String username) {
    final name = username.trim().replaceFirst('@', '');
    if (name.isEmpty) return;
    selectAvatar('https://github.com/${Uri.encodeComponent(name)}.png');
  }

  Future<void> saveAvatar(String fallbackUrl) async {
    final url = state.pendingAvatarUrl ?? fallbackUrl;
    emit(state.copyWith(isSaving: true));
    try {
      final user = await authRepository.updateAvatar(url);
      emit(ProfileState(pendingAvatarUrl: url, savedUser: user));
    } catch (e) {
      emit(state.copyWith(isSaving: false, errorMessage: e.toString()));
    }
  }
}
