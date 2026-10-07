import 'package:dev_radar_ai/core/notifications/local_notification_service.dart';
import 'package:dev_radar_ai/core/utils/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// In-memory StorageService for the settings that the cubits/services read and write.
class MemoryStorage extends Fake implements StorageService {
  final Map<String, Object> values = {};
  final Set<int> onboardingDone = {};

  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;

  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;

  @override
  Future<int?> getInt(String key) async => values[key] as int?;

  @override
  Future<void> setInt(String key, int value) async => values[key] = value;

  @override
  Future<bool> isOnboardingDone(int userId) async => onboardingDone.contains(userId);

  @override
  Future<void> setOnboardingDone(int userId) async => onboardingDone.add(userId);
}

class MockLocalNotificationService extends Mock implements LocalNotificationService {}

/// Minimal backend JSON for a RepoBrief.
Map<String, dynamic> repoBriefJson(int id, {String fullName = 'owner/repo'}) => {
      'id': id,
      'full_name': fullName,
      'owner': fullName.split('/').first,
      'name': fullName.split('/').last,
      'description': null,
      'language': 'Dart',
      'stars': 10,
      'owner_avatar_url': null,
    };
