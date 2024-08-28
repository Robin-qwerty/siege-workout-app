import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    return await openDatabase(
      join(dbPath, 'exercise.db'),
      version: 2, // Increment version if schema changes
      onCreate: (db, version) {
        return db.execute(
          "CREATE TABLE exercises(id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT, event TEXT, level1 INTEGER, level2 INTEGER)",
        );
      },
      onUpgrade: (db, oldVersion, newVersion) {
        if (oldVersion < 2) {
          db.execute("ALTER TABLE exercises ADD COLUMN level1 INTEGER");
          db.execute("ALTER TABLE exercises ADD COLUMN level2 INTEGER");
        }
      },
    );
  }

  Future<void> insertOrUpdateExercise(
      String date, String event, int level1, int level2) async {
    final db = await database;
    await db.insert(
      'exercises',
      {'date': date, 'event': event, 'level1': level1, 'level2': level2},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>> getExerciseByEventAndDate(
      String date, String event) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'exercises',
      where: 'date = ? AND event = ?',
      whereArgs: [date, event],
    );
    return result.isNotEmpty ? result.first : {'level1': 0, 'level2': 0};
  }
}
