import 'package:sqflite/sqflite.dart';

import '../model/witness_model.dart';
import 'db_helper.dart';

class WitnessDB {
  static const String tableName = 'witnesses';

  /// Schema: snake_case + isSynced (legacy)
  ///
  /// - id                INTEGER PK AUTOINCREMENT
  /// - firebase_id        TEXT UNIQUE NOT NULL   (cloud uuid)
  /// - case_id            INTEGER NOT NULL       (local case id)
  /// - firebase_case_id   TEXT NOT NULL          (cloud case uuid)
  /// - name               TEXT NOT NULL
  /// - role               TEXT NOT NULL          (avoid Supabase NOT NULL failure)
  /// - notes/phone/address/relationship  TEXT NULL
  /// - isSynced           INTEGER NOT NULL DEFAULT 0
  static Future<void> createWitnessTable(Database db) async => createTable(db);

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firebase_id TEXT NOT NULL UNIQUE,
        case_id INTEGER NOT NULL,
        firebase_case_id TEXT NOT NULL,
        name TEXT NOT NULL,
        role TEXT NOT NULL,
        notes TEXT,
        phone TEXT,
        address TEXT,
        relationship TEXT,
        isSynced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  /// Migration helper: safely add missing columns without dropping data.
  static Future<void> migrate(Database db) async {
    // Ensure table exists.
    await createTable(db);

    // Try to add missing columns for older installs.
    // Note: SQLite doesn't support IF NOT EXISTS for ADD COLUMN in older versions,
    // so we use try/catch.
    Future<void> _tryAdd(String sql) async {
      try {
        await db.execute(sql);
      } catch (_) {
        // ignore (already exists)
      }
    }

    await _tryAdd('ALTER TABLE $tableName ADD COLUMN firebase_id TEXT');
    await _tryAdd('ALTER TABLE $tableName ADD COLUMN case_id INTEGER');
    await _tryAdd('ALTER TABLE $tableName ADD COLUMN firebase_case_id TEXT');
    await _tryAdd('ALTER TABLE $tableName ADD COLUMN name TEXT');
    await _tryAdd('ALTER TABLE $tableName ADD COLUMN role TEXT');
    await _tryAdd('ALTER TABLE $tableName ADD COLUMN notes TEXT');
    await _tryAdd('ALTER TABLE $tableName ADD COLUMN phone TEXT');
    await _tryAdd('ALTER TABLE $tableName ADD COLUMN address TEXT');
    await _tryAdd('ALTER TABLE $tableName ADD COLUMN relationship TEXT');
    await _tryAdd('ALTER TABLE $tableName ADD COLUMN isSynced INTEGER');

    // If the old schema used camelCase `caseId`, copy data into case_id.
    try {
      final cols = await db.rawQuery('PRAGMA table_info($tableName)');
      final hasCaseIdCamel = cols.any((c) => (c['name'] as String) == 'caseId');
      if (hasCaseIdCamel) {
        await db.execute(
          'UPDATE $tableName SET case_id = COALESCE(case_id, caseId) WHERE case_id IS NULL',
        );
      }
    } catch (_) {
      // ignore
    }

    // Ensure role isn't null (both local + cloud often require it).
    try {
      await db.execute(
        "UPDATE $tableName SET role = 'witness' WHERE role IS NULL OR TRIM(role) = ''",
      );
    } catch (_) {
      // ignore
    }
  }

  /// Backward-compatible name used by DBHelper during upgrades.
  static Future<void> migrateTable(Database db) async => migrate(db);

  static Future<int> insertWitness(WitnessModel witness) async {
    final db = await DBHelper.database;
    final map = witness.toMapLocal();
    // Never send local PK.
    map.remove('id');
    return db.insert(
      tableName,
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<int> updateWitness(WitnessModel witness) async {
    final db = await DBHelper.database;
    return db.update(
      tableName,
      witness.toMapLocal(),
      where: 'id = ?',
      whereArgs: [witness.localId],
    );
  }

  static Future<List<WitnessModel>> getWitnessesByFirebaseCaseId(
    String firebaseCaseId,
  ) async {
    final db = await DBHelper.database;
    final rows = await db.query(
      tableName,
      where: 'firebase_case_id = ?',
      whereArgs: [firebaseCaseId],
      orderBy: 'id DESC',
    );
    return rows.map(WitnessModel.fromMapLocal).toList();
  }

  static Future<List<WitnessModel>> getUnsyncedWitnesses() async {
    final db = await DBHelper.database;
    final rows = await db.query(
      tableName,
      where: 'isSynced = 0',
      orderBy: 'id ASC',
    );
    return rows.map(WitnessModel.fromMapLocal).toList();
  }

  static Future<void> markWitnessAsSynced(int localId) async {
    final db = await DBHelper.database;
    await db.update(
      tableName,
      {'isSynced': 1},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  static Future<void> deleteByLocalId(int localId) async {
    final db = await DBHelper.database;
    await db.delete(tableName, where: 'id = ?', whereArgs: [localId]);
  }

  /// Import a remote witness (already synced) if it doesn't exist locally.
  static Future<void> importWitnessIfNotExists(WitnessModel remote) async {
    final db = await DBHelper.database;
    final existing = await db.query(
      tableName,
      where: 'firebase_id = ?',
      whereArgs: [remote.firebaseId],
      limit: 1,
    );
    if (existing.isNotEmpty) return;

    final map = remote.toMapLocal();
    map.remove('id');
    map['isSynced'] = 1;
    await db.insert(tableName, map);
  }
}
