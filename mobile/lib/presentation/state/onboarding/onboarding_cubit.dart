import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/storage_service.dart';
import '../../../data/models/preferences_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/preferences_repository.dart';

enum OnboardingStatus { initial, loading, ready, failure }

class OnboardingState extends Equatable {
  final OnboardingStatus status;
  final FilterOptionsModel options;
  final Set<String> selectedLanguages;
  final Set<String> selectedTopics;

  /// Text typed in the search box, filters both chip lists.
  final String query;
  final bool isSaving;

  /// True once saved or skipped: the screen then leaves.
  final bool isDone;
  final String? errorMessage;
  final String? actionError;

  const OnboardingState({
    this.status = OnboardingStatus.initial,
    this.options = const FilterOptionsModel(),
    this.selectedLanguages = const {},
    this.selectedTopics = const {},
    this.query = '',
    this.isSaving = false,
    this.isDone = false,
    this.errorMessage,
    this.actionError,
  });

  List<FilterOptionModel> get visibleLanguages => _filter(options.languages);
  List<FilterOptionModel> get visibleTopics => _filter(options.topics);
  int get selectedCount => selectedLanguages.length + selectedTopics.length;

  List<FilterOptionModel> _filter(List<FilterOptionModel> list) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((o) => o.name.toLowerCase().contains(q)).toList();
  }

  OnboardingState copyWith({
    OnboardingStatus? status,
    FilterOptionsModel? options,
    Set<String>? selectedLanguages,
    Set<String>? selectedTopics,
    String? query,
    bool? isSaving,
    bool? isDone,
    String? errorMessage,
    String? actionError,
  }) {
    return OnboardingState(
      status: status ?? this.status,
      options: options ?? this.options,
      selectedLanguages: selectedLanguages ?? this.selectedLanguages,
      selectedTopics: selectedTopics ?? this.selectedTopics,
      query: query ?? this.query,
      isSaving: isSaving ?? this.isSaving,
      isDone: isDone ?? this.isDone,
      errorMessage: errorMessage,
      actionError: actionError,
    );
  }

  @override
  List<Object?> get props => [
        status,
        options,
        selectedLanguages,
        selectedTopics,
        query,
        isSaving,
        isDone,
        errorMessage,
        actionError,
      ];
}

/// Choose the languages / topics the feed is personalised for (first login and Settings).
class OnboardingCubit extends Cubit<OnboardingState> {
  final PreferencesRepository preferencesRepository;
  final AuthRepository authRepository;
  final StorageService storage;

  OnboardingCubit({
    required this.preferencesRepository,
    required this.authRepository,
    required this.storage,
  }) : super(const OnboardingState());

  Future<void> load() async {
    emit(state.copyWith(status: OnboardingStatus.loading));
    try {
      final results = await Future.wait([
        preferencesRepository.getFilterOptions(),
        preferencesRepository.getPreferences(),
      ]);
      final options = results[0].data as FilterOptionsModel;
      final prefs = results[1].data as PreferencesModel;
      emit(state.copyWith(
        status: OnboardingStatus.ready,
        options: _withSelected(options, prefs),
        selectedLanguages: prefs.languages.toSet(),
        selectedTopics: prefs.topics.toSet(),
      ));
    } catch (e) {
      emit(state.copyWith(status: OnboardingStatus.failure, errorMessage: e.toString()));
    }
  }

  /// Saved choices that are no longer in the filter options still appear as chips.
  static FilterOptionsModel _withSelected(FilterOptionsModel options, PreferencesModel prefs) {
    List<FilterOptionModel> merge(List<FilterOptionModel> list, List<String> chosen) {
      final names = list.map((o) => o.name).toSet();
      return [
        ...chosen.where((c) => !names.contains(c)).map((c) => FilterOptionModel(name: c, count: 0)),
        ...list,
      ];
    }

    return FilterOptionsModel(
      languages: merge(options.languages, prefs.languages),
      topics: merge(options.topics, prefs.topics),
    );
  }

  void toggleLanguage(String name) {
    final next = {...state.selectedLanguages};
    next.contains(name) ? next.remove(name) : next.add(name);
    emit(state.copyWith(selectedLanguages: next));
  }

  void toggleTopic(String name) {
    final next = {...state.selectedTopics};
    next.contains(name) ? next.remove(name) : next.add(name);
    emit(state.copyWith(selectedTopics: next));
  }

  void setQuery(String query) => emit(state.copyWith(query: query));

  Future<void> save() async {
    emit(state.copyWith(isSaving: true));
    try {
      await preferencesRepository.savePreferences(PreferencesModel(
        languages: state.selectedLanguages.toList(),
        topics: state.selectedTopics.toList(),
      ));
      await _markDone();
      emit(state.copyWith(isSaving: false, isDone: true));
    } catch (e) {
      emit(state.copyWith(isSaving: false, actionError: e.toString()));
    }
  }

  /// "Bỏ qua": do not ask again; the feed shows popular repos.
  Future<void> skip() async {
    await _markDone();
    emit(state.copyWith(isDone: true));
  }

  Future<void> _markDone() async {
    final user = await authRepository.getStoredUser();
    if (user != null) {
      await storage.setOnboardingDone(user.id);
    }
  }
}
