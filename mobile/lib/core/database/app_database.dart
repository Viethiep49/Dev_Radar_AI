import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// The app's local SQLite database (sqflite).
///
/// Table `cache`: one row per cached API response, stored as JSON text.
///   key        TEXT PRIMARY KEY  e.g. "feed:page=1", "repo_detail:42", "collections"
///   json       TEXT              the response body
///   updated_at INTEGER           unix millis, shown as "cached at ..." when offline
class AppDatabase {
  AppDatabase._(this.db);

  static const String fileName = 'devradar.db';
  static const int version = 1;
  static const String cacheTable = 'cache';

  final Database db;

  /// Opens (and creates on first run) the database file in the app's databases dir.
  /// [factory] and [path] can be overridden in tests (e.g. sqflite_common_ffi + inMemoryDatabasePath).
  static Future<AppDatabase> open({DatabaseFactory? factory, String? path}) async {
    final dbFactory = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await dbFactory.getDatabasesPath(), fileName);
    final db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: version,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE $cacheTable (
              key TEXT PRIMARY KEY,
              json TEXT NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
        },
      ),
    );
    return AppDatabase._(db);
  }

  Future<void> close() => db.close();
}
