import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/restaurant.dart';

/// Local SQLite store for ratings. Fast, offline, no backend required.
class RestaurantDatabase {
  RestaurantDatabase._();
  static final RestaurantDatabase instance = RestaurantDatabase._();

  static const _dbName = 'restaurants.db';
  static const _table = 'restaurants';
  static const _version = 1;

  Database? _db;

  Future<Database> get _database async {
    return _db ??= await _open();
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, _dbName);
    return openDatabase(
      path,
      version: _version,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            address TEXT,
            placeId TEXT,
            lat REAL,
            lng REAL,
            photoUrl TEXT,
            customPhotoPath TEXT,
            foodRating INTEGER,
            atmosphereRating INTEGER,
            price INTEGER,
            categoryKeys TEXT,
            mediaPaths TEXT,
            notes TEXT,
            createdAt INTEGER,
            updatedAt INTEGER,
            ownerId TEXT,
            visibility TEXT,
            groupIds TEXT
          )
        ''');
      },
    );
  }

  Future<List<Restaurant>> getAll() async {
    final db = await _database;
    final rows = await db.query(_table, orderBy: 'createdAt DESC');
    return rows.map(Restaurant.fromMap).toList();
  }

  Future<void> upsert(Restaurant r) async {
    final db = await _database;
    await db.insert(
      _table,
      r.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id) async {
    final db = await _database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}
