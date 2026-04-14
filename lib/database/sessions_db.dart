import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';
import '../model/session_model.dart' as model;
import 'package:logger/logger.dart';

class SessionDB {
  static final Logger _logger = Logger();

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firebase_id TEXT,
        case_id INTEGER,
        firebase_case_id TEXT,
        date TEXT,
        time TEXT,
        location TEXT,
        notes TEXT,
        isSynced INTEGER DEFAULT 0
      )
    ''');

    // ✅ فهارس تساعد في الأداء والفلترة
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sessions_case_id ON sessions(case_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sessions_firebase_case_id ON sessions(firebase_case_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sessions_firebase_id ON sessions(firebase_id)');

    // ✅ Prevent duplicates: if firebase_id is set, it must be unique.
    // If old data already contains duplicates, we cleanup first then create the unique index.
    try {
      await db.execute('''
        DELETE FROM sessions
        WHERE firebase_id IS NOT NULL
          AND TRIM(firebase_id) <> ''
          AND id NOT IN (
            SELECT MIN(id) FROM sessions
            WHERE firebase_id IS NOT NULL AND TRIM(firebase_id) <> ''
            GROUP BY firebase_id
          );
      ''');
    } catch (_) {
      // ignore cleanup errors
    }

    try {
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS uq_sessions_firebase_id ON sessions(firebase_id)');
    } catch (_) {
      // ignore if SQLite can't create unique index (e.g., duplicates still exist)
    }

    // ✅ Migration آمن: لو قاعدة قديمة موجودة بدون العمود
    try {
      await db.execute('ALTER TABLE sessions ADD COLUMN firebase_case_id TEXT');
    } catch (_) {
      // العمود موجود بالفعل
    }
  }

  static Future<int> insertSession(model.SessionModel session) async {
    try {
      final db = await DBHelper.database;

      // ✅ يسمح بالحفظ المحلي إذا لدينا على الأقل:
      // caseId محلي صالح أو firebaseCaseId صالح
      final hasLocalCase = session.caseId != 0;
      final hasFirebaseCase =
          (session.firebaseCaseId != null && session.firebaseCaseId!.trim().isNotEmpty);

      if (!hasLocalCase && !hasFirebaseCase) {
        _logger.w('⚠️ رفض إدخال جلسة محليًا: لا caseId ولا firebaseCaseId');
        return -1;
      }

      return await db.insert(
        'sessions',
        session.toMapLocal(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, stackTrace) {
      _logger.e('خطأ أثناء إدخال الجلسة', error: e, stackTrace: stackTrace);
      return -1;
    }
  }

  static Future<List<model.SessionModel>> getSessions() async {
    final db = await DBHelper.database;
    final result = await db.query('sessions', orderBy: 'date ASC, time ASC');
    return result.map((map) => model.SessionModel.fromMapLocal(map)).toList();
  }

  /// ✅ تنظيف آمن فقط:
  /// يحذف الجلسات التي ليس لها case_id ولا firebase_case_id
  static Future<int> purgeOrphanSessionsSafe() async {
    final db = await DBHelper.database;
    final deleted = await db.delete(
      'sessions',
      where: '(case_id IS NULL OR case_id = 0) AND (firebase_case_id IS NULL OR TRIM(firebase_case_id) = "")',
    );

    if (deleted > 0) {
      _logger.w('🧹 تم حذف $deleted جلسات يتيمة (بدون case_id وبدون firebase_case_id)');
    }
    return deleted;
  }

  /// ✅ الجلب الصحيح: حسب القضية المحلية أو حسب معرف القضية السحابي
  static Future<List<model.SessionModel>> getSessionsByCaseId(
    int caseId, {
    String? firebaseCaseId,
  }) async {
    final db = await DBHelper.database;

    // تنظيف آمن للبقايا القديمة
    await purgeOrphanSessionsSafe();

    final hasFirebase = firebaseCaseId != null && firebaseCaseId.trim().isNotEmpty;

    // إذا ما في لا محلي ولا سحابي → رجّع فاضي
    if (caseId == 0 && !hasFirebase) return [];

    final result = await db.query(
      'sessions',
      where: hasFirebase
          ? '(case_id = ?) OR (firebase_case_id = ?)'
          : 'case_id = ?',
      whereArgs: hasFirebase ? [caseId, firebaseCaseId!.trim()] : [caseId],
      orderBy: 'date ASC, time ASC',
    );

    return result.map((map) => model.SessionModel.fromMapLocal(map)).toList();
  }

  static Future<int> updateSession(model.SessionModel session) async {
    final db = await DBHelper.database;

    if (session.localId == null) {
      _logger.w('⚠️ updateSession بدون localId — تم تجاهل التحديث');
      return 0;
    }

    // ✅ لا تمنع update إذا caseId=0 طالما firebaseCaseId موجود
    final hasLocalCase = session.caseId != 0;
    final hasFirebaseCase =
        (session.firebaseCaseId != null && session.firebaseCaseId!.trim().isNotEmpty);

    if (!hasLocalCase && !hasFirebaseCase) {
      _logger.w('⚠️ رفض تحديث جلسة: لا caseId ولا firebaseCaseId');
      return 0;
    }

    return await db.update(
      'sessions',
      session.toMapLocal(),
      where: 'id = ?',
      whereArgs: [session.localId],
    );
  }

  static Future<int> deleteSession(int id) async {
    final db = await DBHelper.database;
    return await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<model.SessionModel>> getUnsyncedSessions() async {
    final db = await DBHelper.database;

    // ✅ لا تزامن جلسات يتيمة بالكامل
    final result = await db.query(
      'sessions',
      where:
          'isSynced = 0 AND ((case_id IS NOT NULL AND case_id != 0) OR (firebase_case_id IS NOT NULL AND TRIM(firebase_case_id) != ""))',
      orderBy: 'date ASC, time ASC',
    );

    return result.map((map) => model.SessionModel.fromMapLocal(map)).toList();
  }

  static Future<void> markSessionAsSynced(int localId) async {
    final db = await DBHelper.database;
    await db.update(
      'sessions',
      {'isSynced': 1},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  /// Update local session row with the cloud UUID stored in `firebase_id`.
  static Future<void> updateSessionFirebaseId({
    required int localId,
    required String firebaseId,
  }) async {
    final db = await DBHelper.database;
    await db.update(
      'sessions',
      {'firebase_id': firebaseId},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  /// Fetch a single session by its local integer id.
  static Future<model.SessionModel?> getSessionByLocalId(int localId) async {
    final db = await DBHelper.database;
    final rows = await db.query(
      'sessions',
      where: 'id = ?',
      whereArgs: [localId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return model.SessionModel.fromMapLocal(rows.first);
  }

  static Future<void> importSessionIfNotExists(model.SessionModel session) async {
    final db = await DBHelper.database;

    if (session.firebaseId == null || session.firebaseId!.trim().isEmpty) {
      _logger.w('⚠️ importSessionIfNotExists: firebaseId فارغ — تم تجاهل الاستيراد');
      return;
    }

    // ✅ نسمح بالاستيراد إذا عندنا caseId محلي أو firebaseCaseId
    final hasLocalCase = session.caseId != 0;
    final hasFirebaseCase =
        (session.firebaseCaseId != null && session.firebaseCaseId!.trim().isNotEmpty);

    if (!hasLocalCase && !hasFirebaseCase) {
      _logger.w('⚠️ importSessionIfNotExists: لا caseId ولا firebaseCaseId — تم تجاهل الاستيراد');
      return;
    }

    final result = await db.query(
      'sessions',
      where: 'firebase_id = ?',
      whereArgs: [session.firebaseId!.trim()],
    );

    if (result.isEmpty) {
      // 🛠️ Prevent duplicate local rows:
      // If the same session was created locally (firebase_id = NULL) then later
      // came from the cloud with a firebaseId, we should UPDATE the local row
      // instead of inserting a new one.
      try {
        final possibleDup = await db.query(
          'sessions',
          where: '(firebase_id IS NULL OR firebase_id = \'\') AND date = ? AND time = ? AND (case_id = ? OR firebase_case_id = ?)',
          whereArgs: [
            session.date,
            session.time,
            session.caseId,
            session.firebaseCaseId ?? '',
          ],
          limit: 1,
        );

        if (possibleDup.isNotEmpty) {
          final localId = possibleDup.first['id'] as int;
          final updated = Map<String, dynamic>.from(session.toMapLocal());
          updated['id'] = localId; // keep the local primary key
          updated['isSynced'] = 1;
          await db.update(
            'sessions',
            updated,
            where: 'id = ?',
            whereArgs: [localId],
          );
          _logger.i('🔁 تم ربط الجلسة المحلية بالنسخة السحابية (firebaseId=${session.firebaseId})');
          return;
        }
      } catch (e) {
        // Some logger versions only accept a single positional argument.
        _logger.w('⚠️ duplicate-check update failed (sessions): $e');
      }

      await db.insert(
        'sessions',
        session.toMapLocal(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _logger.i('⬇️ تم استيراد جلسة من السحابة إلى SQLite (firebaseId=${session.firebaseId})');
    }
  }
}
