import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService extends GetxService {
  late Database db;

  Future<DatabaseService> init() async {
    db = await openDatabase(
      'app.db',
      version: 1,
      onCreate: (db, version) async {
        await _createTables(db);
      },
    );
    return this;
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE regions (
        id INTEGER PRIMARY KEY,
        name TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE districts (
        id INTEGER PRIMARY KEY,
        name TEXT,
        region_id INTEGER,
        FOREIGN KEY (region_id) REFERENCES regions(id)
      );
    ''');
  }
}
