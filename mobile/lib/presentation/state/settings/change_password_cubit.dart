import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/auth_repository.dart';

enum ChangePasswordStatus { idle, submitting, success, failure }

class ChangePasswordState extends Equatable {
  final ChangePasswordStatus status;
  final String? errorMessage;

  const ChangePasswordState({this.status = ChangePasswordStatus.idle, this.errorMessage});

  @override
  List<Object?> get props => [status, errorMessage];
}

class ChangePasswordCubit extends Cubit<ChangePasswordState> {
  final AuthRepository authRepository;

  ChangePasswordCubit(this.authRepository) : super(const ChangePasswordState());

  /// [oldPassword] may be empty for Google/GitHub accounts that have no password yet.
  Future<void> submit({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final error = validate(newPassword: newPassword, confirmPassword: confirmPassword);
    if (error != null) {
      emit(ChangePasswordState(status: ChangePasswordStatus.failure, errorMessage: error));
      return;
    }
    emit(const ChangePasswordState(status: ChangePasswordStatus.submitting));
    try {
      await authRepository.changePassword(oldPassword, newPassword);
      emit(const ChangePasswordState(status: ChangePasswordStatus.success));
    } catch (e) {
      emit(ChangePasswordState(status: ChangePasswordStatus.failure, errorMessage: e.toString()));
    }
  }

  static String? validate({required String newPassword, required String confirmPassword}) {
    if (newPassword.isEmpty) return 'Vui lòng nhập mật khẩu mới';
    if (newPassword.length < 6) return 'Mật khẩu mới phải từ 6 ký tự trở lên';
    if (newPassword.length > 72) return 'Mật khẩu mới tối đa 72 ký tự';
    if (newPassword != confirmPassword) return 'Mật khẩu xác nhận không khớp';
    return null;
  }
}
