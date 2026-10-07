import 'package:equatable/equatable.dart';
import '../../../data/models/repo_model.dart';

abstract class RepoState extends Equatable {
  const RepoState();

  @override
  List<Object?> get props => [];
}

class RepoInitial extends RepoState {}

class RepoLoading extends RepoState {}

class RepoLoaded extends RepoState {
  final List<RepoModel> repos;
  final String? selectedLanguage;

  const RepoLoaded({required this.repos, this.selectedLanguage});

  @override
  List<Object?> get props => [repos, selectedLanguage];
}

class RepoFailure extends RepoState {
  final String message;

  const RepoFailure(this.message);

  @override
  List<Object?> get props => [message];
}
