import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';

import 'db_helper.dart';
import '../model/evidence_model.dart';

class EvidenceDB {
  static final Logger _logger = Logger();

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS evidence (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firebase_id TEXT,
        firebase_case_id TEXT,
        caseId INTEGER NOT NULL,
        type TEXT NOT NULL,
        filePath TEXT NOT NULL,
        uploadedAt TEXT NOT NULL,
        description TEXT,
        isSynced INTEGER DEFAULT 0
      )
    ''');
    // indexes (best-effort)
    try {
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_evidence_firebase_id ON evidence(firebase_id);');
    } catch (_) {}
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_evidence_firebase_case_id ON evidence(firebase_case_id);');
    } catch (_) {}
  }

  static Future<int> insertEvidence(EvidenceModel e) async {
    try {
      final db = await DBHelper.database;
      return await db.insert('evidence', e.toMapLocal());
    } catch (e, st) {
      _logger.e('Error inserting evidence', error: e, stackTrace: st);
      return -1;
    }
  }

  static Future<int> updateEvidence(EvidenceModel e) async {
    final db = await DBHelper.database;
    return await db.update(
      'evidence',
      e.toMapLocal(),
      where: 'id = ?',
      whereArgs: [e.localId],
    );
  }

  static Future<int> deleteEvidence(int localId) async {
    final db = await DBHelper.database;
    return await db.delete('evidence', where: 'id = ?', whereArgs: [localId]);
  }

  static Future<int> deleteEvidenceByFirebaseId(String firebaseId) async {
    final db = await DBHelper.database;
    return await db.delete('evidence', where: 'firebase_id = ?', whereArgs: [firebaseId]);
  }

  static Future<List<EvidenceModel>> getEvidenceByFirebaseCaseId(String firebaseCaseId) async {
    final db = await DBHelper.database;
    final result = await db.query(
      'evidence',
      where: 'firebase_case_id = ?',
      whereArgs: [firebaseCaseId],
      orderBy: 'uploadedAt DESC',
    );
    return result.map(EvidenceModel.fromMapLocal).toList();
  }

  /// Backward-compatible: if [firebaseCaseId] provided use it, else use local [caseId].
  static Future<List<EvidenceModel>> getEvidenceByCaseId(int caseId, {String? firebaseCaseId}) async {
    if (firebaseCaseId != null && firebaseCaseId.trim().isNotEmpty) {
      return getEvidenceByFirebaseCaseId(firebaseCaseId.trim());
    }
    final db = await DBHelper.database;
    final result = await db.query(
      'evidence',
      where: 'caseId = ?',
      whereArgs: [caseId],
      orderBy: 'uploadedAt DESC',
    );
    return result.map(EvidenceModel.fromMapLocal).toList();
  }

  static Future<List<EvidenceModel>> getUnsyncedEvidence() async {
    final db = await DBHelper.database;
    final result = await db.query('evidence', where: 'isSynced = 0');
    return result.map(EvidenceModel.fromMapLocal).toList();
  }

  static Future<void> markEvidenceAsSynced(int localId) async {
    final db = await DBHelper.database;
    await db.update('evidence', {'isSynced': 1}, where: 'id = ?', whereArgs: [localId]);
  }

  static Future<void> markEvidenceAsSyncedByFirebaseId(String firebaseId) async {
    final db = await DBHelper.database;
    await db.update('evidence', {'isSynced': 1}, where: 'firebase_id = ?', whereArgs: [firebaseId]);
  }

  /// Import evidence from Supabase if it doesn't exist locally.
  static Future<void> importEvidenceIfNotExists(EvidenceModel e) async {
    if (e.firebaseId == null || e.firebaseId!.trim().isEmpty) return;
    final db = await DBHelper.database;
    final result = await db.query('evidence', where: 'firebase_id = ?', whereArgs: [e.firebaseId]);
    if (result.isEmpty) {
      await db.insert('evidence', e.toMapLocal());
    }
  }

  /// Deletes orphan evidence rows that have no firebase_case_id.
  /// Useful to clean legacy records that could cause cross-case mixing.
  static Future<int> deleteOrphanEvidence() async {
    final db = await DBHelper.database;
    return await db.delete(
      'evidence',
      where: "firebase_case_id IS NULL OR TRIM(firebase_case_id) = ''",
    );
  }
}
