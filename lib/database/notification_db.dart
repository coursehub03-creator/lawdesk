import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';

import 'db_helper.dart';
import '../model/notification_model.dart';

class NotificationDB {
  static final Logger _logger = Logger();

  static const String _table = 'notifications';

  /// Called from DBHelper.onCreate
  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firebase_id TEXT,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        session_id INTEGER,
        firebase_session_id TEXT,
        case_id INTEGER,
        firebase_case_id TEXT,
        is_read INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_notifications_timestamp ON $_table(timestamp)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_notifications_firebase_case_id ON $_table(firebase_case_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_notifications_firebase_session_id ON $_table(firebase_session_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_notifications_firebase_id ON $_table(firebase_id)',
    );
  }

  /// Ensures older DBs are upgraded (adds missing columns safely).
  static Future<void> _ensureSchema() async {
    final db = await DBHelper.database;

    // Make sure table exists.
    await createTable(db);

    try {
      final cols = await db.rawQuery('PRAGMA table_info($_table)');
      final existing = cols.map((c) => (c['name'] as String)).toSet();

      Future<void> addCol(String name, String typeAndDefault) async {
        if (!existing.contains(name)) {
          await db.execute('ALTER TABLE $_table ADD COLUMN $name $typeAndDefault');
        }
      }

      await addCol('firebase_id', 'TEXT');
      await addCol('session_id', 'INTEGER');
      await addCol('firebase_session_id', 'TEXT');
      await addCol('case_id', 'INTEGER');
      await addCol('firebase_case_id', 'TEXT');
      await addCol('is_read', 'INTEGER DEFAULT 0');
      await addCol('is_synced', 'INTEGER DEFAULT 0');

      // Indexes (idempotent)
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_notifications_timestamp ON $_table(timestamp)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_notifications_firebase_case_id ON $_table(firebase_case_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_notifications_firebase_session_id ON $_table(firebase_session_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_notifications_firebase_id ON $_table(firebase_id)',
      );
    } catch (e) {
      _logger.w('NotificationDB schema check failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // CRUD
  // ---------------------------------------------------------------------------

  static Future<int> insertNotification(AppNotification notification) async {
    await _ensureSchema();
    final db = await DBHelper.database;

    final map = notification.toMapLocal();

    // Offline-first: if firebase_id exists, upsert into local DB by firebase_id.
    final fid = (notification.firebaseId ?? '').trim();
    if (fid.isNotEmpty) {
      final existing = await db.query(
        _table,
        columns: ['id'],
        where: 'firebase_id = ?',
        whereArgs: [fid],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        final localId = existing.first['id'] as int;
        await db.update(
          _table,
          map..remove('id'),
          where: 'id = ?',
          whereArgs: [localId],
        );
        return localId;
      }
    }

    // Insert new
    return await db.insert(_table, map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<AppNotification>> getAllNotifications({bool unreadOnly = false}) async {
    await _ensureSchema();
    final db = await DBHelper.database;

    final maps = await db.query(
      _table,
      where: unreadOnly ? 'is_read = ?' : null,
      whereArgs: unreadOnly ? [0] : null,
      orderBy: 'timestamp DESC',
    );

    return maps.map((e) => AppNotification.fromMapLocal(e)).toList();
  }

  static Future<int> getUnreadCount() async {
    await _ensureSchema();
    final db = await DBHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM $_table WHERE is_read = 0');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  static Future<void> markAsRead(int id) async {
    await _ensureSchema();
    final db = await DBHelper.database;
    await db.update(_table, {'is_read': 1}, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> markAllAsRead() async {
    await _ensureSchema();
    final db = await DBHelper.database;
    await db.update(_table, {'is_read': 1});
  }

  static Future<void> deleteNotification(int id) async {
    await _ensureSchema();
    final db = await DBHelper.database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteByFirebaseId(String firebaseId) async {
    await _ensureSchema();
    final db = await DBHelper.database;
    await db.delete(_table, where: 'firebase_id = ?', whereArgs: [firebaseId]);
  }

  static Future<void> clearAllNotifications() async {
    await _ensureSchema();
    final db = await DBHelper.database;
    await db.delete(_table);
  }

  // ---------------------------------------------------------------------------
  // Sync helpers (optional)
  // ---------------------------------------------------------------------------

  static Future<List<AppNotification>> getUnsyncedNotifications() async {
    await _ensureSchema();
    final db = await DBHelper.database;
    final result = await db.query(_table, where: 'is_synced = ?', whereArgs: [0]);
    return result.map((e) => AppNotification.fromMapLocal(e)).toList();
  }

  static Future<void> markNotificationAsSynced(int id) async {
    await _ensureSchema();
    final db = await DBHelper.database;
    await db.update(_table, {'is_synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> markNotificationAsSyncedByFirebaseId(String firebaseId) async {
    await _ensureSchema();
    final db = await DBHelper.database;
    await db.update(_table, {'is_synced': 1}, where: 'firebase_id = ?', whereArgs: [firebaseId]);
  }

  static Future<void> importNotificationIfNotExists(AppNotification notif) async {
    await _ensureSchema();
    final db = await DBHelper.database;

    final fid = (notif.firebaseId ?? '').trim();
    if (fid.isNotEmpty) {
      final existing = await db.query(_table, where: 'firebase_id = ?', whereArgs: [fid], limit: 1);
      if (existing.isEmpty) {
        await db.insert(_table, notif.toMapLocal(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      return;
    }

    // Fallback for older notifications without firebase_id
    final result = await db.query(
      _table,
      where: 'title = ? AND body = ? AND timestamp = ?',
      whereArgs: [notif.title, notif.body, notif.timestamp.toIso8601String()],
      limit: 1,
    );
    if (result.isEmpty) {
      await db.insert(_table, notif.toMapLocal(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }
}
