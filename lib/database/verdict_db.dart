import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';
import '../model/verdict_model.dart';
import 'package:logger/logger.dart';

class VerdictDB {
  static final Logger _logger = Logger();

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS verdicts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firebase_id TEXT,
        session_id INTEGER,
        firebase_session_id TEXT,
        pdf_path TEXT,
        description TEXT,
        created_at TEXT,
        isSynced INTEGER DEFAULT 0,
        FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
      )
    ''');

    // ✅ Hard guard: when firebase_id is set, it must be unique (prevents double imports/sync).
    try {
      await db.execute('''
        DELETE FROM verdicts
        WHERE id NOT IN (
          SELECT MIN(id)
          FROM verdicts
          WHERE firebase_id IS NOT NULL AND TRIM(firebase_id) <> ''
          GROUP BY firebase_id
        )
        AND firebase_id IS NOT NULL AND TRIM(firebase_id) <> ''
      ''');

      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS uq_verdicts_firebase_id ON verdicts(firebase_id)');
    } catch (e) {
      // If this fails on an existing DB, we still prefer the app to run.
      _logger.w('Could not enforce unique firebase_id for verdicts: $e');
    }
  }

  static Future<int> insertVerdict(VerdictModel verdict) async {
    try {
      final db = await DBHelper.database;
      return await db.insert('verdicts', verdict.toMapLocal());
    } catch (e, stackTrace) {
      _logger.e('خطأ أثناء إدخال منطوق الحكم', error: e, stackTrace: stackTrace);
      return -1;
    }
  }

  static Future<List<VerdictModel>> getVerdictsBySessionId(int sessionId) async {
    final db = await DBHelper.database;
    final result = await db.query(
      'verdicts',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    return result.map((map) => VerdictModel.fromMapLocal(map)).toList();
  }

  /// ✅ جلب المنطوقات اعتماداً على firebase_session_id
  /// تستخدمها شاشة المنطوق عندما يكون التنقل مبنيًا على معرف السحابة.
  static Future<List<VerdictModel>> getVerdictsByFirebaseSessionId(String firebaseSessionId) async {
    final db = await DBHelper.database;
    final rows = await db.query(
      'verdicts',
      where: 'firebase_session_id = ?',
      whereArgs: [firebaseSessionId],
      orderBy: 'created_at DESC',
    );
    return rows.map((e) => VerdictModel.fromMapLocal(e)).toList();
  }

  static Future<void> deleteVerdictById(int id) async {
    final db = await DBHelper.database;
    await db.delete('verdicts', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> updateDescription(int id, String newDescription) async {
    final db = await DBHelper.database;
    await db.update(
      'verdicts',
      {'description': newDescription},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// ✅ تحديث المنطوق بعد رفعه إلى السحابة وربطه بـ firebaseId
  static Future<void> updateVerdictWithFirebaseId(int localId, VerdictModel verdict) async {
    final db = await DBHelper.database;
    await db.update(
      'verdicts',
      {
        'firebase_id': verdict.firebaseId,
        'isSynced': 1,
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  static Future<List<VerdictModel>> getUnsyncedVerdicts() async {
    final db = await DBHelper.database;
    final result = await db.query('verdicts', where: 'isSynced = 0');
    return result.map((map) => VerdictModel.fromMapLocal(map)).toList();
  }

  static Future<void> markVerdictAsSynced(int localId) async {
    final db = await DBHelper.database;
    await db.update(
      'verdicts',
      {'isSynced': 1},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  static Future<void> importVerdictIfNotExists(VerdictModel verdict) async {
    final db = await DBHelper.database;
    final result = await db.query(
      'verdicts',
      where: 'firebase_id = ?',
      whereArgs: [verdict.firebaseId],
    );

    if (result.isEmpty) {
      await db.insert('verdicts', verdict.toMapLocal());
    }
  }
}
