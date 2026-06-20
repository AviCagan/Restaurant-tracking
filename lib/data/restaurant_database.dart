import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/restaurant.dart';

/// Local SQLite store for restaurants + their visits.
class RestaurantDatabase {
  RestaurantDatabase._();
  static final RestaurantDatabase instance = RestaurantDatabase._();

  static const _dbName = 'restaurants.db';
  static const _table = 'restaurants';
  static const _version = 2;

  Database? _db;

  Future<Database> get _database async => _db ??= await _open();

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
            categoryKeys TEXT,
            visits TEXT,
            createdAt INTEGER,
            updatedAt INTEGER,
            ownerId TEXT,
            visibility TEXT,
            groupIds TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _migrateToVisits(db);
        }
      },
    );
  }

  /// v1 stored one rating per row (foodRating/atmosphereRating/price/notes/
  /// mediaPaths). v2 folds that into a single first visit under `visits`.
  Future<void> _migrateToVisits(Database db) async {
    await db.execute('ALTER TABLE $_table ADD COLUMN visits TEXT');
    final rows = await db.query(_table);
    const uuid = Uuid();
    for (final row in rows) {
      List<String> media = const [];
      final raw = row['mediaPaths'];
      if (raw is String && raw.isNotEmpty) {
        media = (jsonDecode(raw) as List).map((e) => e.toString()).toList();
      }
      final visit = {
        'id': uuid.v4(),
        'date': row['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
        'foodRating': row['foodRating'] ?? 5,
        'atmosphereRating': row['atmosphereRating'] ?? 5,
        'price': row['price'] ?? 0,
        'notes': row['notes'] ?? '',
        'items': <dynamic>[],
        'photoPaths': media,
      };
      await db.update(
        _table,
        {'visits': jsonEncode([visit])},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  Future<List<Restaurant>> getAll() async {
    final db = await _database;
    final rows = await db.query(_table, orderBy: 'createdAt DESC');
    return rows.map(Restaurant.fromMap).toList();
  }

  Future<Restaurant?> getById(String id) async {
    final db = await _database;
    final rows = await db.query(_table, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Restaurant.fromMap(rows.first);
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
