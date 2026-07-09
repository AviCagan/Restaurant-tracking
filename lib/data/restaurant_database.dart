import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/restaurant.dart';

/// Local store for restaurants + their visits. SQLite on Android/iOS; on
/// the web (no SQLite in browsers) the same data lives as one JSON blob in
/// browser storage — personal lists are small, so this is plenty.
class RestaurantDatabase {
  RestaurantDatabase._();
  static final RestaurantDatabase instance = RestaurantDatabase._();

  static const _dbName = 'restaurants.db';
  static const _table = 'restaurants';
  static const _version = 5;

  Database? _db;

  Future<Database> get _database async => _db ??= await _open();

  // ---- Web storage (browser) ----
  static const _webKey = 'restaurants_web_v1';
  List<Restaurant>? _webCache;

  Future<List<Restaurant>> _webAll() async {
    if (_webCache != null) return _webCache!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_webKey);
    _webCache = raw == null || raw.isEmpty
        ? <Restaurant>[]
        : [
            for (final m in jsonDecode(raw) as List)
              Restaurant.fromMap((m as Map).cast<String, dynamic>())
          ];
    return _webCache!;
  }

  Future<void> _webSave() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_webKey,
        jsonEncode([for (final r in _webCache ?? <Restaurant>[]) r.toMap()]));
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
            categoryKeys TEXT,
            visits TEXT,
            isFavorite INTEGER,
            wantToGo INTEGER,
            isChain INTEGER,
            chainName TEXT,
            locationLabel TEXT,
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
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE $_table ADD COLUMN isChain INTEGER');
          await db.execute('ALTER TABLE $_table ADD COLUMN chainName TEXT');
          await db
              .execute('ALTER TABLE $_table ADD COLUMN locationLabel TEXT');
        }
        if (oldVersion < 4) {
          await db
              .execute('ALTER TABLE $_table ADD COLUMN isFavorite INTEGER');
        }
        if (oldVersion < 5) {
          await db.execute('ALTER TABLE $_table ADD COLUMN wantToGo INTEGER');
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
    if (kIsWeb) {
      final all = await _webAll();
      return [...all]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    final db = await _database;
    final rows = await db.query(_table, orderBy: 'createdAt DESC');
    return rows.map(Restaurant.fromMap).toList();
  }

  Future<Restaurant?> getById(String id) async {
    if (kIsWeb) {
      final all = await _webAll();
      for (final r in all) {
        if (r.id == id) return r;
      }
      return null;
    }
    final db = await _database;
    final rows = await db.query(_table, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Restaurant.fromMap(rows.first);
  }

  /// Set by the cloud layer to mirror local changes to Firestore.
  static void Function(Restaurant r)? onUpsert;
  static void Function(String id)? onDelete;

  Future<void> upsert(Restaurant r) async {
    if (kIsWeb) {
      final all = await _webAll();
      final i = all.indexWhere((x) => x.id == r.id);
      i >= 0 ? all[i] = r : all.add(r);
      await _webSave();
      onUpsert?.call(r);
      return;
    }
    final db = await _database;
    await db.insert(
      _table,
      r.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    onUpsert?.call(r);
  }

  Future<void> delete(String id) async {
    if (kIsWeb) {
      final all = await _webAll();
      all.removeWhere((r) => r.id == id);
      await _webSave();
      onDelete?.call(id);
      return;
    }
    final db = await _database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
    onDelete?.call(id);
  }
}
