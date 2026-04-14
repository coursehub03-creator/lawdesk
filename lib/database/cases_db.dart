import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';
import '../model/case_model.dart' as model;
import 'package:logger/logger.dart';

/// ✅ CaseDB: تخزين محلي (SQLite) مع دعم Offline-first.
/// - firebase_id: UUID موحّد (نولّده محلياً ثم نرفعه للسحابة بنفسه)
/// - firebase_client_id: UUID العميل السحابي لربط القضية بالعميل (Supabase clients.id)
/// - clientId: معرف العميل المحلي (للتوافق مع الشاشات القديمة)
class CaseDB {
  static final Logger _logger = Logger();

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firebase_id TEXT,
        firebase_client_id TEXT,
        title TEXT,
        fileNumber TEXT,
        status TEXT,
        caseType TEXT,
        court TEXT,
        startDate TEXT,
        notes TEXT,
        clientId INTEGER,
        isSynced INTEGER DEFAULT 0
      )
    ''');
  }

  // ---------------------------------------------------------------------------
  // CRUD
  // ---------------------------------------------------------------------------

  static Future<int> insertCase(model.CaseModel c) async {
    try {
      final db = await DBHelper.database;
      return await db.insert('cases', c.toMapLocal());
    } catch (e, stackTrace) {
      _logger.e('Error inserting case', error: e, stackTrace: stackTrace);
      return -1;
    }
  }

  static Future<int> updateCase(model.CaseModel c) async {
    final db = await DBHelper.database;
    return await db.update(
      'cases',
      c.toMapLocal(),
      where: 'id = ?',
      whereArgs: [c.localId],
    );
  }

  static Future<int> deleteCase(int localId) async {
    final db = await DBHelper.database;
    return await db.delete('cases', where: 'id = ?', whereArgs: [localId]);
  }

  // ---------------------------------------------------------------------------
  // Queries (Backward-compatible + New)
  // ---------------------------------------------------------------------------

  /// ✅ جلب كل القضايا (Legacy support for SyncService)
  static Future<List<model.CaseModel>> getCases() async {
    final db = await DBHelper.database;
    final result = await db.query('cases', orderBy: 'id DESC');
    return result.map((map) => model.CaseModel.fromMapLocal(map)).toList();
  }

  /// ✅ Legacy: فلترة بحسب clientId المحلي
  /// ملاحظة: هذا يبقى للتوافق مع شاشات قديمة.
  static Future<List<model.CaseModel>> getCasesByClientId(int clientId) async {
    final db = await DBHelper.database;
    final result = await db.query(
      'cases',
      where: 'clientId = ?',
      whereArgs: [clientId],
      orderBy: 'id DESC',
    );
    return result.map((map) => model.CaseModel.fromMapLocal(map)).toList();
  }

  /// ✅ الطريقة الأصح: فلترة بحسب firebase_client_id (UUID العميل السحابي)
  static Future<List<model.CaseModel>> getCasesByFirebaseClientId(String firebaseClientId) async {
    final db = await DBHelper.database;
    final result = await db.query(
      'cases',
      where: 'firebase_client_id = ?',
      whereArgs: [firebaseClientId],
      orderBy: 'id DESC',
    );
    return result.map((map) => model.CaseModel.fromMapLocal(map)).toList();
  }

  /// ✅ استيراد القضية من Supabase إذا لم تكن موجودة محلياً (Legacy support)
  static Future<void> importCaseIfNotExists(model.CaseModel c) async {
    final db = await DBHelper.database;
    final result = await db.query(
      'cases',
      where: 'firebase_id = ?',
      whereArgs: [c.firebaseId],
      limit: 1,
    );

    if (result.isEmpty) {
      await db.insert('cases', c.toMapLocal());
    }
  }

  // ---------------------------------------------------------------------------
  // Sync helpers
  // ---------------------------------------------------------------------------

  static Future<List<model.CaseModel>> getUnsyncedCases() async {
    final db = await DBHelper.database;
    final result = await db.query(
      'cases',
      where: 'isSynced = ?',
      whereArgs: [0],
      orderBy: 'id DESC',
    );
    return result.map((map) => model.CaseModel.fromMapLocal(map)).toList();
  }

  static Future<void> markCaseAsSynced(int localId) async {
    final db = await DBHelper.database;
    await db.update(
      'cases',
      {'isSynced': 1},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }
}
