import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/stats_model.dart';
import '../../../data/repositories/stats_repository.dart';

enum StatsStatus { initial, loading, loaded, failure }

class StatsState extends Equatable {
  final StatsStatus status;
  final StatsOverviewModel? overview;
  final List<WeeklyStatModel> weekly;
  final List<LanguageStatModel> languages;

  /// Number of weeks shown in the bar chart (4 / 8 / 12).
  final int weeks;
  final bool fromCache;
  final DateTime? cachedAt;
  final String? errorMessage;

  const StatsState({
    this.status = StatsStatus.initial,
    this.overview,
    this.weekly = const [],
    this.languages = const [],
    this.weeks = 8,
    this.fromCache = false,
    this.cachedAt,
    this.errorMessage,
  });

  /// True when the user has nothing on the learning path yet.
  bool get isEmpty => (overview?.totalRepos ?? 0) == 0 && languages.isEmpty;

  StatsState copyWith({
    StatsStatus? status,
    StatsOverviewModel? overview,
    List<WeeklyStatModel>? weekly,
    List<LanguageStatModel>? languages,
    int? weeks,
    bool? fromCache,
    DateTime? cachedAt,
    String? errorMessage,
  }) {
    return StatsState(
      status: status ?? this.status,
      overview: overview ?? this.overview,
      weekly: weekly ?? this.weekly,
      languages: languages ?? this.languages,
      weeks: weeks ?? this.weeks,
      fromCache: fromCache ?? this.fromCache,
      cachedAt: cachedAt ?? this.cachedAt,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, overview, weekly, languages, weeks, fromCache, cachedAt, errorMessage];
}

/// Loads overview + weekly + languages for the Stats tab (and the Settings summary).
class StatsCubit extends Cubit<StatsState> {
  final StatsRepository statsRepository;

  StatsCubit(this.statsRepository) : super(const StatsState());

  Future<void> load() async {
    // Keep showing the old charts during a pull-to-refresh.
    if (state.overview == null) {
      emit(state.copyWith(status: StatsStatus.loading));
    }
    try {
      final results = await Future.wait([
        statsRepository.getOverview(),
        statsRepository.getWeekly(weeks: state.weeks),
        statsRepository.getLanguages(),
      ]);
      final overview = results[0];
      final weekly = results[1];
      final languages = results[2];
      final fromCache = overview.fromCache || weekly.fromCache || languages.fromCache;
      emit(state.copyWith(
        status: StatsStatus.loaded,
        overview: overview.data as StatsOverviewModel,
        weekly: weekly.data as List<WeeklyStatModel>,
        languages: languages.data as List<LanguageStatModel>,
        fromCache: fromCache,
        cachedAt: overview.cachedAt ?? weekly.cachedAt ?? languages.cachedAt,
      ));
    } catch (e) {
      emit(state.copyWith(status: StatsStatus.failure, errorMessage: e.toString()));
    }
  }

  /// Switches the bar chart range and reloads only the weekly data.
  Future<void> changeWeeks(int weeks) async {
    if (weeks == state.weeks) return;
    emit(state.copyWith(weeks: weeks));
    try {
      final weekly = await statsRepository.getWeekly(weeks: weeks);
      emit(state.copyWith(weekly: weekly.data, fromCache: weekly.fromCache || state.fromCache));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }
}
